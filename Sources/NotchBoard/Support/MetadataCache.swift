import AppKit
import ImageIO

/// Generates and caches metadata (file size and image pixel dimensions)
/// off the main thread to prevent UI freezes in grids.
final class MetadataCache: @unchecked Sendable {
    static let shared = MetadataCache()

    struct Info: Sendable {
        let sizeString: String?
        let pixelSize: CGSize?
    }

    private let cache = NSCache<NSString, InfoWrapper>()
    private let queue = DispatchQueue(label: "com.notchboard.metadata", qos: .userInitiated, attributes: .concurrent)

    private init() {
        cache.countLimit = 500
    }

    /// Returns the cached metadata synchronously if present.
    func cached(for url: URL) -> Info? {
        cache.object(forKey: url.path as NSString)?.info
    }

    /// Loads (or generates) metadata off the main thread, then calls back on main.
    func info(for url: URL, isImage: Bool, completion: @escaping @Sendable (Info) -> Void) {
        let path = url.path
        if let hit = cache.object(forKey: path as NSString) {
            completion(hit.info)
            return
        }

        queue.async { [weak self] in
            guard let self else { return }
            
            // 1. File size
            let sizeString: String?
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                sizeString = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            } else {
                sizeString = nil
            }

            // 2. Pixel size
            var pixelSize: CGSize? = nil
            if isImage,
               let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
               let w = props[kCGImagePropertyPixelWidth] as? Int,
               let h = props[kCGImagePropertyPixelHeight] as? Int {
                pixelSize = CGSize(width: w, height: h)
            }

            let info = Info(sizeString: sizeString, pixelSize: pixelSize)
            self.cache.setObject(InfoWrapper(info), forKey: path as NSString)

            DispatchQueue.main.async {
                completion(info)
            }
        }
    }
}

/// Objective-C wrapper around Info struct so it can be stored in NSCache.
final class InfoWrapper: NSObject {
    let info: MetadataCache.Info
    init(_ info: MetadataCache.Info) {
        self.info = info
    }
}
