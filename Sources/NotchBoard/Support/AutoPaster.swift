import AppKit
import ApplicationServices

/// Activates the previously focused app and synthesizes Cmd+V, so selecting a
/// history item pastes it straight where the user was typing.
@MainActor
enum AutoPaster {
    /// Whether we currently hold the Accessibility permission needed to post keys.
    static var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user (system dialog) to grant Accessibility access.
    static func requestPermission() {
        // Equivalent to kAXTrustedCheckOptionPrompt, used directly to avoid a
        // non-concurrency-safe global under Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func paste(to app: NSRunningApplication?) {
        guard hasPermission else {
            requestPermission()
            return
        }

        if let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            app.activate()
        }

        // Give the target app a moment to become active before posting keys.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            postCommandV()
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // 'v'

        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else {
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
