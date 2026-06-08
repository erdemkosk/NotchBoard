import SwiftUI

/// Grid of clipboard history cards. Cards are clickable (re-copy) and draggable
/// out to other apps.
struct HistoryView: View {
    @ObservedObject var viewModel: NotchViewModel

    private let columns = [GridItem(.adaptive(minimum: 210, maximum: 260), spacing: 14)]

    private var filtered: [ClipboardItem] { viewModel.visibleHistory }

    var body: some View {
        Group {
            if viewModel.clipboard.items.isEmpty {
                EmptyState(
                    icon: "doc.on.clipboard",
                    title: L.emptyHistoryTitle,
                    subtitle: L.emptyHistorySubtitle
                )
            } else if filtered.isEmpty {
                EmptyState(
                    icon: viewModel.showFavoritesOnly ? "star" : "magnifyingglass",
                    title: viewModel.showFavoritesOnly ? L.emptyFavoritesTitle : L.noMatchesTitle,
                    subtitle: viewModel.showFavoritesOnly ? L.emptyFavoritesSubtitle : L.noMatchesSubtitle
                )
            } else {
                ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                            ClipboardCard(
                                item: item,
                                isCopied: viewModel.lastCopiedID == item.id,
                                isSelected: viewModel.selectedIndex == index,
                                onToggleFavorite: { viewModel.clipboard.toggleFavorite(item) }
                            )
                            .id(item.id)
                            .hoverFeedback()
                            .onTapGesture {
                                viewModel.selectAndCopy(item)
                            }
                            .onDrag {
                                DragProviders.beginDrag()
                                return DragProviders.provider(for: item)
                            } preview: {
                                DragPreview(item: item)
                            }
                            .contextMenu {
                                Button(L.copy) { viewModel.selectAndCopy(item) }
                                Button(item.isFavorite ? L.unpin : L.pin) {
                                    viewModel.clipboard.toggleFavorite(item)
                                }
                                Button(L.addTag) {
                                    if let tag = TagPrompt.run() {
                                        viewModel.clipboard.addTag(tag, to: item)
                                    }
                                }
                                if !item.tags.isEmpty {
                                    Menu(L.removeTag) {
                                        ForEach(item.tags, id: \.self) { tag in
                                            Button(tag) { viewModel.clipboard.removeTag(tag, from: item) }
                                        }
                                    }
                                }
                                if item.fileURL != nil {
                                    Button(L.addToShelf) { viewModel.shelf.add(from: item) }
                                }
                                Divider()
                                Button(L.delete, role: .destructive) {
                                    viewModel.clipboard.remove(item)
                                }
                            }
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: filtered.map(\.id))
                }
                .scrollIndicators(.never)
                .scrollEdgeFade()
                .onChange(of: viewModel.selectedIndex) { _, newValue in
                    guard filtered.indices.contains(newValue) else { return }
                    let id = filtered[newValue].id
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A single history card. Layout adapts to the item kind.
private struct ClipboardCard: View {
    let item: ClipboardItem
    var isCopied: Bool = false
    var isSelected: Bool = false
    var onToggleFavorite: () -> Void = {}

    private var borderColor: Color {
        if isCopied { return .accentColor }
        if isSelected { return .accentColor.opacity(0.8) }
        return .white.opacity(0.06)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            preview
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                .clipped()
            if !item.tags.isEmpty { tagRow }
            footer
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(borderColor, lineWidth: (isCopied || isSelected) ? 2 : 1)
        )
        .overlay(alignment: .topTrailing) { favoriteButton }
        .overlay {
            if isCopied { copiedBadge }
        }
        .scaleEffect(isCopied ? 0.96 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isCopied)
        .help(helpText)
    }

    /// Full, untruncated text shown as a native tooltip on hover (e.g. the
    /// complete URL for links).
    private var helpText: String {
        switch item.kind {
        case .link: return item.text ?? item.subtitle
        case .text, .file, .color: return item.text ?? item.subtitle
        case .image: return item.subtitle
        }
    }

    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(item.tags, id: \.self) { tag in
                    HStack(spacing: 3) {
                        Circle().fill(Color.tagColor(tag)).frame(width: 6, height: 6)
                        Text(tag)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.tagColor(tag).opacity(0.18), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 7)
        }
    }

    private var favoriteButton: some View {
        Button(action: onToggleFavorite) {
            Image(systemName: item.isFavorite ? "star.fill" : "star")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(item.isFavorite ? Color.yellow : Color.white.opacity(0.8))
                .padding(5)
                .background(.black.opacity(0.35), in: Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .padding(6)
        .opacity(item.isFavorite ? 1 : 0.85)
    }

    private var copiedBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.45))
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                Text("Copied")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .image:
            if let url = item.fileURL {
                ThumbnailImage(url: url, maxPixel: 256, contentMode: .fill)
                    .overlay(alignment: .bottomLeading) { imageBadge }
            } else {
                placeholder(icon: "photo")
            }
        case .color:
            colorPreview
        case .file:
            placeholder(icon: "doc.fill")
        case .link:
            LinkPreview(urlString: item.text ?? "")
        case .text:
            textPreview(icon: nil)
        }
    }

    private var imageBadge: some View {
        let parts = [
            item.pixelSize.map { "\(Int($0.width))×\(Int($0.height))" },
            item.fileSizeString
        ].compactMap { $0 }
        return Group {
            if !parts.isEmpty {
                Text(parts.joined(separator: " · "))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(6)
            }
        }
    }

    private var colorPreview: some View {
        ZStack {
            if let c = item.color {
                Color(nsColor: c)
            } else {
                placeholder(icon: "paintpalette")
            }
            VStack(spacing: 2) {
                Text((item.text ?? "").uppercased())
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                if let rgb = item.rgbString {
                    Text("RGB \(rgb)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .opacity(0.85)
                }
            }
            .foregroundStyle(textColor(on: item.color))
            .shadow(color: .black.opacity(0.25), radius: 2)
        }
    }

    private func textColor(on color: NSColor?) -> Color {
        guard let c = color?.usingColorSpace(.sRGB) else { return .white }
        // Luminance-based contrast pick.
        let lum = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        return lum > 0.6 ? .black : .white
    }

    private func textPreview(icon: String?) -> some View {
        HStack(alignment: .top, spacing: 6) {
            if let icon {
                Image(systemName: icon).foregroundStyle(.secondary).font(.system(size: 12))
            }
            Text(item.text ?? "")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.03))
    }

    private func placeholder(icon: String) -> some View {
        ZStack {
            Color.white.opacity(0.05)
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 7) {
            if let appIcon = item.sourceAppIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Text(item.createdAt.relativeShort)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(item.subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(item.kind == .link ? .middle : .tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

/// Rich link card: OpenGraph image/favicon + title + host (via LinkPresentation).
private struct LinkPreview: View {
    let urlString: String
    @ObservedObject private var service = LinkMetadataService.shared

    private var meta: LinkMetadataService.Meta? { service.cached(for: urlString) }

    private var host: String {
        URL(string: urlString)?.host?.replacingOccurrences(of: "www.", with: "") ?? urlString
    }

    var body: some View {
        ZStack {
            if let image = meta?.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(LinearGradient(
                        colors: [.black.opacity(0.05), .black.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(alignment: .bottomLeading) {
                        Text(meta?.title ?? host)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .padding(8)
                    }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Image(systemName: "link")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text(meta?.title ?? host)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                    Text(host)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
                .background(Color.white.opacity(0.03))
            }
        }
        .animation(.easeOut(duration: 0.25), value: meta?.image != nil)
        .onAppear { service.fetch(urlString) }
    }
}

/// Small floating preview shown under the cursor while dragging an item out.
private struct DragPreview: View {
    let item: ClipboardItem

    var body: some View {
        Group {
            if item.kind == .image, let img = item.previewImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
            } else if item.kind == .color, let c = item.color {
                Color(nsColor: c)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text(item.text ?? item.subtitle)
                    .font(.system(size: 13))
                    .lineLimit(3)
                    .padding(10)
                    .frame(maxWidth: 220)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

/// Centered placeholder shown when a tab has no content.
struct EmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

extension Date {
    /// "27 min ago" style relative string.
    var relativeShort: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
