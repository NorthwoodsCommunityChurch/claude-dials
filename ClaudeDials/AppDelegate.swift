import AppKit
import SwiftUI
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var updaterController: SPUStandardUpdaterController!
    private var statusBar: StatusBarController!
    private let monitor = UsageMonitor()

    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        FontRegistrar.registerBundledFonts()
        // Don't register a login item during a diagnostic dump — that would point
        // the login item at whatever (possibly build-folder) binary ran the dump.
        if !DiagnosticDump.isEnabled {
            LaunchAtLogin.enableOnFirstLaunch()
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
        )

        statusBar = StatusBarController(monitor: monitor, updater: updaterController.updater)
        statusBar.presentSettings = { [weak self] in self?.showSettings() }
        statusBar.presentAbout = { [weak self] in self?.showAbout() }

        monitor.start()

        if DiagnosticDump.isEnabled {
            Task {
                // Wait for ALL accounts to leave the .loading seed state.
                for _ in 0..<40 {
                    await monitor.refresh()
                    let allSettled = !monitor.snapshots.isEmpty && monitor.snapshots.allSatisfy {
                        if case .loading = $0.state { return false } else { return true }
                    }
                    if allSettled { break }
                    try? await Task.sleep(for: .milliseconds(300))
                }
                DiagnosticDump.run(monitor: monitor)
            }
        }
    }

    // MARK: - Windows (LSUIElement app builds its own)

    private func showSettings() {
        if let w = settingsWindow { focus(w); return }
        let view = SettingsView(monitor: monitor)
        let window = makeWindow(title: "Claude Dials Settings", view: view)
        settingsWindow = window
        focus(window)
    }

    private func showAbout() {
        let window = makeWindow(title: "About Claude Dials", view: AboutView(), resizable: false)
        focus(window)
    }

    private func makeWindow<V: View>(title: String, view: V, resizable: Bool = true) -> NSWindow {
        var style: NSWindow.StyleMask = [.titled, .closable]
        if resizable { style.insert(.resizable) }
        let window = NSWindow(
            contentRect: .zero, styleMask: style, backing: .buffered, defer: false
        )
        window.title = title
        window.contentViewController = NSHostingController(rootView: view)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func focus(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
