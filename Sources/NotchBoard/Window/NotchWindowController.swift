import AppKit
import SwiftUI
import Combine

/// Owns the notch window, its SwiftUI content, and the open/close hover logic.
@MainActor
final class NotchWindowController: NSObject, NotchTriggerDelegate {
    private var window: NotchWindow?
    private var triggerWindow: NSWindow?
    private var triggerView: NotchTriggerView?
    private let viewModel = NotchViewModel()
    private let hover = HoverDetector()
    private let hotKey = HotKeyManager()
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    private var metrics = NotchScreenMetrics.primary
    private var closeWorkItem: DispatchWorkItem?

    /// Set while an outward drag is in progress so we don't auto-close mid-drag.
    static var isDraggingOut = false

    func show() {
        metrics = NotchScreenMetrics.primary
        viewModel.updateMetrics(metrics)

        let frame = windowFrame(for: metrics)
        let win = NotchWindow(contentRect: frame)

        let root = NotchView(viewModel: viewModel)
            .environmentObject(viewModel)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        win.contentView = hosting

        win.setFrame(frame, display: true)
        win.orderFrontRegardless()
        win.ignoresMouseEvents = true
        window = win

        setupTriggerWindow()

        viewModel.requestClose = { [weak self] in self?.close() }
        viewModel.clipboard.start()

        hover.onMove = { [weak self] point in
            Task { @MainActor in self?.handleMouseMove(point) }
        }
        hover.start()

        hotKey.onTrigger = { [weak self] in self?.toggle() }
        hotKey.register()

        installKeyMonitor()

        // Live-resize the window when the panel size changes (drag handle).
        viewModel.$openWidth
            .combineLatest(viewModel.$openHeight)
            .dropFirst()
            .sink { [weak self] _, _ in self?.applyPanelSize() }
            .store(in: &cancellables)
    }

    private func applyPanelSize() {
        guard let window else { return }
        let frame = windowFrame(for: metrics)
        window.setFrame(frame, display: true)
        window.contentView?.frame = NSRect(origin: .zero, size: frame.size)
    }

    /// Handles Esc / arrows / Enter while the panel is the key window.
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, self.viewModel.isOpen else { return event }
            switch event.keyCode {
            case 53: // Esc
                self.close()
                return nil
            case 36, 76: // Return / Enter
                if self.viewModel.selectedTab == .history {
                    self.viewModel.activateSelection()
                    return nil
                }
            case 123: // Left
                if self.viewModel.selectedTab == .history { self.viewModel.moveSelection(.left); return nil }
            case 124: // Right
                if self.viewModel.selectedTab == .history { self.viewModel.moveSelection(.right); return nil }
            case 125: // Down
                if self.viewModel.selectedTab == .history { self.viewModel.moveSelection(.down); return nil }
            case 126: // Up
                if self.viewModel.selectedTab == .history { self.viewModel.moveSelection(.up); return nil }
            default:
                break
            }
            return event
        }
    }

    /// A tiny window pinned over the notch that listens for hover + drag-enter.
    private func setupTriggerWindow() {
        let rect = triggerRect()
        let tWin = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        tWin.isOpaque = false
        tWin.backgroundColor = .clear
        tWin.hasShadow = false
        tWin.level = .statusBar
        tWin.ignoresMouseEvents = false
        tWin.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let view = NotchTriggerView(frame: NSRect(origin: .zero, size: rect.size))
        view.delegate = self
        tWin.contentView = view
        tWin.orderFrontRegardless()

        triggerWindow = tWin
        triggerView = view
    }

    func reposition() {
        metrics = NotchScreenMetrics.primary
        viewModel.updateMetrics(metrics)
        let frame = windowFrame(for: metrics)
        window?.setFrame(frame, display: true)
        window?.contentView?.frame = NSRect(origin: .zero, size: frame.size)
        triggerWindow?.setFrame(triggerRect(), display: true)
    }

    // MARK: - NotchTriggerDelegate

    func triggerActivated(dragging: Bool) {
        if dragging {
            // Reveal the shelf so the dragged file has somewhere to land.
            viewModel.selectedTab = .shelf
            NotchWindowController.isDraggingOut = false
        }
        open()
    }

    func toggle() {
        viewModel.isOpen ? close() : open()
    }

    // MARK: - Geometry

    private func windowFrame(for metrics: NotchScreenMetrics) -> NSRect {
        let f = metrics.screen.frame
        let w = viewModel.openWidth
        let h = viewModel.openHeight
        return NSRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h)
    }

    /// Hot zone around the notch that triggers opening (screen coords).
    private func triggerRect() -> NSRect {
        let f = metrics.screen.frame
        let width = max(metrics.notchWidth + 80, 200)
        let height = max(metrics.notchHeight + 6, 30)
        return NSRect(x: f.midX - width / 2, y: f.maxY - height, width: width, height: height)
    }

    // MARK: - Open / Close

    /// Generous margin so brief excursions toward shelf cards don't close the panel.
    private let closeMargin: CGFloat = 28

    private func handleMouseMove(_ point: NSPoint) {
        // Opening is driven by the trigger window; here we only manage auto-close.
        guard viewModel.isOpen else { return }
        let panel = window?.frame ?? .zero
        let padded = panel.insetBy(dx: -closeMargin, dy: -closeMargin)
        if padded.contains(point) {
            cancelClose()
        } else {
            scheduleClose()
        }
    }

    private func open() {
        cancelClose()
        guard !viewModel.isOpen else { return }
        // Remember who was focused so auto-paste can return content there.
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier {
            viewModel.previousApp = front
        }
        viewModel.selectedIndex = 0
        // Hand event handling to the panel; stop the tiny trigger from intercepting.
        triggerWindow?.ignoresMouseEvents = true
        window?.ignoresMouseEvents = false
        window?.orderFrontRegardless()
        // Activate so the search field + keyboard navigation receive key events.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKey()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) {
            viewModel.isOpen = true
        }
    }

    private func close() {
        guard viewModel.isOpen else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            viewModel.isOpen = false
        }
        // Re-enable click-through + the trigger after the collapse settles, and
        // hand focus back so the user keeps typing where they were.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak self] in
            guard let self, !self.viewModel.isOpen else { return }
            self.window?.ignoresMouseEvents = true
            self.triggerWindow?.ignoresMouseEvents = false
            if !AppSettings.shared.autoPaste {
                NSApp.deactivate()
            }
        }
    }

    private func scheduleClose() {
        guard closeWorkItem == nil else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.closeWorkItem = nil
            if NotchWindowController.isDraggingOut { return }
            // Re-check the live cursor position before committing to close.
            let panel = self.window?.frame ?? .zero
            if !panel.insetBy(dx: -self.closeMargin, dy: -self.closeMargin).contains(NSEvent.mouseLocation) {
                self.close()
            }
        }
        closeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    private func cancelClose() {
        closeWorkItem?.cancel()
        closeWorkItem = nil
    }
}
