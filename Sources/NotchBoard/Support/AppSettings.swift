import Foundation
import Combine
import ServiceManagement

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

    @Published var autoPaste: Bool {
        didSet { defaults.set(autoPaste, forKey: Keys.autoPaste) }
    }

    @Published var skipSensitive: Bool {
        didSet { defaults.set(skipSensitive, forKey: Keys.skipSensitive) }
    }

    @Published var maxItems: Int {
        didSet { defaults.set(maxItems, forKey: Keys.maxItems) }
    }

    @Published var panelWidth: Double {
        didSet { defaults.set(panelWidth, forKey: Keys.panelWidth) }
    }

    @Published var panelHeight: Double {
        didSet { defaults.set(panelHeight, forKey: Keys.panelHeight) }
    }

    // Allowed panel size range.
    static let minPanelWidth: Double = 460
    static let maxPanelWidth: Double = 1200
    static let minPanelHeight: Double = 320
    static let maxPanelHeight: Double = 860
    static let defaultPanelWidth: Double = 760
    static let defaultPanelHeight: Double = 540

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let autoPaste = "autoPaste"
        static let skipSensitive = "skipSensitive"
        static let maxItems = "maxItems"
        static let panelWidth = "panelWidth"
        static let panelHeight = "panelHeight"
    }

    private init() {
        defaults.register(defaults: [
            Keys.skipSensitive: true,
            Keys.maxItems: 100,
            Keys.panelWidth: Self.defaultPanelWidth,
            Keys.panelHeight: Self.defaultPanelHeight
        ])
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        autoPaste = defaults.bool(forKey: Keys.autoPaste)
        skipSensitive = defaults.bool(forKey: Keys.skipSensitive)
        maxItems = defaults.integer(forKey: Keys.maxItems)
        panelWidth = defaults.double(forKey: Keys.panelWidth)
        panelHeight = defaults.double(forKey: Keys.panelHeight)
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
