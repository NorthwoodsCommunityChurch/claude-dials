import SwiftUI

/// About panel — the one place RedRock + the Northwoods mark appear.
struct AboutView: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: Theme.Space.medium) {
            // Twin-ring capsule mark
            HStack(spacing: Theme.Space.small) {
                ringMark(Theme.Brand.green, fraction: 0.42)
                ringMark(Theme.Brand.gold, fraction: 0.67)
            }
            .padding(.horizontal, Theme.Space.medium)
            .padding(.vertical, Theme.Space.small)
            .background(Capsule().fill(Theme.Brand.warmBlack))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.22)))

            Text("Claude Dials")
                .font(Theme.Typo.headline)
                .foregroundStyle(Theme.Ink.primary)
            Text("Version \(version)")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Ink.secondary)

            Text("Twin tally dials for your Claude session budget.")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Ink.secondary)
                .multilineTextAlignment(.center)

            if let symbol = NSImage(named: "northwoods-symbol-white") {
                Image(nsImage: symbol)
                    .resizable().scaledToFit()
                    .frame(height: 22)
                    .opacity(0.75)
                    .padding(.top, Theme.Space.small)
            }
            Text("Northwoods Community Church · AVL Tools")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Ink.tertiary)
        }
        .padding(Theme.Space.xlarge)
        .frame(width: 320)
        .background(Theme.Surface.window)
    }

    private func ringMark(_ color: Color, fraction: Double) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 3)
            Circle().trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 18, height: 18)
    }
}
