import SwiftUI

/// A segmented LED-style meter — broadcast-console language for the weekly and
/// Opus windows. Twelve segments fill in status color up to the utilization.
struct SegmentMeter: View {
    let label: String
    /// 0–100, or nil for no data.
    let utilization: Double?

    private let segmentCount = 12

    private var filledCount: Int {
        guard let utilization else { return 0 }
        return Int((utilization / 100 * Double(segmentCount)).rounded())
    }
    private var color: Color {
        Theme.Status.color(for: utilization ?? 0)
    }

    var body: some View {
        HStack(spacing: Theme.Space.small) {
            Text(label)
                .font(Theme.Typo.meterLabel)
                .tracking(1.6)
                .foregroundStyle(Theme.Ink.tertiary)
                .frame(width: 44, alignment: .leading)

            HStack(spacing: 2) {
                ForEach(0..<segmentCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(i < filledCount ? color : Color.white.opacity(0.10))
                        .frame(height: 7)
                        .animation(.easeOut(duration: 0.18), value: filledCount)
                }
            }

            Text(utilization == nil ? "—" : "\(Int(utilization!.rounded()))%")
                .font(Theme.Typo.meterPct())
                .foregroundStyle(Theme.Ink.secondary)
                .frame(width: 34, alignment: .trailing)
        }
    }
}
