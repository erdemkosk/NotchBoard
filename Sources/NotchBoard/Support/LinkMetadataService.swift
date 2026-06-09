import AppKit
import LinkPresentation

/// Fetches and caches rich link metadata (title + icon/image) for link cards.
/// Views observe `cache` and re-render when an entry arrives.
@MainActor
final class LinkMetadataService: ObservableObject {
    static let shared = LinkMetadataService()

    struct Meta: @unchecked Sendable {
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

        Task {
            let meta = await Self.loadMetadata(for: url)
            self.inFlight.remove(urlString)
            self.cache[urlString] = meta
        }
    }

    /// Drives LinkPresentation from a nonisolated context.
    private nonisolated static func loadMetadata(for url: URL) async -> Meta {
        await withCheckedContinuation { continuation in
            let provider = LPMetadataProvider()
            provider.startFetchingMetadata(for: url) { metadata, _ in
                let host = url.host ?? url.absoluteString
                let title = metadata?.title ?? host
                guard let imageProvider = metadata?.imageProvider ?? metadata?.iconProvider else {
                    continuation.resume(returning: Meta(title: title, image: nil))
                    return
                }
                imageProvider.loadObject(ofClass: NSImage.self) { object, _ in
                    continuation.resume(returning: Meta(title: title, image: object as? NSImage))
                }
            }
        }
    }
}
