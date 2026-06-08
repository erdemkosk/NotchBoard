import SwiftUI
import UniformTypeIdentifiers

/// Grid of parked files/images. Accepts drops from anywhere and lets items be
/// dragged back out into other apps.
struct ShelfView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var isTargeted = false

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 14)]

    var body: some View {
        ZStack {
            if viewModel.shelf.items.isEmpty {
                EmptyState(
                    icon: "tray.and.arrow.down",
                    title: L.emptyShelfTitle,
                    subtitle: L.emptyShelfSubtitle
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.shelf.items) { item in
                            ShelfCard(item: item)
                                .hoverFeedback()
                                .onDrag {
                                    DragProviders.beginDrag()
                                    DragProviders.draggingShelfItemID = item.id
                                    return DragProviders.provider(for: item)
                                } preview: {
                                    Image(nsImage: item.thumbnail)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 120, height: 120)
                                }
                                .contextMenu {
                                    Button(L.revealInFinder) {
                                        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
                                    }
                                    Divider()
                                    Button(L.remove, role: .destructive) {
                                        viewModel.shelf.remove(item)
                                    }
                                }
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.shelf.items.map(\.id))
                }
                .scrollIndicators(.never)
                .scrollEdgeFade()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.white.opacity(0.08),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                )
        )
        .onDrop(
            of: [.fileURL, .image, .png, .tiff, .pdf],
            isTargeted: $isTargeted
        ) { providers in
            handleDrop(providers)
        }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        // A shelf tile dragged and dropped back onto the shelf: consume it so we
        // don't duplicate it (the dropped data may be a temp copy URL).
        if DragProviders.draggingShelfItemID != nil {
            DragProviders.draggingShelfItemID = nil
            return true
        }
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: NSURL.self) {
                handled = true
                _ = provider.loadObject(ofClass: NSURL.self) { object, _ in
                    guard let url = object as? URL, url.isFileURL else { return }
                    Task { @MainActor in viewModel.shelf.addFile(at: url) }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                handled = true
                _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                    guard let image = object as? NSImage,
                          let tiff = image.tiffRepresentation,
                          let rep = NSBitmapImageRep(data: tiff),
                          let png = rep.representation(using: .png, properties: [:]) else { return }
                    Task { @MainActor in
                        viewModel.shelf.addImageData(png, suggestedName: "dropped-\(Int(Date().timeIntervalSince1970)).png")
                    }
                }
            }
        }
        return handled
    }
}

/// A single shelf tile: thumbnail plus filename.
private struct ShelfCard: View {
    let item: ShelfItem

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.white.opacity(0.05)
                if item.isImage {
                    ThumbnailImage(url: item.fileURL, maxPixel: 256, contentMode: .fill)
                } else {
                    Image(nsImage: item.thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(18)
                }
            }
            .frame(height: 96)
            .frame(maxWidth: .infinity)
            .clipped()

            HStack(spacing: 5) {
                Text(item.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
