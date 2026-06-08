import SwiftUI

/// Compact capture confirmation that feels like the notch itself growing: the
/// black shape starts at the exact notch footprint and smoothly expands to a
/// small pill, with the content fading in just after.
struct CaptureHUD: View {
    let item: ClipboardItem
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    var onUndo: (() -> Void)? = nil
    var onSendToShelf: (() -> Void)? = nil
    var onHoverChanged: ((Bool) -> Void)? = nil

    @State private var fullSize: CGSize = .zero
    @State private var grown = false
    @State private var contentIn = false
    @State private var checkPop = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            previewBadge

            Text(L.copied)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(kindTint)
                .scaleEffect(checkPop ? 1 : 0.3)

            if isHovered {
                Divider()
                    .frame(height: 14)
                    .background(Color.white.opacity(0.2))
                    .padding(.horizontal, 2)

                HStack(spacing: 12) {
                    if item.kind == .file || item.kind == .image {
                        Button {
                            onSendToShelf?()
                        } label: {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .help(L.addToShelf)
                    }

                    Button {
                        onUndo?()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help(L.t("Undo", "Geri Al"))
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .opacity(contentIn ? 1 : 0)
        .padding(.horizontal, 11)
        // Extra top inset (+ upward offset below) tucks the top edge above the
        // notch so its boundary is hidden and it reads as the notch growing.
        .padding(.top, notchHeight + 20)
        .padding(.bottom, 7)
        .frame(minWidth: max(notchWidth + (isHovered ? 120 : 36), 150))
        .background(Color.black)
        .clipShape(
            .rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 0
            )
        )
        .shadow(color: .black.opacity(grown ? 0.4 : 0), radius: 12, y: 6)
        // Measure the natural size, then grow from the notch footprint up to it.
        .background(
            GeometryReader { geo in
                Color.clear
                    .onChange(of: isHovered) { _, _ in
                        fullSize = geo.size
                    }
                    .onAppear { startReveal(for: geo.size) }
            }
        )
        .scaleEffect(
            x: grown ? 1 : collapsedScaleX,
            y: grown ? 1 : collapsedScaleY,
            anchor: .top
        )
        .opacity(fullSize == .zero ? 0 : 1)
        .offset(y: -16)
        .onHover { hovering in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                isHovered = hovering
            }
            onHoverChanged?(hovering)
        }
    }

    private func startReveal(for size: CGSize) {
        guard fullSize == .zero else { return }
        fullSize = size
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) { grown = true }
            withAnimation(.easeOut(duration: 0.22).delay(0.12)) { contentIn = true }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.5).delay(0.16)) { checkPop = true }
        }
    }

    private var collapsedScaleX: CGFloat {
        fullSize.width > 0 ? max(notchWidth / fullSize.width, 0.05) : 1
    }
    private var collapsedScaleY: CGFloat {
        fullSize.height > 0 ? max(notchHeight / fullSize.height, 0.05) : 1
    }

    private var previewBadge: some View {
        preview
            .frame(width: 20, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .image:
            if let url = item.fileURL {
                ThumbnailImage(url: url, maxPixel: 48, contentMode: .fill)
            } else {
                hudIcon("photo")
            }
        case .color:
            (item.color.map { Color(nsColor: $0) } ?? Color.gray)
        case .link:
            hudIcon("link")
        case .file:
            hudIcon("doc.fill")
        case .text:
            hudIcon("textformat")
        }
    }

    private func hudIcon(_ name: String) -> some View {
        ZStack {
            kindTint.opacity(0.25)
            Image(systemName: name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var kindTint: Color {
        switch item.kind {
        case .text: return .blue
        case .link: return .teal
        case .color: return item.color.map { Color(nsColor: $0) } ?? .pink
        case .image: return .purple
        case .file: return .orange
        }
    }
}
