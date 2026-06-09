import AppKit
import SwiftUI

/// Hosts the first-run onboarding flow in a regular centered window.
@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            ModalWindowHelper.bringToFront(window)
            return
        }

        let root = OnboardingView { [weak self] in
            AppSettings.shared.hasCompletedOnboarding = true
            self?.close()
        }
        let hosting = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: hosting)
        win.title = "NotchBoard"
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.center()
        window = win

        ModalWindowHelper.bringToFront(win)
    }

    private func close() {
        window?.close()
    }
}
