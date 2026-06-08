import Foundation

/// Filesystem locations and small JSON helpers for persisting app state.
enum Persistence {
    static let appName = "NotchBoard"

    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(appName, isDirectory: true)
        ensureDirectory(dir)
        return dir
    }

    /// Cached binary payloads (images, dropped files).
    static var cacheDirectory: URL {
        let dir = supportDirectory.appendingPathComponent("cache", isDirectory: true)
        ensureDirectory(dir)
        return dir
    }

    static var historyIndexURL: URL {
        supportDirectory.appendingPathComponent("history.json")
    }

    static var shelfIndexURL: URL {
        supportDirectory.appendingPathComponent("shelf.json")
    }

    static func ensureDirectory(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    static func save<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
}
