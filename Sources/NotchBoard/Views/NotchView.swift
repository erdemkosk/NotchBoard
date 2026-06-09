import SwiftUI

/// Root content: a black notch pill that morphs into the expanded panel.
struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        ZStack(alignment: .top) {
            // Transparent backdrop fills the window; only the panel is visible.
            Color.clear

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
                    errorMessage: viewModel.hudErrorMessage,
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
                .id(hudItem.id)
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
