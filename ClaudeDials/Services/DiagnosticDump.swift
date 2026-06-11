import SwiftUI
import AppKit

/// Renders the real popover and capsule to PNGs when launched with the
/// `CLAUDEDIALS_DUMP` environment variable set. Ships harmlessly (gated behind
/// the env var) and is the reliable way to verify the UI when a menu-bar manager
/// hides the status item. Uses the live monitor data.
@MainActor
enum DiagnosticDump {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["CLAUDEDIALS_DUMP"] != nil
    }

    static func run(monitor: UsageMonitor) {
        let dir = ProcessInfo.processInfo.environment["CLAUDEDIALS_DUMP"] ?? "/tmp"

        // Capsule (menu-bar) icon from current snapshots.
        let rings: [RingSpec] = monitor.snapshots.enumerated().map { i, snap in
            let initial = monitor.account(for: snap.id)?.label.first.map { String($0).uppercased() } ?? "\(i+1)"
            if !snap.state.isConnected {
                return RingSpec(fraction: 0, color: .gray, initial: initial, connected: false)
            }
            let worst = snap.state.usage?.worstUtilization ?? 0
            return RingSpec(fraction: worst/100, color: Theme.Status.nsColor(for: worst), initial: initial, connected: true)
        }
        let capsule = CapsuleStatusIcon.make(rings: rings.isEmpty
            ? [RingSpec(fraction: 0, color: .gray, initial: "1", connected: false)] : rings)
        writePNG(capsule, to: "\(dir)/claudedials_capsule.png", scale: 6)

        // Popover at real size.
        let popover = PopoverView(
            monitor: monitor, onConnectSecond: {}, onOpenSettings: {}, onReconnect: { _ in }
        )
        renderSwiftUI(popover, to: "\(dir)/claudedials_popover.png")

        // About panel.
        renderSwiftUI(AboutView(), to: "\(dir)/claudedials_about.png")

        NSLog("Claude Dials: diagnostic dump written to \(dir)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
    }

    private static func renderSwiftUI<V: View>(_ view: V, to path: String) {
        let renderer = ImageRenderer(content: view.frame(width: 330).fixedSize(horizontal: true, vertical: true))
        renderer.scale = 2
        guard let nsImage = renderer.nsImage else { return }
        writePNG(nsImage, to: path, scale: 1)
    }

    private static func writePNG(_ image: NSImage, to path: String, scale: CGFloat) {
        let size = image.size
        let pixelW = Int(size.width * scale), pixelH = Int(size.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelW, pixelsHigh: pixelH,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
