import Foundation

/// Bridge between the Finder extension ("Send to NotchBoard") and the main app.
///
/// The extension appends selected file paths to `inbox.json` and posts a Darwin
/// notification; the main app observes that notification, drains the inbox, and
/// imports the files onto the shelf. Darwin notifications cross the process
/// boundary regardless of sandboxing, and the shared file lives in the app's
/// Application Support directory.
@MainActor
enum ShelfInbox {
    /// Darwin notification name shared with the Finder extension.
    static let darwinName = "com.notchboard.inbox"

    static var url: URL {
        Persistence.supportDirectory.appendingPathComponent("inbox.json")
    }

    private static var handler: (() -> Void)?

    /// Starts listening for "Send to NotchBoard" events from the extension.
    static func startObserving(_ onReceive: @escaping () -> Void) {
        handler = onReceive
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let callback: CFNotificationCallback = { _, _, _, _, _ in
            Task { @MainActor in ShelfInbox.handler?() }
        }
        CFNotificationCenterAddObserver(
            center,
            nil,
            callback,
            darwinName as CFString,
            nil,
            .deliverImmediately
        )
    }

    /// Reads and clears the inbox, returning the queued file URLs.
    static func drain() -> [URL] {
        guard let data = try? Data(contentsOf: url),
              let paths = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        try? FileManager.default.removeItem(at: url)
        return paths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }
}
