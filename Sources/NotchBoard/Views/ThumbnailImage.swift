import SwiftUI
import UniformTypeIdentifiers

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
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .onAppear(perform: load)
        .onChange(of: url) { _, _ in image = nil; load() }
    }

    @MainActor
    private func load() {
        if let hit = ThumbnailCache.shared.cached(for: url, maxPixel: maxPixel) {
            image = hit
            return
        }
        Task {
            let result = await ThumbnailCache.shared.thumbnail(for: url, maxPixel: maxPixel)
            if let result = result {
                self.image = result
            } else {
                // Fall back to a lightweight, instant generic icon (without hitting the disk for a path)
                let isDir = url.pathExtension.isEmpty
                if isDir {
                    self.image = NSWorkspace.shared.icon(for: .folder)
                } else {
                    self.image = NSWorkspace.shared.icon(for: .item)
                }
            }
        }
    }
}
