import AppKit

/// One ring inside the menu-bar capsule.
struct RingSpec {
    /// 0–1 fill fraction.
    var fraction: Double
    var color: NSColor
    var initial: String
    /// false → hollow dashed "disconnected" ring.
    var connected: Bool
}

/// Draws the menu-bar capsule: a warm-black pill containing up to two status
/// rings — the app's silhouette. Colored (non-template) so status reads at a
/// glance. Redrawn whenever usage changes.
enum CapsuleStatusIcon {

    static func make(rings: [RingSpec]) -> NSImage {
        let ringD: CGFloat = 13
        let ringGap: CGFloat = 5
        let padX: CGFloat = 7
        let height: CGFloat = 18
        let count = max(rings.count, 1)
        let width = padX * 2 + CGFloat(count) * ringD + CGFloat(count - 1) * ringGap

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        guard let ctx = NSGraphicsContext.current else { image.unlockFocus(); return image }
        ctx.imageInterpolation = .high

        // Capsule background
        let capsuleRect = NSRect(x: 0.5, y: 0.5, width: width - 1, height: height - 1)
        let capsule = NSBezierPath(roundedRect: capsuleRect, xRadius: height / 2, yRadius: height / 2)
        NSColor(hex: 0x2D2926).setFill()
        capsule.fill()
        NSColor.white.withAlphaComponent(0.25).setStroke()
        capsule.lineWidth = 1
        capsule.stroke()

        // Rings
        let cy = height / 2
        for (i, ring) in rings.enumerated() {
            let cx = padX + ringD / 2 + CGFloat(i) * (ringD + ringGap)
            drawRing(ring, centerX: cx, centerY: cy, diameter: ringD)
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func drawRing(_ ring: RingSpec, centerX cx: CGFloat, centerY cy: CGFloat, diameter: CGFloat) {
        let lineWidth: CGFloat = 2.2
        let radius = (diameter - lineWidth) / 2
        let center = NSPoint(x: cx, y: cy)

        if !ring.connected {
            let path = NSBezierPath()
            path.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            path.lineWidth = 1.4
            NSColor.white.withAlphaComponent(0.35).setStroke()
            let pattern: [CGFloat] = [2.2, 2.2]
            path.setLineDash(pattern, count: 2, phase: 0)
            path.stroke()
            drawInitial(ring.initial, at: center, color: NSColor.white.withAlphaComponent(0.45))
            return
        }

        // Track
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        NSColor.white.withAlphaComponent(0.16).setStroke()
        track.stroke()

        // Progress arc — start at top (90°), sweep clockwise.
        let fraction = min(max(ring.fraction, 0), 1)
        if fraction > 0 {
            let start: CGFloat = 90
            let end = start - 360 * fraction
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            ring.color.setStroke()
            arc.stroke()
        }

        drawInitial(ring.initial, at: center, color: NSColor.white.withAlphaComponent(0.78))
    }

    private static func drawInitial(_ text: String, at center: NSPoint, color: NSColor) {
        guard !text.isEmpty else { return }
        let font = NSFont(name: "MyriadPro-Black", size: 6) ?? NSFont.systemFont(ofSize: 6, weight: .black)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        str.draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
    }
}
