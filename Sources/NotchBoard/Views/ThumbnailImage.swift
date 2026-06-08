import SwiftUI

/// Async, cached thumbnail view. Shows a fallback while the thumbnail loads, and
/// uses the system file icon for non-image files.
struct ThumbnailImage: View {
    let url: URL
    var maxPixel: CGFloat = 256
    var contentMode: ContentMode = .fill
    /// Used for non-image files (icon fallback).
    var fallbackIcon: NSImage?

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let fallbackIcon {
                Image(nsImage: fallbackIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(18)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .onAppear(perform: load)
        .onChange(of: url) { _, _ in image = nil; load() }
    }

    private func load() {
        if let hit = ThumbnailCache.shared.cached(for: url, maxPixel: maxPixel) {
            image = hit
            return
        }
        ThumbnailCache.shared.thumbnail(for: url, maxPixel: maxPixel) { result in
            self.image = result
        }
    }
}
