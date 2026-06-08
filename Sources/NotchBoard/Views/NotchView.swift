import SwiftUI

/// Root content: a black notch pill that morphs into the expanded panel.
struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        ZStack(alignment: .top) {
            // Transparent backdrop fills the window; only the panel is visible.
            Color.clear

            // Soft glow that pulses around the notch on each capture.
            CapturePulse(
                trigger: viewModel.capturePulse,
                width: viewModel.notchWidth,
                height: viewModel.notchHeight
            )

            if viewModel.isOpen {
                ExpandedPanel(viewModel: viewModel)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.62, anchor: .top)
                                .combined(with: .offset(y: -18))
                                .combined(with: .opacity),
                            removal: .scale(scale: 0.78, anchor: .top)
                                .combined(with: .offset(y: -10))
                                .combined(with: .opacity)
                        )
                    )
            } else if let hudItem = viewModel.hudItem {
                CaptureHUD(
                    item: hudItem,
                    notchWidth: viewModel.notchWidth,
                    notchHeight: viewModel.notchHeight,
                    onUndo: {
                        withAnimation {
                            viewModel.clipboard.remove(hudItem)
                            viewModel.hudItem = nil
                        }
                    },
                    onSendToShelf: {
                        withAnimation {
                            viewModel.shelf.add(from: hudItem)
                            viewModel.hudItem = nil
                        }
                    },
                    onHoverChanged: { hovering in
                        viewModel.hudHoverChanged(hovering)
                    }
                )
                .id(viewModel.capturePulse)
                .transition(
                    .asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 0.6, anchor: .top)
                            .combined(with: .offset(y: -6))
                            .combined(with: .opacity)
                    )
                )
            } else {
                ClosedPill(viewModel: viewModel)
                    .transition(
                        .scale(scale: 0.9, anchor: .top).combined(with: .opacity)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.5, dampingFraction: 0.68), value: viewModel.isOpen)
    }
}

/// A brief accent-colored glow that blooms around the notch each time something
/// is captured — a subtle pulse on top of the capture HUD.
private struct CapturePulse: View {
    let trigger: Int
    let width: CGFloat
    let height: CGFloat

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 12, bottomTrailingRadius: 12)
            .stroke(Color.accentColor, lineWidth: 2)
            .frame(width: width, height: height)
            .shadow(color: Color.accentColor.opacity(0.9), radius: 8)
            .opacity(opacity)
            .scaleEffect(scale, anchor: .top)
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, _ in
                guard trigger > 0 else { return }
                opacity = 0.6
                scale = 1.0
                withAnimation(.easeOut(duration: 0.6)) {
                    opacity = 0
                    scale = 1.12
                }
            }
    }
}

/// The collapsed state sitting under the hardware notch.
private struct ClosedPill: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        let radius = viewModel.hasHardwareNotch ? 12 : viewModel.pillCornerRadius
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.black)
            .frame(
                width: viewModel.notchWidth,
                height: viewModel.notchHeight
            )
            .overlay(alignment: .bottom) {
                if !viewModel.hasHardwareNotch {
                    // Subtle indicator on non-notch displays.
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 34, height: 4)
                        .padding(.bottom, 5)
                }
            }
            .clipShape(
                .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: radius,
                    bottomTrailingRadius: radius,
                    topTrailingRadius: 0
                )
            )
    }
}
