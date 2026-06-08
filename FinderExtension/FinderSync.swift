import Cocoa
import FinderSync

/// Adds a top-level "Send to NotchBoard" item to Finder's right-click menu.
/// Selected files are appended to NotchBoard's inbox and the main app is
/// notified via a Darwin notification.
@objc(FinderSync)
final class FinderSync: FIFinderSync {
    private let darwinName = "com.notchboard.inbox"

    override init() {
        super.init()
        // Monitor the whole filesystem so the contextual menu appears everywhere.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        guard menuKind == .contextualMenuForItems else { return menu }
        let item = NSMenuItem(
            title: "Send to NotchBoard",
            action: #selector(sendToNotchBoard(_:)),
            keyEquivalent: ""
        )
        item.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: nil)
        menu.addItem(item)
        return menu
    }

    @objc func sendToNotchBoard(_ sender: AnyObject?) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        appendToInbox(urls.map { $0.path })
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinName as CFString),
            nil,
            nil,
            true
        )
    }

    // MARK: - Inbox file

    private var inboxURL: URL? {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("NotchBoard", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("inbox.json")
    }

    /// Appends paths to inbox.json, merging with anything not yet drained.
    private func appendToInbox(_ paths: [String]) {
        guard let url = inboxURL else { return }
        var existing: [String] = []
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            existing = decoded
        }
        existing.append(contentsOf: paths)
        if let data = try? JSONEncoder().encode(existing) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
