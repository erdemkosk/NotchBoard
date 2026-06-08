import AppKit

/// Tracks the global mouse position and reports moves in screen coordinates
/// (bottom-left origin), so the controller can decide when to open/close.
final class HoverDetector {
    var onMove: ((NSPoint) -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        guard globalMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.report()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.report()
            return event
        }
    }

    func stop() {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor { NSEvent.removeMonitor(l) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func report() {
        onMove?(NSEvent.mouseLocation)
    }

    deinit { stop() }
}
