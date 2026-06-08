import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var notchController: NotchWindowController?
    private let settingsController = SettingsWindowController()
    private let onboardingController = OnboardingWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.shared.syncLaunchAtLoginState()
        setupStatusItem()
        notchController = NotchWindowController()
        notchController?.show()
        UpdateService.shared.checkOnLaunchIfDue()

        // First run: walk the user through setup and the optional permission.
        if !AppSettings.shared.hasCompletedOnboarding {
            onboardingController.show()
        }

        // Reposition the notch window whenever the active screen layout changes.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        notchController?.reposition()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.topthird.inset.filled",
                accessibilityDescription: "NotchBoard"
            )
        }

        let menu = NSMenu()
        menu.addItem(
            withTitle: L.toggleNotch,
            action: #selector(toggleNotch),
            keyEquivalent: "t"
        )
        menu.addItem(
            withTitle: "\(L.settings)…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        menu.addItem(
            withTitle: L.setupGuide,
            action: #selector(openOnboarding),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: L.quit,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu
        statusItem = item
    }

    @objc private func toggleNotch() {
        notchController?.toggle()
    }

    @objc private func openSettings() {
        settingsController.show()
    }

    @objc private func openOnboarding() {
        onboardingController.show()
    }
}
