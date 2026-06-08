import AppKit
import ImageIO
import UniformTypeIdentifiers

/// A single captured clipboard entry.
struct ClipboardItem: Identifiable, Equatable {
    enum Kind: String, Codable {
        case text
        case link
        case image
        case file
        case color
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date

    /// Plain-text payload (text, link string, hex color, file path).
    var text: String?
    /// On-disk location for image/file payloads (cached under Application Support).
    var fileURL: URL?
    /// Name of the app the content came from, if known.
    var sourceAppName: String?
    /// Icon of the source app.
    var sourceAppIcon: NSImage?
    /// Whether the user starred this item.
    var isFavorite: Bool
    /// User-defined labels for categorization (e.g. "API", "key").
    var tags: [String]

    init(
        id: UUID = UUID(),
        kind: Kind,
        createdAt: Date = Date(),
        text: String? = nil,
        fileURL: URL? = nil,
        sourceAppName: String? = nil,
        sourceAppIcon: NSImage? = nil,
        isFavorite: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.text = text
        self.fileURL = fileURL
        self.sourceAppName = sourceAppName
        self.sourceAppIcon = sourceAppIcon
        self.isFavorite = isFavorite
        self.tags = tags
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    /// Preview image for image-type items.
    var previewImage: NSImage? {
        guard kind == .image, let fileURL else { return nil }
        return NSImage(contentsOf: fileURL)
    }

    /// Color parsed from a stored hex string (color items).
    var color: NSColor? {
        guard kind == .color, let text else { return nil }
        return NSColor(hex: text)
    }

    /// Human-readable file size for image/file items.
    var fileSizeString: String? {
        guard let fileURL,
              let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    /// Pixel dimensions for image items (read cheaply from metadata).
    var pixelSize: CGSize? {
        guard kind == .image, let fileURL,
              let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return CGSize(width: w, height: h)
    }

    /// "R G B" string for color items.
    var rgbString: String? {
        guard kind == .color, let c = color?.usingColorSpace(.sRGB) else { return nil }
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return "\(r) \(g) \(b)"
    }

    /// A short human-readable subtitle shown on the card.
    var subtitle: String {
        switch kind {
        case .text: return "Text"
        case .link: return linkDisplay ?? "Link"
        case .image: return "Image"
        case .file: return fileURL?.pathExtension.uppercased() ?? "File"
        case .color: return text ?? "Color"
        }
    }

    /// Host portion of a link item (e.g. "erdemkosk.com"), without "www.".
    var linkHost: String? {
        guard kind == .link, let text,
              let host = URL(string: text)?.host else { return nil }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    /// Readable full link (host + path + query) without the scheme or "www.",
    /// so different pages on the same site stay distinguishable on the card.
    var linkDisplay: String? {
        guard kind == .link, let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var display = trimmed
        if let range = display.range(of: "://") {
            display = String(display[range.upperBound...])
        }
        if display.lowercased().hasPrefix("www.") {
            display = String(display.dropFirst(4))
        }
        while display.hasSuffix("/") { display.removeLast() }
        return display.isEmpty ? linkHost : display
    }
}
