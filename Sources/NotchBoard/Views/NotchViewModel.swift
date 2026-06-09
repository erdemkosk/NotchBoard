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
    @Published var unlockedCollectionIDs: Set<UUID> = []

    /// Set when the panel is summoned via the keyboard shortcut so the expanded
    /// panel focuses the search field on appear (lets the user type immediately).
    @Published var pendingSearchFocus = false

    /// Quick text transforms available from a card's context menu.
    enum TextTransform: String, CaseIterable, Identifiable {
        case uppercase, lowercase, trim, jsonPretty, urlEncode, urlDecode, base64Encode, base64Decode
        var id: String { rawValue }

        var title: String {
            switch self {
            case .uppercase: return L.transformUppercase
            case .lowercase: return L.transformLowercase
            case .trim: return L.transformTrim
            case .jsonPretty: return L.transformJSON
            case .urlEncode: return L.transformURLEncode
            case .urlDecode: return L.transformURLDecode
            case .base64Encode: return L.transformBase64Encode
            case .base64Decode: return L.transformBase64Decode
            }
        }

        var icon: String {
            switch self {
            case .uppercase: return "textformat.size.larger"
            case .lowercase: return "textformat.size.smaller"
            case .trim: return "scissors"
            case .jsonPretty: return "curlybraces"
            case .urlEncode: return "link"
            case .urlDecode: return "link.badge.plus"
            case .base64Encode: return "lock"
            case .base64Decode: return "lock.open"
            }
        }

        func apply(_ s: String) -> String? {
            switch self {
            case .uppercase: return s.uppercased()
            case .lowercase: return s.lowercased()
            case .trim: return s.trimmingCharacters(in: .whitespacesAndNewlines)
            case .jsonPretty:
                guard let data = s.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
                      let pretty = try? JSONSerialization.data(
                        withJSONObject: obj,
                        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                      ),
                      let out = String(data: pretty, encoding: .utf8)
                else { return nil }
                return out
            case .urlEncode:
                return s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            case .urlDecode:
                return s.removingPercentEncoding
            case .base64Encode:
                return s.data(using: .utf8)?.base64EncodedString()
            case .base64Decode:
                guard let data = Data(base64Encoded: s.trimmingCharacters(in: .whitespacesAndNewlines)),
                      let out = String(data: data, encoding: .utf8)
                else { return nil }
                return out
            }
        }
    }

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
    @Published var hudErrorMessage: String?
    private var hudWorkItem: DispatchWorkItem?

    /// Increments on each capture to trigger a brief glow pulse on the notch.
    @Published var capturePulse = 0

    /// Shows the capture HUD for ~1.6s.
    func showCaptureHUD(_ item: ClipboardItem, errorMessage: String? = nil) {
        capturePulse += 1
        hudWorkItem?.cancel()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            hudItem = item
            hudErrorMessage = errorMessage
        }
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                self?.hudItem = nil
                self?.hudErrorMessage = nil
            }
        }
        hudWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    func hudHoverChanged(_ hovering: Bool) {
        if hovering {
            hudWorkItem?.cancel()
        } else {
            hudWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    self?.hudItem = nil
                    self?.hudErrorMessage = nil
                }
            }
            hudWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
        }
    }

    /// Set by the window controller so views can ask the panel to collapse.
    var requestClose: (() -> Void)?

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
        // Pinned snippets always float to the top, keeping their relative order.
        let pinned = result.filter { $0.isPinned }
        let rest = result.filter { !$0.isPinned }
        return pinned + rest
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

    /// Copies an item to the clipboard, flashes feedback, and closes the panel.
    /// The user then pastes it manually wherever they want (Cmd+V).
    func selectAndCopy(_ item: ClipboardItem) {
        clipboard.copyToPasteboard(item)
        finishCopy(item)
    }

    /// Copies only the plain-text form of an item, then closes the panel.
    func copyPlain(_ item: ClipboardItem) {
        clipboard.copyAsPlainText(item)
        finishCopy(item)
    }

    /// Applies a quick text transform to the item's text, replaces the stored
    /// item's data with the transformed result, and copies it to the pasteboard.
    func copyTransformed(_ item: ClipboardItem, _ transform: TextTransform) {
        guard let text = item.text else { return }
        if let out = transform.apply(text) {
            clipboard.copyString(out)
            clipboard.updateText(out, for: item)
            finishCopy(item)
        } else {
            // Transform failed (e.g. invalid JSON, invalid Base64, etc.)
            NSSound.beep()
            let errorMsg: String
            switch transform {
            case .jsonPretty:
                errorMsg = L.t("Invalid JSON", "Geçersiz JSON")
            case .base64Decode:
                errorMsg = L.t("Invalid Base64", "Geçersiz Base64")
            default:
                errorMsg = L.t("Transform Failed", "Dönüşüm Başarısız")
            }
            showCaptureHUD(item, errorMessage: errorMsg)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.requestClose?()
            }
        }
    }

    private func finishCopy(_ item: ClipboardItem) {
        lastCopiedID = item.id
        showCaptureHUD(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.lastCopiedID = nil
            self?.requestClose?()
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
    /// Corner radius for the closed pill (customizable on non-notch screens).
    @Published var pillCornerRadius: CGFloat = 12

    // Adjustable, persisted size of the expanded panel.
    @Published var openWidth: CGFloat = CGFloat(AppSettings.defaultPanelWidth)
    @Published var openHeight: CGFloat = CGFloat(AppSettings.defaultPanelHeight)
    @Published var horizontalOffset: CGFloat = 0.0
    @Published var screenWidth: CGFloat = 1920

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

    func updateHorizontalOffset(_ offset: CGFloat) {
        let maxOffset = max(0, (screenWidth - openWidth) / 2)
        horizontalOffset = min(max(offset, -maxOffset), maxOffset)
    }

    func commitHorizontalOffset() {
        AppSettings.shared.horizontalOffset = Double(horizontalOffset)
    }

    init() {
        openWidth = CGFloat(AppSettings.shared.panelWidth)
        openHeight = CGFloat(AppSettings.shared.panelHeight)
        horizontalOffset = CGFloat(AppSettings.shared.horizontalOffset)

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
        hasHardwareNotch = metrics.hasHardwareNotch
        screenWidth = metrics.screen.frame.width
        if metrics.hasHardwareNotch {
            notchWidth = metrics.notchWidth
            notchHeight = metrics.notchHeight
            pillCornerRadius = 12
        } else {
            // Apply the user's custom virtual-pill appearance.
            let settings = AppSettings.shared
            notchWidth = CGFloat(settings.triggerPillWidth)
            notchHeight = CGFloat(settings.triggerPillHeight)
            pillCornerRadius = CGFloat(settings.triggerPillCornerRadius)
        }
    }
}
