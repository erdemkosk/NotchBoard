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

    private func destination(for name: String, itemId: UUID) -> URL {
        let dir = shelfDirectory.appendingPathComponent(itemId.uuidString, isDirectory: true)
        Persistence.ensureDirectory(dir)
        return dir.appendingPathComponent(name)
    }

    /// Copies a source file into the shelf cache and registers it in the given
    /// collection (defaults to the selected one).
    func addFile(at sourceURL: URL, suggestedName: String? = nil, deleteSourceOnSuccess: Bool = false, to collectionID: UUID? = nil) {
        print("[DEBUG] --- addFile: sourceURL: \(sourceURL), suggestedName: \(String(describing: suggestedName))")
        
        let cid = collectionID ?? selectedCollectionID
        let itemsSnapshot = self.items
        let shelfDir = self.shelfDirectory
        
        Task.detached(priority: .userInitiated) {
            // Check duplicates in the background to avoid main-thread disk I/O
            if Self.checkIsInShelf(sourceURL, shelfDirectory: shelfDir, items: itemsSnapshot) {
                print("[DEBUG] --- addFile: Item already in shelf, skipping.")
                return
            }
            
            var safeName = sourceURL.lastPathComponent
            if let suggestedName = suggestedName, !suggestedName.isEmpty {
                let ext = sourceURL.pathExtension
                if !ext.isEmpty && !suggestedName.lowercased().hasSuffix(".\(ext.lowercased())") {
                    safeName = "\(suggestedName).\(ext)"
                } else {
                    safeName = suggestedName
                }
            }

            let itemId = UUID()
            let dir = shelfDir.appendingPathComponent(itemId.uuidString, isDirectory: true)
            // Create directory in background to avoid blocking main thread
            if !FileManager.default.fileExists(atPath: dir.path) {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            let dest = dir.appendingPathComponent(safeName)
            
            do {
                try FileManager.default.copyItem(at: sourceURL, to: dest)
                if deleteSourceOnSuccess {
                    try? FileManager.default.removeItem(at: sourceURL)
                }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    let item = ShelfItem(
                        id: itemId,
                        fileURL: dest,
                        displayName: safeName,
                        collectionID: cid
                    )
                    self.items.insert(item, at: 0)
                    self.persist()
                }
            } catch {
                print("Failed to copy item in background: \(error)")
            }
        }
    }

    /// Writes raw image data (e.g. a dropped bitmap with no file URL) to the shelf.
    @discardableResult
    func addImageData(_ data: Data, suggestedName: String = "image.png", to collectionID: UUID? = nil) -> ShelfItem? {
        let itemId = UUID()
        let dest = destination(for: suggestedName, itemId: itemId)
        do {
            try data.write(to: dest)
        } catch {
            return nil
        }
        let item = ShelfItem(
            id: itemId,
            fileURL: dest,
            displayName: suggestedName,
            collectionID: collectionID ?? selectedCollectionID
        )
        items.insert(item, at: 0)
        persist()
        return item
    }

    /// Promotes a clipboard image/file into the shelf.
    func add(from clip: ClipboardItem) {
        guard let url = clip.fileURL else { return }
        addFile(at: url)
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        selection.remove(item.id)
        try? FileManager.default.removeItem(at: item.fileURL)
        let parentDir = item.fileURL.deletingLastPathComponent()
        if parentDir.lastPathComponent == item.id.uuidString {
            try? FileManager.default.removeItem(at: parentDir)
        }
        persist()
    }

    /// Removes the given item IDs (used by batch operations).
    func remove(ids: Set<UUID>) {
        for item in items where ids.contains(item.id) {
            try? FileManager.default.removeItem(at: item.fileURL)
            let parentDir = item.fileURL.deletingLastPathComponent()
            if parentDir.lastPathComponent == item.id.uuidString {
                try? FileManager.default.removeItem(at: parentDir)
            }
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
            let parentDir = item.fileURL.deletingLastPathComponent()
            if parentDir.lastPathComponent == item.id.uuidString {
                try? FileManager.default.removeItem(at: parentDir)
            }
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

    // MARK: - Dedup helpers

    /// Whether the URL already points inside the shelf storage directory.
    private nonisolated static func checkIsInShelf(_ url: URL, shelfDirectory: URL, items: [ShelfItem]) -> Bool {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        let shelfDir = shelfDirectory.resolvingSymlinksInPath().standardizedFileURL
        if resolved.deletingLastPathComponent() == shelfDir { return true }
        if resolved.deletingLastPathComponent().deletingLastPathComponent() == shelfDir { return true }
        
        let resolvedPath = resolved.path
        if items.contains(where: { $0.fileURL.standardizedFileURL.path == resolvedPath }) {
            return true
        }
        
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
        let droppedBase = baseName(url.lastPathComponent)
        return items.contains { item in
            let itemSize = (try? item.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1
            guard itemSize == droppedSize else { return false }
            let names = [item.fileURL.lastPathComponent, item.displayName].map(baseName)
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
                let flatUrl = shelfDirectory.appendingPathComponent(s.fileName)
                if FileManager.default.fileExists(atPath: flatUrl.path) {
                    guard let cid = s.collectionID ?? fallbackID else { return nil }
                    return ShelfItem(id: s.id, fileURL: flatUrl, displayName: s.displayName, addedAt: s.addedAt, collectionID: cid)
                }
                
                let nestedUrl = shelfDirectory.appendingPathComponent(s.id.uuidString).appendingPathComponent(s.fileName)
                if FileManager.default.fileExists(atPath: nestedUrl.path) {
                    guard let cid = s.collectionID ?? fallbackID else { return nil }
                    return ShelfItem(id: s.id, fileURL: nestedUrl, displayName: s.displayName, addedAt: s.addedAt, collectionID: cid)
                }
                
                return nil
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
