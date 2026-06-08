import AppKit
import ImageIO

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
        cache.object(forKey: key(url, maxPixel))
    }

    /// Loads (or generates) a thumbnail off the main thread, then calls back on main.
    func thumbnail(for url: URL, maxPixel: CGFloat, completion: @escaping (NSImage?) -> Void) {
        let k = key(url, maxPixel)
        if let hit = cache.object(forKey: k) {
            completion(hit)
            return
        }
        queue.async { [weak self] in
            let image = Self.makeThumbnail(url: url, maxPixel: maxPixel)
            if let image { self?.cache.setObject(image, forKey: k) }
            DispatchQueue.main.async { completion(image) }
        }
    }

    private func key(_ url: URL, _ maxPixel: CGFloat) -> NSString {
        "\(url.path)|\(Int(maxPixel))" as NSString
    }

    private static func makeThumbnail(url: URL, maxPixel: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            // Non-image files: fall back to the system file icon.
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}
