import SwiftUI
import AppKit
import Combine

enum NotchTab: String, CaseIterable, Identifiable {
    case history = "History"
    case shelf = "Shelf"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: return L.tabHistory
        case .shelf: return L.tabShelf
        }
    }

    var systemImage: String {
        switch self {
        case .history: return "clock"
        case .shelf: return "tray.full"
        }
    }
}

/// Shared observable state driving the notch UI.
@MainActor
final class NotchViewModel: ObservableObject {
    @Published var isOpen: Bool = false
    @Published var selectedTab: NotchTab = .history
    @Published var searchText: String = ""
    @Published var showFavoritesOnly: Bool = false

    /// Active type filter for the history grid (nil = all kinds).
    @Published var selectedKind: ClipboardItem.Kind?
    /// Active tag filter (nil = all tags).
    @Published var selectedTag: String?

    /// Index of the keyboard-highlighted card within `visibleHistory`.
    @Published var selectedIndex: Int = 0

    let clipboard = ClipboardManager()
    let shelf = ShelfManager()
    private var cancellables = Set<AnyCancellable>()

    /// Briefly highlights the card that was just copied.
    @Published var lastCopiedID: UUID?

    /// Transient Dynamic-Island-style capture confirmation shown near the notch.
    @Published var hudItem: ClipboardItem?
    private var hudWorkItem: DispatchWorkItem?

    /// Shows the capture HUD for ~1.6s (skipped while the panel is open).
    func showCaptureHUD(_ item: ClipboardItem) {
        guard !isOpen else { return }
        hudWorkItem?.cancel()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            hudItem = item
        }
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                self?.hudItem = nil
            }
        }
        hudWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    /// Set by the window controller so views can ask the panel to collapse.
    var requestClose: (() -> Void)?

    /// The app that was frontmost before the panel opened (for auto-paste).
    var previousApp: NSRunningApplication?

    /// History filtered by search text and favorites toggle.
    var visibleHistory: [ClipboardItem] {
        var result = clipboard.items
        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }
        if let kind = selectedKind {
            result = result.filter { $0.kind == kind }
        }
        if let tag = selectedTag {
            result = result.filter { item in
                item.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
            }
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { item in
                (item.text?.lowercased().contains(q) ?? false)
                    || item.subtitle.lowercased().contains(q)
                    || (item.sourceAppName?.lowercased().contains(q) ?? false)
                    || item.tags.contains { $0.lowercased().contains(q) }
            }
        }
        return result
    }

    /// Kinds currently present in history, in a stable display order.
    var availableKinds: [ClipboardItem.Kind] {
        let order: [ClipboardItem.Kind] = [.text, .link, .color, .image, .file]
        let present = Set(clipboard.items.map { $0.kind })
        return order.filter { present.contains($0) }
    }

    func count(of kind: ClipboardItem.Kind) -> Int {
        clipboard.items.filter { $0.kind == kind }.count
    }

    /// Approximate number of grid columns in the history view.
    var historyColumns: Int {
        let usable = openWidth - 36 + 14
        return max(Int(usable / (210 + 14)), 1)
    }

    // MARK: - Selection / clicks

    /// Copies an item, flashes feedback, closes the panel, and optionally pastes
    /// it into the previously focused app.
    func selectAndCopy(_ item: ClipboardItem) {
        clipboard.copyToPasteboard(item)
        lastCopiedID = item.id
        let target = previousApp
        let autoPaste = AppSettings.shared.autoPaste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.lastCopiedID = nil
            self?.requestClose?()
            if autoPaste {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    AutoPaster.paste(to: target)
                }
            }
        }
    }

    // MARK: - Keyboard navigation

    func moveSelection(_ direction: MoveDirection) {
        let items = visibleHistory
        guard !items.isEmpty else { return }
        let cols = historyColumns
        var idx = min(selectedIndex, items.count - 1)
        switch direction {
        case .left: idx -= 1
        case .right: idx += 1
        case .up: idx -= cols
        case .down: idx += cols
        }
        selectedIndex = max(0, min(idx, items.count - 1))
    }

    func activateSelection() {
        let items = visibleHistory
        guard items.indices.contains(selectedIndex) else { return }
        selectAndCopy(items[selectedIndex])
    }

    enum MoveDirection { case left, right, up, down }

    /// Visual metrics for the current screen.
    @Published var notchWidth: CGFloat = NotchScreenMetrics.virtualNotchWidth
    @Published var notchHeight: CGFloat = 32
    @Published var hasHardwareNotch: Bool = false

    // Adjustable, persisted size of the expanded panel.
    @Published var openWidth: CGFloat = CGFloat(AppSettings.defaultPanelWidth)
    @Published var openHeight: CGFloat = CGFloat(AppSettings.defaultPanelHeight)

    /// Updates the panel size live (clamped). Pass nil to keep a dimension.
    func resizePanel(width: CGFloat? = nil, height: CGFloat? = nil) {
        if let width {
            openWidth = min(max(width, CGFloat(AppSettings.minPanelWidth)), CGFloat(AppSettings.maxPanelWidth))
        }
        if let height {
            openHeight = min(max(height, CGFloat(AppSettings.minPanelHeight)), CGFloat(AppSettings.maxPanelHeight))
        }
    }

    /// Persists the current panel size after a resize gesture ends.
    func commitPanelSize() {
        AppSettings.shared.panelWidth = Double(openWidth)
        AppSettings.shared.panelHeight = Double(openHeight)
    }

    init() {
        openWidth = CGFloat(AppSettings.shared.panelWidth)
        openHeight = CGFloat(AppSettings.shared.panelHeight)

        // Bridge nested ObservableObject changes up so SwiftUI re-renders live
        // (otherwise the grid only refreshes when something else forces a redraw).
        clipboard.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        shelf.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        clipboard.onCapture = { [weak self] item in
            self?.showCaptureHUD(item)
        }
    }

    func updateMetrics(_ metrics: NotchScreenMetrics) {
        notchWidth = metrics.notchWidth
        notchHeight = metrics.notchHeight
        hasHardwareNotch = metrics.hasHardwareNotch
    }
}
