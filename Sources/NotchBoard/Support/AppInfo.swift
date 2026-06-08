import Foundation

/// Static facts about this build (version, update repository).
enum AppInfo {
    /// GitHub repository used for auto-update checks (owner/name).
    static let repo = "erdemkosk/NotchBoard"

    /// Marketing version, e.g. "0.1.42". Read from the bundle Info.plist.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// Build number.
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    static var releasesURL: URL {
        URL(string: "https://github.com/\(repo)/releases")!
    }

    /// Developer's personal website.
    static var websiteURL: URL {
        URL(string: "https://erdemkosk.com")!
    }
}
