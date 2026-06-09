import AppKit
import SwiftUI

/// Hosts the settings form in a regular window (the app itself is an accessory).
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            ModalWindowHelper.bringToFront(window)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView())
        let win = NSWindow(contentViewController: hosting)
        win.title = L.settingsTitle
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.center()
        window = win

        ModalWindowHelper.bringToFront(win)
    }
}
