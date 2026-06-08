import Foundation

/// Bundles one or more files into a single `.zip` archive using `/usr/bin/ditto`.
enum ZipArchiver {
    /// Creates a zip archive of the given files in a temporary directory and
    /// returns its URL. Returns nil on failure or when given no files.
    static func makeArchive(of urls: [URL], named archiveName: String) -> URL? {
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else { return nil }

        let fm = FileManager.default
        // Stage the files in a uniquely named folder so ditto's --keepParent
        // produces a single top-level folder inside the zip.
        let stageRoot = fm.temporaryDirectory
            .appendingPathComponent("NotchBoardZip-\(UUID().uuidString)", isDirectory: true)
        let stageDir = stageRoot.appendingPathComponent(archiveName, isDirectory: true)
        defer { try? fm.removeItem(at: stageRoot) }

        do {
            try fm.createDirectory(at: stageDir, withIntermediateDirectories: true)
            for url in existing {
                var dest = stageDir.appendingPathComponent(url.lastPathComponent)
                var counter = 1
                while fm.fileExists(atPath: dest.path) {
                    let base = (url.lastPathComponent as NSString).deletingPathExtension
                    let ext = (url.lastPathComponent as NSString).pathExtension
                    let name = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
                    dest = stageDir.appendingPathComponent(name)
                    counter += 1
                }
                try fm.copyItem(at: url, to: dest)
            }
        } catch {
            return nil
        }

        let output = stageRoot.appendingPathComponent("\(archiveName).zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", stageDir.path, output.path]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0, fm.fileExists(atPath: output.path) else { return nil }

        // Move the archive out of the staging root (which is deleted on return).
        let final = fm.temporaryDirectory.appendingPathComponent("\(archiveName)-\(UUID().uuidString).zip")
        do {
            try fm.moveItem(at: output, to: final)
        } catch {
            return nil
        }
        return final
    }
}
