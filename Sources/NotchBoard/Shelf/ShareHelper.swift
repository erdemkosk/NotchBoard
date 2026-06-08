import AppKit

/// Presents the system share sheet (AirDrop, Messages, Mail, Copy, iCloud, …)
/// for one or more shelf files.
@MainActor
enum ShareHelper {
    /// Shows `NSSharingServicePicker` anchored near the center of the panel's
    /// key window. Falls back silently if there's nothing to share.
    static func share(urls: [URL]) {
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else { return }
        guard let view = NSApp.keyWindow?.contentView else { return }

        let picker = NSSharingServicePicker(items: existing)
        let bounds = view.bounds
        // Anchor a small rect near the top-center of the panel.
        let anchor = NSRect(x: bounds.midX - 1, y: bounds.maxY - 80, width: 2, height: 2)
        picker.show(relativeTo: anchor, of: view, preferredEdge: .minY)
    }
}
