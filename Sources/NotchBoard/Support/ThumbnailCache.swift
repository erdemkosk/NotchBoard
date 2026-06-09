import AppKit
import ImageIO

struct SendableImage: @unchecked Sendable {
    let image: NSImage
}

/// Generates and caches downsized thumbnails so grids stay smooth even with many
/// images. Avoids loading full-resolution NSImages on every redraw.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.notchboard.thumbnails", qos: .userInitiated, attributes: .concurrent)

    private init() {
        cache.countLimit = 300
    }

    /// Returns a cached thumbnail synchronously if present.
    func cached(for url: URL, maxPixel: CGFloat) -> NSImage? {
        cache.object(forKey: key(url, maxPixel) as NSString)
    }

    /// Loads (or generates) a thumbnail off the main thread.
    func thumbnail(for url: URL, maxPixel: CGFloat) async -> SendableImage? {
        let k = key(url, maxPixel)
        if let hit = cache.object(forKey: k as NSString) {
            return SendableImage(image: hit)
        }
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                let image = Self.makeThumbnail(url: url, maxPixel: maxPixel)
                if let image {
                    self?.cache.setObject(image, forKey: k as NSString)
                    continuation.resume(returning: SendableImage(image: image))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func key(_ url: URL, _ maxPixel: CGFloat) -> String {
        "\(url.path)|\(Int(maxPixel))"
    }

    private static func makeThumbnail(url: URL, maxPixel: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            // Non-image files: fall back to the system file icon.
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}
