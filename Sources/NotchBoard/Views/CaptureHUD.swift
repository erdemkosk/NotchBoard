import SwiftUI

/// Dynamic-Island-style capsule that drops from the notch to confirm a capture.
struct CaptureHUD: View {
    let item: ClipboardItem
    let notchWidth: CGFloat
    let notchHeight: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            preview
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(L.copied)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(item.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 14)
        // Push the info row below the physical notch so it isn't hidden behind it.
        .padding(.top, notchHeight + 8)
        .padding(.bottom, 10)
        .frame(minWidth: max(notchWidth + 70, 220))
        .background(Color.black)
        .clipShape(
            .rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: 22,
                bottomTrailingRadius: 22,
                topTrailingRadius: 0
            )
        )
        .overlay(
            UnevenRoundedRectangle(bottomLeadingRadius: 22, bottomTrailingRadius: 22)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .image:
            if let url = item.fileURL {
                ThumbnailImage(url: url, maxPixel: 64, contentMode: .fill)
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
            Color.white.opacity(0.12)
            Image(systemName: name)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
