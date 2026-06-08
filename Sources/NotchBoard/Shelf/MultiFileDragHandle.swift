import SwiftUI
import AppKit

/// A drag handle that lets the user drag *all* selected shelf files out in a
/// single gesture. SwiftUI's `.onDrag` only vends one provider, so multi-file
/// drag-out needs an AppKit dragging session.
struct MultiFileDragHandle: NSViewRepresentable {
    /// Resolves the current selection's file URLs at drag time.
    var urls: () -> [URL]
    /// Called when the drag begins so the controller won't auto-close mid-drag.
    var onBegin: () -> Void

    func makeNSView(context: Context) -> DragSourceView {
        let view = DragSourceView()
        view.urlsProvider = urls
        view.onBegin = onBegin
        return view
    }

    func updateNSView(_ nsView: DragSourceView, context: Context) {
        nsView.urlsProvider = urls
        nsView.onBegin = onBegin
    }

    final class DragSourceView: NSView, NSDraggingSource {
        var urlsProvider: (() -> [URL])?
        var onBegin: (() -> Void)?

        override func mouseDown(with event: NSEvent) {
            guard let urls = urlsProvider?(), !urls.isEmpty else { return }

            let items: [NSDraggingItem] = urls.enumerated().map { (index, url) -> NSDraggingItem in
                let item = NSDraggingItem(pasteboardWriter: url as NSURL)
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                let size = NSSize(width: 48, height: 48)
                let origin = NSPoint(x: CGFloat(index) * 6, y: -CGFloat(index) * 6)
                item.setDraggingFrame(NSRect(origin: origin, size: size), contents: icon)
                return item
            }
            guard !items.isEmpty else { return }

            onBegin?()
            beginDraggingSession(with: items, event: event, source: self)
        }

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            .copy
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            // Only intercept clicks within our own bounds.
            bounds.contains(convert(point, from: superview)) ? self : nil
        }
    }
}
