import AppKit
import LinkPresentation

/// Fetches and caches rich link metadata (title + icon/image) for link cards.
/// Views observe `cache` and re-render when an entry arrives.
@MainActor
final class LinkMetadataService: ObservableObject {
    static let shared = LinkMetadataService()

    struct Meta {
        var title: String?
        var image: NSImage?
    }

    @Published private(set) var cache: [String: Meta] = [:]
    private var inFlight: Set<String> = []

    func cached(for urlString: String) -> Meta? { cache[urlString] }

    func fetch(_ urlString: String) {
        guard cache[urlString] == nil, !inFlight.contains(urlString),
              let url = URL(string: urlString) else { return }
        inFlight.insert(urlString)

        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metadata, _ in
            // Runs off the main thread; hop back with an unchecked capture since
            // LPLinkMetadata / NSImage are not Sendable.
            nonisolated(unsafe) let md = metadata
            DispatchQueue.main.async {
                self.finish(urlString: urlString, url: url, metadata: md)
            }
        }
    }

    private func finish(urlString: String, url: URL, metadata: LPLinkMetadata?) {
        let host = url.host ?? urlString
        var meta = Meta(title: metadata?.title ?? host, image: nil)

        guard let imageProvider = metadata?.imageProvider ?? metadata?.iconProvider else {
            inFlight.remove(urlString)
            cache[urlString] = meta
            return
        }

        imageProvider.loadObject(ofClass: NSImage.self) { object, _ in
            nonisolated(unsafe) let image = object as? NSImage
            DispatchQueue.main.async {
                meta.image = image
                self.inFlight.remove(urlString)
                self.cache[urlString] = meta
            }
        }
    }
}
