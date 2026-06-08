import AppKit

/// Borderless, transparent window pinned to the notch area, visible on every Space.
final class NotchWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        isMovable = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        // Keep the window out of screenshots / screen recordings of other apps.
        sharingType = .none
    }

    // Borderless windows refuse key status by default; we need it for drag + clicks.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
