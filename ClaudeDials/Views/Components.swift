import SwiftUI

/// Full-bleed brand color-block account header (Logic-track-header device).
/// The signature Northwoods color-block treatment: account name reversed out of
/// a solid brand-color strip, tier badge right-aligned.
struct ColorBlockHeader: View {
    let name: String
    let tier: String
    let color: Color

    var body: some View {
        HStack {
            Text(name.uppercased())
                .font(Theme.Typo.sectionLabel)
                .tracking(1.6)
                .foregroundStyle(.white)
            Spacer()
            Text(tier)
                .font(Theme.Typo.tierBadge)
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, Theme.Space.large)
        .frame(height: 27)
        .frame(maxWidth: .infinity)
        .background(color)
    }
}

/// The Northwoods pointer device — a small triangle that marks the account whose
/// window resets next.
struct PointerMarker: View {
    var body: some View {
        Triangle()
            .fill(Theme.Brand.gold)
            .frame(width: 6, height: 10)
            .accessibilityLabel("Resets next")
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A broadcast warning strip (gold = transient, coral = needs action).
struct WarningStrip: View {
    enum Kind { case caution, alert }
    let kind: Kind
    let title: String
    var subtitle: String? = nil
    var action: (label: String, perform: () -> Void)? = nil

    var body: some View {
        HStack(spacing: Theme.Space.small) {
            Text(title)
                .font(Theme.Typo.meterLabel)
                .tracking(1.4)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.Typo.caption)
                    .opacity(0.8)
            }
            Spacer(minLength: 0)
            if let action {
                Button(action: action.perform) {
                    Text(action.label)
                        .font(Theme.Typo.meterLabel)
                        .tracking(1.2)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(Theme.Brand.warmBlack)
        .padding(.horizontal, Theme.Space.large)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(kind == .caution ? Theme.Brand.gold : Theme.Brand.coral)
    }
}

/// Light-blue capsule button (interactive accent).
struct CapsuleButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom(Theme.FontName.semibold, size: 13))
                .foregroundStyle(Theme.Surface.window)
                .padding(.horizontal, Theme.Space.xlarge)
                .padding(.vertical, 9)
                .background(Capsule().fill(Theme.Brand.lightBlue))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Countdown formatting

enum Countdown {
    /// Formats a reset date as "H:MM:SS until reset" components.
    static func timecode(until date: Date?, now: Date = Date()) -> String {
        guard let date else { return "—" }
        let remaining = max(0, Int(date.timeIntervalSince(now)))
        let h = remaining / 3600
        let m = (remaining % 3600) / 60
        let s = remaining % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}

extension Date {
    /// "12 s" / "6 m" / "2 h" compact age string.
    func compactAge(now: Date = Date()) -> String {
        let secs = Int(now.timeIntervalSince(self))
        if secs < 60 { return "\(max(0, secs)) s" }
        if secs < 3600 { return "\(secs / 60) m" }
        return "\(secs / 3600) h"
    }
}
