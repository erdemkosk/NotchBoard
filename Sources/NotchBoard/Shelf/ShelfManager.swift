import AppKit
import Combine

/// Holds files/images dropped onto the notch so they can be re-dragged elsewhere.
@MainActor
final class ShelfManager: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    private var shelfDirectory: URL {
        let dir = Persistence.supportDirectory.appendingPathComponent("shelf", isDirectory: true)
        Persistence.ensureDirectory(dir)
        return dir
    }

    init() {
        loadFromDisk()
    }

    /// Copies a source file into the shelf cache and registers it.
    @discardableResult
    func addFile(at sourceURL: URL) -> ShelfItem? {
        // Ignore drops of files that already live in the shelf (dragging an
        // item out and back in) so we don't create duplicates.
        if isInShelf(sourceURL) { return nil }
        let safeName = sourceURL.lastPathComponent
        let dest = uniqueDestination(for: safeName)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: dest)
        } catch {
            return nil
        }
        let item = ShelfItem(fileURL: dest, displayName: safeName)
        items.insert(item, at: 0)
        persist()
        return item
    }

    /// Writes raw image data (e.g. a dropped bitmap with no file URL) to the shelf.
    @discardableResult
    func addImageData(_ data: Data, suggestedName: String = "image.png") -> ShelfItem? {
        let dest = uniqueDestination(for: suggestedName)
        do {
            try data.write(to: dest)
        } catch {
            return nil
        }
        let item = ShelfItem(fileURL: dest, displayName: suggestedName)
        items.insert(item, at: 0)
        persist()
        return item
    }

    /// Promotes a clipboard image/file into the shelf.
    @discardableResult
    func add(from clip: ClipboardItem) -> ShelfItem? {
        guard let url = clip.fileURL else { return nil }
        return addFile(at: url)
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        try? FileManager.default.removeItem(at: item.fileURL)
        persist()
    }

    func clearAll() {
        for item in items {
            try? FileManager.default.removeItem(at: item.fileURL)
        }
        items.removeAll()
        persist()
    }

    /// Whether the URL already points inside the shelf storage directory.
    private func isInShelf(_ url: URL) -> Bool {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        let shelfDir = shelfDirectory.resolvingSymlinksInPath().standardizedFileURL
        if resolved.deletingLastPathComponent() == shelfDir { return true }
        if items.contains(where: {
            $0.fileURL.resolvingSymlinksInPath().standardizedFileURL == resolved
        }) { return true }

        // A shelf tile dragged out and dropped back arrives as a fresh temp copy
        // with a different path, so the path checks above miss it and we'd keep
        // duplicating it. Treat it as already-present when an existing shelf item
        // has the same byte size and a matching base name. This covers every file
        // type (not just images), which the path checks alone did not.
        guard let droppedSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return false
        }
        let droppedBase = Self.baseName(url.lastPathComponent)
        return items.contains { item in
            let itemSize = (try? item.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1
            guard itemSize == droppedSize else { return false }
            let names = [item.fileURL.lastPathComponent, item.displayName].map(Self.baseName)
            return names.contains { $0 == droppedBase || droppedBase.hasPrefix($0) || $0.hasPrefix(droppedBase) }
        }
    }

    /// Filename without its extension and trailing copy suffixes the OS or our own
    /// `uniqueDestination` adds (e.g. "report-1", "report 2", "report copy").
    private nonisolated static func baseName(_ name: String) -> String {
        var b = (name as NSString).deletingPathExtension.lowercased()
        b = b.replacingOccurrences(
            of: #"[ \-_]*(copy|kopya|\d+)$"#,
            with: "",
            options: .regularExpression
        )
        return b.trimmingCharacters(in: .whitespaces)
    }

    private func uniqueDestination(for name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = shelfDirectory.appendingPathComponent(name)
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            candidate = shelfDirectory.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }

    // MARK: - Persistence

    private struct StoredItem: Codable {
        let id: UUID
        let fileName: String
        let displayName: String
        let addedAt: Date
    }

    private func persist() {
        let stored = items.map {
            StoredItem(
                id: $0.id,
                fileName: $0.fileURL.lastPathComponent,
                displayName: $0.displayName,
                addedAt: $0.addedAt
            )
        }
        Persistence.save(stored, to: Persistence.shelfIndexURL)
    }

    private func loadFromDisk() {
        guard let stored = Persistence.load([StoredItem].self, from: Persistence.shelfIndexURL) else {
            return
        }
        items = stored.compactMap { s in
            let url = shelfDirectory.appendingPathComponent(s.fileName)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return ShelfItem(id: s.id, fileURL: url, displayName: s.displayName, addedAt: s.addedAt)
        }
    }
}
