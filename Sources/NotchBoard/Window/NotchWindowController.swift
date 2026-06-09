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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        // Import files sent from Finder via the "Send to NotchBoard" extension.
        ShelfInbox.startObserving { [weak self] in self?.importFromInbox() }
        importFromInbox()

        hover.onMove = { [weak self] point in
            Task { @MainActor in self?.handleMouseMove(point) }
        }
        hover.start()

        let settings = AppSettings.shared
        hotKey.onTrigger = { [weak self] in self?.toggle() }
        hotKey.register(keyCode: UInt32(settings.hotkeyCode), modifiers: UInt32(settings.hotkeyModifiers))

        installKeyMonitor()

        // Live-resize/reposition the window when size or offset changes.
        viewModel.$openWidth
            .combineLatest(viewModel.$openHeight, viewModel.$horizontalOffset)
            .dropFirst()
            .sink { [weak self] _, _, _ in
                self?.applyPanelSize()
                self?.refreshPillAppearance()
            }
            .store(in: &cancellables)

        // Live-update the trigger pill when its non-notch appearance changes.
        settings.$triggerPillWidth
            .combineLatest(settings.$triggerPillHeight, settings.$triggerPillCornerRadius)
            .dropFirst()
            .sink { [weak self] _, _, _ in self?.refreshPillAppearance() }
            .store(in: &cancellables)

        // Live-update the hotkey registration when it changes in settings.
        settings.$hotkeyCode
            .combineLatest(settings.$hotkeyModifiers)
            .dropFirst()
            .sink { [weak self] code, mods in
                self?.hotKey.register(keyCode: UInt32(code), modifiers: UInt32(mods))
            }
            .store(in: &cancellables)

        // Live-update the horizontal offset when it changes in settings.
        settings.$horizontalOffset
            .dropFirst()
            .sink { [weak self] offset in
                self?.viewModel.horizontalOffset = CGFloat(offset)
            }
            .store(in: &cancellables)

        // Make the window interactive while the HUD is shown so the user can hover & click its actions
        viewModel.$hudItem
            .sink { [weak self] item in
                guard let self else { return }
                if item != nil {
                    self.window?.ignoresMouseEvents = false
                } else if !self.viewModel.isOpen {
                    self.window?.ignoresMouseEvents = true
                }
            }
            .store(in: &cancellables)

        // Live-update the screen capture hide setting on the window.
        settings.$hideFromScreenCapture
            .sink { [weak self] hide in
                self?.window?.sharingType = hide ? .none : .readOnly
            }
            .store(in: &cancellables)
    }

    /// Drains the Finder-extension inbox and stashes any queued files on the
    /// shelf (current collection).
    private func importFromInbox() {
        let urls = ShelfInbox.drain()
        guard !urls.isEmpty else { return }
        for url in urls {
            viewModel.shelf.addFile(at: url)
        }
        viewModel.selectedTab = .shelf
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

    /// Re-anchors the panel (and trigger zone) to the screen the user is currently
    /// on, so summoning it from another display slides it down there instead of
    /// always on the hardware-notch screen.
    private func moveToActiveScreen() {
        let active = NotchScreenMetrics.active
        guard active.screen.frame != metrics.screen.frame else { return }
        metrics = active
        viewModel.updateMetrics(metrics)
        let frame = windowFrame(for: metrics)
        window?.setFrame(frame, display: false)
        window?.contentView?.frame = NSRect(origin: .zero, size: frame.size)
        triggerWindow?.setFrame(triggerRect(), display: false)
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
        if viewModel.isOpen {
            close()
        } else {
            // Summoned via the keyboard shortcut: switch to History and focus the search field on open.
            viewModel.selectedTab = .history
            viewModel.pendingSearchFocus = true
            open()
        }
    }

    // MARK: - Geometry

    private func windowFrame(for metrics: NotchScreenMetrics) -> NSRect {
        let f = metrics.screen.frame
        let w = viewModel.openWidth
        let h = viewModel.openHeight
        let offset = viewModel.hasHardwareNotch ? 0.0 : viewModel.horizontalOffset
        let minX = f.minX
        let maxX = f.maxX - w
        let targetX = f.midX - w / 2 + offset
        let clampedX = min(max(targetX, minX), maxX)
        return NSRect(x: clampedX, y: f.maxY - h, width: w, height: h)
    }

    private func triggerRect() -> NSRect {
        let f = metrics.screen.frame
        // Keep it tight to the notch/pill bounds (only 4pt padding on each side) to avoid blocking menu/tray icons
        let width = viewModel.notchWidth + 8
        let height = viewModel.notchHeight + 2
        let offset = viewModel.hasHardwareNotch ? 0.0 : viewModel.horizontalOffset
        
        let minX = f.minX
        let maxX = f.maxX - width
        let targetX = f.midX - width / 2 + offset
        let clampedX = min(max(targetX, minX), maxX)
        return NSRect(x: clampedX, y: f.maxY - height, width: width, height: height)
    }

    /// Re-applies the trigger-pill appearance after the user changes the
    /// non-notch customization in Settings.
    private func refreshPillAppearance() {
        viewModel.updateMetrics(metrics)
        triggerWindow?.setFrame(triggerRect(), display: true)
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
        viewModel.selectedIndex = 0
        // Slide down on whichever display the user is currently on (e.g. when the
        // panel is summoned via the keyboard shortcut from a secondary screen).
        moveToActiveScreen()
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
        viewModel.unlockedCollectionIDs.removeAll()
        // Re-enable click-through + the trigger after the collapse settles, and
        // hand focus back so the user keeps typing where they were.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak self] in
            guard let self, !self.viewModel.isOpen else { return }
            self.window?.ignoresMouseEvents = true
            self.triggerWindow?.ignoresMouseEvents = false
            // Hand focus back to the app the user was in so they can paste (Cmd+V).
            NSApp.deactivate()

            if AppSettings.shared.autoPasteEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.performAutoPaste()
                }
            }
        }
    }

    private func performAutoPaste() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKeyCode: CGKeyCode = 9 // V key
        guard let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else { return }
        cmdVDown.flags = .maskCommand
        guard let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else { return }
        cmdVUp.flags = .maskCommand

        cmdVDown.post(tap: .cghidEventTap)
        cmdVUp.post(tap: .cghidEventTap)
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

    @objc private func appDidResignActive() {
        close()
    }
}
