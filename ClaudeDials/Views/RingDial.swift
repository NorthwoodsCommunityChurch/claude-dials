import SwiftUI

/// A broadcast-style ring gauge: a track plus a status-colored arc, with a
/// monospaced numeral (or em dash) in the center. Used at popover scale.
struct RingDial: View {
    /// 0–100. Nil renders the disconnected (hollow dashed) state.
    let utilization: Double?
    var diameter: CGFloat = 56
    var lineWidth: CGFloat = 5

    private var fraction: Double { min(max((utilization ?? 0) / 100, 0), 1) }
    private var color: Color {
        guard let utilization else { return Theme.Ink.tertiary }
        return Theme.Status.color(for: utilization)
    }

    var body: some View {
        ZStack {
            if utilization == nil {
                Circle()
                    .strokeBorder(
                        Theme.Ink.tertiary.opacity(0.55),
                        style: StrokeStyle(lineWidth: lineWidth - 2, dash: [4, 4])
                    )
            } else {
                Circle()
                    .stroke(Color.white.opacity(0.09), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.18), value: fraction)
            }

            Text(utilization == nil ? "—" : "\(Int(utilization!.rounded()))%")
                .font(Theme.Typo.dialNumeral(diameter * 0.27))
                .foregroundStyle(color)
        }
        .frame(width: diameter, height: diameter)
    }
}
