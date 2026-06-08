import AppKit

/// A file or image parked on the shelf, ready to be dragged into another app.
struct ShelfItem: Identifiable, Equatable {
    let id: UUID
    /// Cached copy living under Application Support.
    let fileURL: URL
    let displayName: String
    let addedAt: Date
    /// The collection (shelf tab) this item belongs to.
    var collectionID: UUID

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
    }

    static func == (lhs: ShelfItem, rhs: ShelfItem) -> Bool { lhs.id == rhs.id }

    var isImage: Bool {
        let ext = fileURL.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp"].contains(ext)
    }

    /// Thumbnail: the image itself for images, otherwise the file's system icon.
    var thumbnail: NSImage {
        if isImage, let img = NSImage(contentsOf: fileURL) {
            return img
        }
        return NSWorkspace.shared.icon(forFile: fileURL.path)
    }

    var fileExtension: String {
        fileURL.pathExtension.uppercased()
    }
}
