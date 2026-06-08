import SwiftUI

/// Grid of clipboard history cards. Cards are clickable (re-copy) and draggable
/// out to other apps.
struct HistoryView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var hoveredID: UUID?

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
                                isHovered: hoveredID == item.id,
                                onToggleFavorite: { viewModel.clipboard.toggleFavorite(item) }
                            )
                            .id(item.id)
                            .zIndex(hoveredID == item.id ? 10 : 0)
                            .hoverFeedback()
                            .onHover { inside in
                                if inside { hoveredID = item.id }
                                else if hoveredID == item.id { hoveredID = nil }
                            }
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
                                Button(item.isPinned ? L.unpinFromTop : L.pinToTop) {
                                    viewModel.clipboard.togglePin(item)
                                }
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
    var isHovered: Bool = false
    var onToggleFavorite: () -> Void = {}
    @State private var showTooltip = false
    @State private var tooltipTask: DispatchWorkItem?

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
        .overlay(alignment: .topLeading) {
            if item.isPinned { pinBadge }
        }
        .overlay {
            if isCopied { copiedBadge }
        }
        .scaleEffect(isCopied ? 0.96 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isCopied)
        .overlay(alignment: .bottom) { tooltip }
        .onChange(of: isHovered) { _, hovering in
            if hovering {
                let task = DispatchWorkItem {
                    withAnimation(.easeOut(duration: 0.15)) { showTooltip = true }
                }
                tooltipTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: task)
            } else {
                tooltipTask?.cancel()
                withAnimation(.easeOut(duration: 0.1)) { showTooltip = false }
            }
        }
    }

    /// Full, untruncated text revealed after hovering and waiting (e.g. the
    /// complete URL for links).
    private var helpText: String {
        switch item.kind {
        case .image: return item.subtitle
        default: return item.text ?? item.subtitle
        }
    }

    @ViewBuilder
    private var tooltip: some View {
        if showTooltip && !helpText.isEmpty && !isCopied {
            Text(helpText)
                .font(.system(size: 10.5))
                .foregroundStyle(.white)
                .lineLimit(5)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.disabled)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: 240, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.black.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
                .offset(y: 14)
                .allowsHitTesting(false)
                .transition(.opacity)
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

    private var pinBadge: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(5)
            .background(Color.accentColor, in: Circle())
            .padding(6)
            .rotationEffect(.degrees(45))
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
            textPreview(icon: item.isPinned ? "pin.fill" : nil)
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

/// Centered, illustrated placeholder shown when a tab has no content. The icon
/// sits on a soft gradient halo and gently breathes/floats; the whole thing
/// fades and scales in for a polished empty state.
struct EmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    @State private var appeared = false
    @State private var floating = false

    var body: some View {
        VStack(spacing: 16) {
            illustration
            VStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.92)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }

    private var illustration: some View {
        ZStack {
            // Soft layered halo behind the glyph.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.28), .clear],
                        center: .center, startRadius: 2, endRadius: 70
                    )
                )
                .frame(width: 150, height: 150)
                .scaleEffect(floating ? 1.06 : 0.94)

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.16), .white.opacity(0.02)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .background(Circle().fill(Color.white.opacity(0.04)))
                .frame(width: 92, height: 92)

            Image(systemName: icon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.95), Color.accentColor.opacity(0.85)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .symbolRenderingMode(.hierarchical)
        }
        .offset(y: floating ? -5 : 5)
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
