import AppKit
import UniformTypeIdentifiers

/// Builds the `NSItemProvider` that backs an outward drag into another app,
/// and flags the controller so the panel won't auto-close mid-drag.
enum DragProviders {
    /// Set while a shelf tile itself is being dragged, so a drop back onto the
    /// shelf can be ignored instead of creating a duplicate copy.
    @MainActor static var draggingShelfItemID: UUID?

    @MainActor
    static func beginDrag() {
        NotchWindowController.isDraggingOut = true
        // Safety reset in case we never observe the cursor re-entering the panel.
        // Kept generous so slower file drags (non-image types take longer to
        // hand off) still see the shelf-origin flag when dropped back.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            NotchWindowController.isDraggingOut = false
            draggingShelfItemID = nil
        }
    }

    static func provider(for item: ShelfItem) -> NSItemProvider {
        return fileProvider(url: item.fileURL, name: item.displayName)
    }

    static func provider(for item: ClipboardItem) -> NSItemProvider {
        switch item.kind {
        case .image, .file:
            if let url = item.fileURL {
                return fileProvider(url: url, name: url.lastPathComponent)
            }
        case .link:
            if let text = item.text, let url = URL(string: text) {
                return NSItemProvider(object: url as NSURL)
            }
        case .text, .color:
            break
        }
        let text = item.text ?? ""
        return NSItemProvider(object: text as NSString)
    }

    /// Canonical file drag-out: `NSItemProvider(contentsOf:)` registers the file
    /// representation so Finder and other apps receive a real, droppable file.
    private static func fileProvider(url: URL, name: String) -> NSItemProvider {
        if let provider = NSItemProvider(contentsOf: url) {
            provider.suggestedName = name
            return provider
        }
        // Fallback: hand over the file URL itself.
        let provider = NSItemProvider()
        provider.registerObject(url as NSURL, visibility: .all)
        provider.suggestedName = name
        return provider
    }
}
