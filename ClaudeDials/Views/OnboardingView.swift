import SwiftUI

/// First-impression hero: one dial connected, an invitation to light the second.
/// Composed capsule illustration (not ContentUnavailableView).
struct OnboardingView: View {
    @ObservedObject var monitor: UsageMonitor
    var onConnect: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            CapsuleHero()
                .frame(width: 150, height: 58)
                .padding(.top, Theme.Space.xlarge + Theme.Space.tight)
                .padding(.bottom, Theme.Space.large)

            Text("One dial connected.")
                .font(Theme.Typo.headline)
                .foregroundStyle(Theme.Ink.primary)

            Text("Found your account from Claude Code. Connect the second account to light the other dial.")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Ink.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(width: 250)
                .padding(.top, Theme.Space.small)

            CapsuleButton(title: "Connect second account…", action: onConnect)
                .padding(.top, Theme.Space.large)

            Text("One-time login · takes about a minute")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Ink.tertiary)
                .padding(.top, Theme.Space.small)
                .padding(.bottom, Theme.Space.xlarge)

            HStack {
                Button(action: onSkip) {
                    Text("Skip for now — show one dial")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Ink.tertiary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, Theme.Space.large)
            .padding(.vertical, Theme.Space.small)
            .overlay(Rectangle().fill(Theme.Surface.hairline).frame(height: 1), alignment: .top)
        }
    }
}

/// The composed twin-ring capsule illustration: one ring lit green, one dark and
/// dashed (the account yet to connect).
private struct CapsuleHero: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22.5)
                .fill(Theme.Brand.warmBlack)
                .overlay(
                    RoundedRectangle(cornerRadius: 22.5)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                )
                .frame(height: 45)

            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 5)
                    Circle().trim(from: 0, to: 0.42)
                        .stroke(Theme.Brand.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Theme.Brand.green.opacity(0.6), radius: 4)
                    Text("1").font(.custom(Theme.FontName.black, size: 11)).foregroundStyle(Theme.Ink.primary)
                }
                .frame(width: 30, height: 30)

                ZStack {
                    Circle().strokeBorder(
                        Color.white.opacity(0.3),
                        style: StrokeStyle(lineWidth: 3, dash: [5, 5])
                    )
                    Text("2").font(.custom(Theme.FontName.black, size: 11)).foregroundStyle(Color.white.opacity(0.4))
                }
                .frame(width: 30, height: 30)
            }
        }
    }
}
