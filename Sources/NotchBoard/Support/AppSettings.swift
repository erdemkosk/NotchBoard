import Foundation
import Combine
import ServiceManagement
import Carbon.HIToolbox

/// User-configurable settings, persisted in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLogin()
        }
    }

    @Published var skipSensitive: Bool {
        didSet { defaults.set(skipSensitive, forKey: Keys.skipSensitive) }
    }

    @Published var maxItems: Int {
        didSet { defaults.set(maxItems, forKey: Keys.maxItems) }
    }

    /// Minutes after which non-pinned history is auto-deleted. 0 = keep forever.
    @Published var autoDeleteMinutes: Int {
        didSet { defaults.set(autoDeleteMinutes, forKey: Keys.autoDeleteMinutes) }
    }

    /// Whether the first-run setup guide has been completed/dismissed.
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    /// Whether clicked items automatically paste into the frontmost app.
    @Published var autoPasteEnabled: Bool {
        didSet { defaults.set(autoPasteEnabled, forKey: Keys.autoPasteEnabled) }
    }

    /// Whether the notch shows a brief "Copied" pill when new clipboard content is captured.
    @Published var captureHUDEnabled: Bool {
        didSet { defaults.set(captureHUDEnabled, forKey: Keys.captureHUDEnabled) }
    }

    /// Whether the panel is hidden from screenshots and screen recordings.
    @Published var hideFromScreenCapture: Bool {
        didSet { defaults.set(hideFromScreenCapture, forKey: Keys.hideFromScreenCapture) }
    }

    /// Configured system-wide hotkey code.
    @Published var hotkeyCode: Int {
        didSet { defaults.set(hotkeyCode, forKey: Keys.hotkeyCode) }
    }

    /// Configured system-wide hotkey modifiers.
    @Published var hotkeyModifiers: Int {
        didSet { defaults.set(hotkeyModifiers, forKey: Keys.hotkeyModifiers) }
    }

    /// Retention options offered in Settings (minutes). 0 = off.
    static let retentionOptions: [Int] = [0, 5, 15, 30, 60, 60 * 24, 60 * 24 * 7, 60 * 24 * 30]

    @Published var panelWidth: Double {
        didSet { defaults.set(panelWidth, forKey: Keys.panelWidth) }
    }

    @Published var panelHeight: Double {
        didSet { defaults.set(panelHeight, forKey: Keys.panelHeight) }
    }

    /// Trigger-pill appearance on screens WITHOUT a hardware notch. Macs with a
    /// real notch always use the hardware geometry and ignore these.
    @Published var triggerPillWidth: Double {
        didSet { defaults.set(triggerPillWidth, forKey: Keys.triggerPillWidth) }
    }

    @Published var triggerPillHeight: Double {
        didSet { defaults.set(triggerPillHeight, forKey: Keys.triggerPillHeight) }
    }

    @Published var triggerPillCornerRadius: Double {
        didSet { defaults.set(triggerPillCornerRadius, forKey: Keys.triggerPillCornerRadius) }
    }

    @Published var horizontalOffset: Double {
        didSet { defaults.set(horizontalOffset, forKey: Keys.horizontalOffset) }
    }

    // Allowed panel size range.
    static let minPanelWidth: Double = 460
    static let maxPanelWidth: Double = 1200
    static let minPanelHeight: Double = 320
    static let maxPanelHeight: Double = 860
    static let defaultPanelWidth: Double = 760
    static let defaultPanelHeight: Double = 540

    // Trigger-pill (non-notch) range + defaults.
    static let minPillWidth: Double = 120
    static let maxPillWidth: Double = 600
    static let defaultPillWidth: Double = 220
    static let minPillHeight: Double = 20
    static let maxPillHeight: Double = 60
    static let defaultPillHeight: Double = 28
    static let minPillCorner: Double = 0
    static let maxPillCorner: Double = 22
    static let defaultPillCorner: Double = 12

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let skipSensitive = "skipSensitive"
        static let maxItems = "maxItems"
        static let panelWidth = "panelWidth"
        static let panelHeight = "panelHeight"
        static let autoDeleteMinutes = "autoDeleteMinutes"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let triggerPillWidth = "triggerPillWidth"
        static let triggerPillHeight = "triggerPillHeight"
        static let triggerPillCornerRadius = "triggerPillCornerRadius"
        static let horizontalOffset = "horizontalOffset"
        static let autoPasteEnabled = "autoPasteEnabled"
        static let captureHUDEnabled = "captureHUDEnabled"
        static let hideFromScreenCapture = "hideFromScreenCapture"
        static let hotkeyCode = "hotkeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
    }

    private init() {
        defaults.register(defaults: [
            Keys.skipSensitive: true,
            Keys.maxItems: 100,
            Keys.panelWidth: Self.defaultPanelWidth,
            Keys.panelHeight: Self.defaultPanelHeight,
            Keys.triggerPillWidth: Self.defaultPillWidth,
            Keys.triggerPillHeight: Self.defaultPillHeight,
            Keys.triggerPillCornerRadius: Self.defaultPillCorner,
            Keys.horizontalOffset: 0.0,
            Keys.autoPasteEnabled: false,
            Keys.captureHUDEnabled: true,
            Keys.hideFromScreenCapture: true,
            Keys.hotkeyCode: kVK_ANSI_V,
            Keys.hotkeyModifiers: cmdKey | shiftKey
        ])
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        skipSensitive = defaults.bool(forKey: Keys.skipSensitive)
        maxItems = defaults.integer(forKey: Keys.maxItems)
        panelWidth = defaults.double(forKey: Keys.panelWidth)
        panelHeight = defaults.double(forKey: Keys.panelHeight)
        autoDeleteMinutes = defaults.integer(forKey: Keys.autoDeleteMinutes)
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        triggerPillWidth = defaults.double(forKey: Keys.triggerPillWidth)
        triggerPillHeight = defaults.double(forKey: Keys.triggerPillHeight)
        triggerPillCornerRadius = defaults.double(forKey: Keys.triggerPillCornerRadius)
        horizontalOffset = defaults.double(forKey: Keys.horizontalOffset)
        autoPasteEnabled = defaults.bool(forKey: Keys.autoPasteEnabled)
        captureHUDEnabled = defaults.bool(forKey: Keys.captureHUDEnabled)
        hideFromScreenCapture = defaults.bool(forKey: Keys.hideFromScreenCapture)
        hotkeyCode = defaults.integer(forKey: Keys.hotkeyCode)
        hotkeyModifiers = defaults.integer(forKey: Keys.hotkeyModifiers)
    }

    /// Reflects the actual registration state on launch.
    func syncLaunchAtLoginState() {
        let registered = SMAppService.mainApp.status == .enabled
        if registered != launchAtLogin {
            launchAtLogin = registered
        }
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("NotchBoard: launch-at-login update failed: \(error)")
        }
    }
}
