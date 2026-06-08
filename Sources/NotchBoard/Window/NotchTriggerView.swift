import AppKit

@MainActor
protocol NotchTriggerDelegate: AnyObject {
    /// Cursor (or a dragged item) reached the notch hot zone.
    func triggerActivated(dragging: Bool)
}

/// A small always-listening view sitting over the notch. It opens the panel on
/// either mouse hover or when a drag (file/image) approaches the notch, which is
/// what makes "drag a file toward the notch to reveal the shelf" work.
final class NotchTriggerView: NSView {
    weak var delegate: NotchTriggerDelegate?
    private var tracking: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([
            .fileURL,
            .png,
            .tiff,
            .string,
            .URL,
            NSPasteboard.PasteboardType("public.image"),
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url")
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        delegate?.triggerActivated(dragging: false)
    }

    // MARK: - Dragging (open while a file/image is being dragged toward the notch)

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        delegate?.triggerActivated(dragging: true)
        return []
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        delegate?.triggerActivated(dragging: true)
        return []
    }
}
