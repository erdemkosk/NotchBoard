import AppKit

/// Checks GitHub Releases for a newer build, downloads the zipped app, and
/// performs an in-place self-update + relaunch.
@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case downloading
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var latestVersion: String?

    private var downloadURL: URL?
    private var lastCheck: Date?

    var currentVersion: String { AppInfo.version }

    // MARK: - Check

    /// Checks for updates. `silent` suppresses the "up to date" state churn used
    /// by the automatic launch check.
    func checkForUpdates(silent: Bool = false) {
        if case .downloading = state { return }
        if case .installing = state { return }
        state = .checking

        Task {
            do {
                let release = try await fetchLatestRelease()
                let latest = release.version
                latestVersion = latest
                downloadURL = release.assetURL

                if Self.isNewer(latest, than: currentVersion), release.assetURL != nil {
                    state = .available(version: latest)
                } else {
                    state = silent ? .idle : .upToDate
                }
                lastCheck = Date()
            } catch {
                state = silent ? .idle : .failed(error.localizedDescription)
            }
        }
    }

    /// Automatic check at most once every 6 hours.
    func checkOnLaunchIfDue() {
        if let last = lastCheck, Date().timeIntervalSince(last) < 6 * 3600 { return }
        checkForUpdates(silent: true)
    }

    // MARK: - Install

    func openReleasesPage() {
        NSWorkspace.shared.open(AppInfo.releasesURL)
    }

    func downloadAndInstall() {
        guard let url = downloadURL else { openReleasesPage(); return }
        state = .downloading

        Task {
            do {
                let (tempFile, _) = try await URLSession.shared.download(from: url)
                state = .installing
                try await Self.installUpdate(zip: tempFile)
                // installUpdate relaunches via a helper script; quit now.
                NSApp.terminate(nil)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - GitHub API

    private struct Release {
        let version: String
        let assetURL: URL?
    }

    private func fetchLatestRelease() async throws -> Release {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(AppInfo.repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("NotchBoard", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "NotchBoard.Update", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: L.t("No releases found.", "Yayın bulunamadı.")])
        }

        struct APIRelease: Decodable {
            let tag_name: String
            let assets: [APIAsset]
        }
        struct APIAsset: Decodable {
            let name: String
            let browser_download_url: String
        }

        let decoded = try JSONDecoder().decode(APIRelease.self, from: data)
        let version = decoded.tag_name.hasPrefix("v")
            ? String(decoded.tag_name.dropFirst())
            : decoded.tag_name
        let asset = decoded.assets.first { $0.name.lowercased().hasSuffix(".zip") }
        return Release(version: version, assetURL: asset.flatMap { URL(string: $0.browser_download_url) })
    }

    // MARK: - Version compare

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        }
        let a = parts(candidate)
        let b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: - Self-update

    nonisolated private static func installUpdate(zip: URL) async throws {
        let fm = FileManager.default
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else {
            throw NSError(domain: "NotchBoard.Update", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: L.t("Updates require the .app bundle.", "Güncelleme .app paketi gerektirir.")])
        }

        let work = fm.temporaryDirectory.appendingPathComponent("NotchBoardUpdate-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)

        // Unzip with ditto (preserves the bundle structure).
        try run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path])

        guard let newApp = fm.enumerator(at: work, includingPropertiesForKeys: nil)?
            .compactMap({ $0 as? URL })
            .first(where: { $0.pathExtension == "app" }) else {
            throw NSError(domain: "NotchBoard.Update", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: L.t("Downloaded archive was invalid.", "İndirilen arşiv geçersiz.")])
        }

        // A detached script swaps the bundle once we quit, then relaunches.
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = work.appendingPathComponent("install.sh")
        let contents = """
        #!/bin/bash
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        rm -rf "\(bundleURL.path)"
        cp -R "\(newApp.path)" "\(bundleURL.path)"
        xattr -dr com.apple.quarantine "\(bundleURL.path)" 2>/dev/null
        open "\(bundleURL.path)"
        """
        try contents.write(to: script, atomically: true, encoding: .utf8)
        try run("/bin/chmod", ["+x", script.path])

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [script.path]
        try task.run()
    }

    nonisolated private static func run(_ launchPath: String, _ args: [String]) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = args
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            throw NSError(domain: "NotchBoard.Update", code: Int(task.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(launchPath) failed"])
        }
    }
}
