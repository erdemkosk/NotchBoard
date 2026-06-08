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

        Self.loadMetadata(for: url) { [weak self] title, image in
            // NSImage is not Sendable on every SDK, so silence the region-based
            // sending check explicitly before hopping back to the main actor.
            nonisolated(unsafe) let img = image
            Task { @MainActor in
                guard let self else { return }
                self.inFlight.remove(urlString)
                self.cache[urlString] = Meta(title: title, image: img)
            }
        }
    }

    /// Drives LinkPresentation from a nonisolated context. Its completion handlers
    /// fire on a private dispatch queue, so the callback passed in here must stay
    /// nonisolated (`@Sendable`). If it were inferred `@MainActor` (because this
    /// type is main-actor isolated), Swift 6's executor-isolation check would trap
    /// and crash the app when the callback runs off the main thread.
    private nonisolated static func loadMetadata(
        for url: URL,
        completion: @escaping @Sendable (String?, NSImage?) -> Void
    ) {
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metadata, _ in
            let host = url.host ?? url.absoluteString
            let title = metadata?.title ?? host
            guard let imageProvider = metadata?.imageProvider ?? metadata?.iconProvider else {
                completion(title, nil)
                return
            }
            imageProvider.loadObject(ofClass: NSImage.self) { object, _ in
                completion(title, object as? NSImage)
            }
        }
    }
}
