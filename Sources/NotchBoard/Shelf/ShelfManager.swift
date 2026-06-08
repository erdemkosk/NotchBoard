import AppKit
import Combine

/// Holds files/images dropped onto the notch so they can be re-dragged elsewhere.
/// Items are grouped into named, colored collections (shelf tabs).
@MainActor
final class ShelfManager: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    @Published private(set) var collections: [ShelfCollection] = []
    @Published var selectedCollectionID: UUID = UUID()

    /// Multi-selection of shelf tiles for batch operations.
    @Published var selection: Set<UUID> = []

    private var shelfDirectory: URL {
        let dir = Persistence.supportDirectory.appendingPathComponent("shelf", isDirectory: true)
        Persistence.ensureDirectory(dir)
        return dir
    }

    init() {
        loadFromDisk()
        ensureAtLeastOneCollection()
    }

    // MARK: - Collections

    /// The currently selected collection (falls back to the first).
    var selectedCollection: ShelfCollection? {
        collections.first { $0.id == selectedCollectionID } ?? collections.first
    }

    /// Items belonging to the given collection, newest first (preserving order).
    func items(in collectionID: UUID) -> [ShelfItem] {
        items.filter { $0.collectionID == collectionID }
    }

    /// Items in the currently selected collection.
    var visibleItems: [ShelfItem] {
        items(in: selectedCollectionID)
    }

    func count(in collectionID: UUID) -> Int {
        items.reduce(0) { $0 + ($1.collectionID == collectionID ? 1 : 0) }
    }

    @discardableResult
    func addCollection(name: String) -> ShelfCollection {
        let colorHex = ShelfCollection.palette[collections.count % ShelfCollection.palette.count]
        let collection = ShelfCollection(name: name, colorHex: colorHex)
        collections.append(collection)
        selectedCollectionID = collection.id
        persist()
        return collection
    }

    func renameCollection(_ id: UUID, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[idx].name = clean
        persist()
    }

    func recolorCollection(_ id: UUID, to colorHex: String) {
        guard let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[idx].colorHex = colorHex
        persist()
    }

    func toggleLockCollection(_ id: UUID) {
        guard let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[idx].isLocked.toggle()
        persist()
    }

    /// Removes a collection and all of its files. The last collection can't be
    /// removed (there must always be at least one).
    func removeCollection(_ id: UUID) {
        guard collections.count > 1 else { return }
        for item in items(in: id) {
            try? FileManager.default.removeItem(at: item.fileURL)
        }
        items.removeAll { $0.collectionID == id }
        collections.removeAll { $0.id == id }
        if selectedCollectionID == id {
            selectedCollectionID = collections.first?.id ?? selectedCollectionID
        }
        persist()
    }

    /// Moves the given items into another collection.
    func move(_ ids: Set<UUID>, to collectionID: UUID) {
        guard collections.contains(where: { $0.id == collectionID }) else { return }
        for idx in items.indices where ids.contains(items[idx].id) {
            items[idx].collectionID = collectionID
        }
        persist()
    }

    private func ensureAtLeastOneCollection() {
        if collections.isEmpty {
            let def = ShelfCollection.makeDefault(name: L.shelfDefaultName)
            collections = [def]
        }
        if !collections.contains(where: { $0.id == selectedCollectionID }) {
            selectedCollectionID = collections[0].id
        }
    }

    // MARK: - Items

    /// Copies a source file into the shelf cache and registers it in the given
    /// collection (defaults to the selected one).
    @discardableResult
    func addFile(at sourceURL: URL, to collectionID: UUID? = nil) -> ShelfItem? {
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
        let item = ShelfItem(
            fileURL: dest,
            displayName: safeName,
            collectionID: collectionID ?? selectedCollectionID
        )
        items.insert(item, at: 0)
        persist()
        return item
    }

    /// Writes raw image data (e.g. a dropped bitmap with no file URL) to the shelf.
    @discardableResult
    func addImageData(_ data: Data, suggestedName: String = "image.png", to collectionID: UUID? = nil) -> ShelfItem? {
        let dest = uniqueDestination(for: suggestedName)
        do {
            try data.write(to: dest)
        } catch {
            return nil
        }
        let item = ShelfItem(
            fileURL: dest,
            displayName: suggestedName,
            collectionID: collectionID ?? selectedCollectionID
        )
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
        selection.remove(item.id)
        try? FileManager.default.removeItem(at: item.fileURL)
        persist()
    }

    /// Removes the given item IDs (used by batch operations).
    func remove(ids: Set<UUID>) {
        for item in items where ids.contains(item.id) {
            try? FileManager.default.removeItem(at: item.fileURL)
        }
        items.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
        persist()
    }

    /// Removes every item in the currently selected collection.
    func clearSelectedCollection() {
        let ids = Set(visibleItems.map { $0.id })
        remove(ids: ids)
    }

    func clearAll() {
        for item in items {
            try? FileManager.default.removeItem(at: item.fileURL)
        }
        items.removeAll()
        selection.removeAll()
        persist()
    }

    // MARK: - Selection helpers

    func toggleSelection(_ id: UUID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    func clearSelection() {
        selection.removeAll()
    }

    /// Resolved file URLs for the current selection, in display order.
    var selectedURLs: [URL] {
        visibleItems.filter { selection.contains($0.id) }.map { $0.fileURL }
    }

    // MARK: - Dedup helpers

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
        // Optional so the legacy flat array (pre-collections) still decodes.
        var collectionID: UUID?
    }

    /// New on-disk envelope: collections plus their items.
    private struct StoredShelf: Codable {
        var collections: [ShelfCollection]
        var items: [StoredItem]
    }

    private func persist() {
        let stored = items.map {
            StoredItem(
                id: $0.id,
                fileName: $0.fileURL.lastPathComponent,
                displayName: $0.displayName,
                addedAt: $0.addedAt,
                collectionID: $0.collectionID
            )
        }
        let envelope = StoredShelf(collections: collections, items: stored)
        Persistence.save(envelope, to: Persistence.shelfIndexURL)
    }

    private func loadFromDisk() {
        // New format first.
        if let envelope = Persistence.load(StoredShelf.self, from: Persistence.shelfIndexURL) {
            collections = envelope.collections
            let fallbackID = envelope.collections.first?.id
            items = envelope.items.compactMap { s in
                let url = shelfDirectory.appendingPathComponent(s.fileName)
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                guard let cid = s.collectionID ?? fallbackID else { return nil }
                return ShelfItem(id: s.id, fileURL: url, displayName: s.displayName, addedAt: s.addedAt, collectionID: cid)
            }
            return
        }

        // Legacy migration: a flat [StoredItem] array with no collections.
        guard let legacy = Persistence.load([StoredItem].self, from: Persistence.shelfIndexURL) else {
            return
        }
        let def = ShelfCollection.makeDefault(name: L.shelfDefaultName)
        collections = [def]
        selectedCollectionID = def.id
        items = legacy.compactMap { s in
            let url = shelfDirectory.appendingPathComponent(s.fileName)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return ShelfItem(id: s.id, fileURL: url, displayName: s.displayName, addedAt: s.addedAt, collectionID: def.id)
        }
        persist()
    }
}
