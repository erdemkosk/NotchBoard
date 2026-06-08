import SwiftUI

/// Shrinks + dims a button while pressed so taps feel responsive.
struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Adds hover feedback (lift, brighten, pointer cursor) to non-button elements
/// such as cards, so it is obvious they are interactive.
struct HoverFeedback: ViewModifier {
    var scale: CGFloat = 1.03
    var lift: CGFloat = 2
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? scale : 1)
            .brightness(hovering ? 0.06 : 0)
            .offset(y: hovering ? -lift : 0)
            .shadow(color: .black.opacity(hovering ? 0.35 : 0), radius: hovering ? 10 : 0, y: 4)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
            .onHover { inside in
                hovering = inside
                // Use set() rather than push/pop to avoid an unbalanced cursor
                // stack when a hovered card is removed (e.g. after copy + close).
                if inside {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
    }
}

extension View {
    func hoverFeedback(scale: CGFloat = 1.03, lift: CGFloat = 2) -> some View {
        modifier(HoverFeedback(scale: scale, lift: lift))
    }

    /// Fades the top and bottom edges of a scroll view for a softer look.
    func scrollEdgeFade(_ length: CGFloat = 18) -> some View {
        mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.04),
                    .init(color: .black, location: 0.96),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
