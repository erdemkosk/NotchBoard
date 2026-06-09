import AppKit
import UniformTypeIdentifiers

/// A file or image parked on the shelf, ready to be dragged into another app.
struct ShelfItem: Identifiable, Equatable {
    let id: UUID
    /// Cached copy living under Application Support.
    let fileURL: URL
    let displayName: String
    let addedAt: Date
    /// The collection (shelf tab) this item belongs to.
    var collectionID: UUID

    let isImage: Bool
    let isDirectory: Bool

    init(
        id: UUID = UUID(),
        fileURL: URL,
        displayName: String? = nil,
        addedAt: Date = Date(),
        collectionID: UUID
    ) {
        self.id = id
        self.fileURL = fileURL
        self.displayName = displayName ?? fileURL.lastPathComponent
        self.addedAt = addedAt
        self.collectionID = collectionID

        let ext = fileURL.pathExtension.lowercased()
        self.isImage = ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp"].contains(ext)

        var isDir: ObjCBool = false
        self.isDirectory = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir) && isDir.boolValue
    }

    static func == (lhs: ShelfItem, rhs: ShelfItem) -> Bool { lhs.id == rhs.id }

    /// Thumbnail: the image itself for images, otherwise the file's system icon.
    var thumbnail: NSImage {
        if let cached = ThumbnailCache.shared.cached(for: fileURL, maxPixel: 256) {
            return cached
        }
        // Return a generic fallback icon immediately without hitting the disk synchronously.
        if isDirectory {
            return NSWorkspace.shared.icon(for: .folder)
        } else {
            return NSWorkspace.shared.icon(for: .item)
        }
    }

    var fileExtension: String {
        fileURL.pathExtension.uppercased()
    }
}
