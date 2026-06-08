import SwiftUI
import AppKit

/// First-run setup guide: a short welcome that introduces the app.
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var step = 0

    private let totalSteps = 2

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 36)
                .padding(.top, 40)

            footer
        }
        .frame(width: 520, height: 400)
        .background(background)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:
            page(
                icon: "sparkles",
                title: L.onboardingWelcomeTitle,
                body: L.onboardingWelcomeBody
            )
        default:
            page(
                icon: "checkmark.seal.fill",
                title: L.onboardingDoneTitle,
                body: L.onboardingDoneBody
            )
        }
    }

    private func page(icon: String, title: String, body: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.tint)
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
            Text(body)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button(L.back) { withAnimation { step -= 1 } }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            stepDots
            Spacer()
            primaryButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Circle()
                    .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if step < totalSteps - 1 {
            Button(L.next) { withAnimation { step += 1 } }
                .keyboardShortcut(.defaultAction)
        } else {
            Button(L.getStarted) { onFinish() }
                .keyboardShortcut(.defaultAction)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.10), Color.clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
