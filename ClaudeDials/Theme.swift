import SwiftUI
import AppKit

/// Central design system for Claude Dials. Every color, font, and spacing value
/// in the UI comes from here — no hex or point literals in view code.
/// Mirrors design/sketches/index.html and DESIGN.md.
enum Theme {

    // MARK: - Brand palette (Pantone-backed)

    enum Brand {
        static let blue      = Color(hex: 0x004C97)   // Pantone 2945 — color blocks on dark only
        static let lightBlue = Color(hex: 0x009CDE)   // Pantone 292 — interactive only
        static let navy      = Color(hex: 0x002855)   // Pantone 295
        static let gold      = Color(hex: 0xF1BE48)   // Pantone 142 — caution
        static let green     = Color(hex: 0x86AD3F)   // Pantone 4212 — healthy
        static let coral     = Color(hex: 0xFF6D6A)   // Pantone 2345 — near limit
        static let warmBlack = Color(hex: 0x2D2926)   // brand black
    }

    // MARK: - Warm-black surface tiers (derived from brand black, never pure black)

    enum Surface {
        static let backdrop = Color(hex: 0x141210)
        static let window   = Color(hex: 0x1B1815)
        static let panel    = Color(hex: 0x242019)
        static let raised   = Color(hex: 0x2D2926)
        static let hairline = Color.white.opacity(0.08)
    }

    enum Ink {
        static let primary   = Color(hex: 0xF2EFEA)
        static let secondary = Color(hex: 0xB8B2A9)
        static let tertiary  = Color(hex: 0x7D776E)
    }

    // MARK: - Broadcast status colors (exact brand accents, mapped to meaning)

    enum Status {
        static let healthy = Brand.green   // < 60 %
        static let caution = Brand.gold    // 60–85 %
        static let nearLimit = Brand.coral // > 85 %

        /// Worst-window-wins color for a utilization percentage (0–100).
        static func color(for utilization: Double) -> Color {
            switch utilization {
            case ..<60:  return healthy
            case ..<85:  return caution
            default:     return nearLimit
            }
        }

        static func nsColor(for utilization: Double) -> NSColor {
            switch utilization {
            case ..<60:  return NSColor(hex: 0x86AD3F)
            case ..<85:  return NSColor(hex: 0xF1BE48)
            default:     return NSColor(hex: 0xFF6D6A)
            }
        }
    }

    // MARK: - Spacing rhythm

    enum Space {
        static let tight: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 24
        static let xxlarge: CGFloat = 36
    }

    // MARK: - Typography (Myriad Pro, registered at launch)

    enum FontName {
        static let regular  = "MyriadPro-Regular"
        static let semibold = "MyriadPro-Semibold"
        static let black    = "MyriadPro-Black"
    }

    enum Typo {
        static func dialNumeral(_ size: CGFloat = 22) -> Font {
            .custom(FontName.black, size: size).monospacedDigit()
        }
        static let sectionLabel = Font.custom(FontName.black, size: 11)   // ALL-CAPS + tracking
        static let tierBadge    = Font.custom(FontName.semibold, size: 9)
        static let body         = Font.custom(FontName.regular, size: 13)
        static func timecode(_ size: CGFloat = 14) -> Font {
            .custom(FontName.semibold, size: size).monospacedDigit()
        }
        static let caption      = Font.custom(FontName.regular, size: 10)
        static let meterLabel   = Font.custom(FontName.black, size: 9)
        static func meterPct(_ size: CGFloat = 11) -> Font {
            .custom(FontName.semibold, size: size).monospacedDigit()
        }
        static let headline     = Font.custom(FontName.black, size: 20)
    }
}

// MARK: - Hex helpers

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green:   CGFloat((hex >> 8) & 0xFF) / 255,
            blue:    CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
