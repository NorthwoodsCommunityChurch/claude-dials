import AppKit
import SwiftUI
import Combine
import Sparkle

/// Owns the menu-bar status item: draws the twin-ring capsule from live usage,
/// shows the popover on left-click and a context menu on right-click.
@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {

    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let monitor: UsageMonitor
    private let updater: SPUUpdater
    private var cancellables = Set<AnyCancellable>()

    // Window presenters injected by AppDelegate (LSUIElement app has no Scene windows by default).
    var presentSettings: () -> Void = {}
    var presentAbout: () -> Void = {}
    var presentConnectAccount: () -> Void = {}

    init(monitor: UsageMonitor, updater: SPUUpdater) {
        self.monitor = monitor
        self.updater = updater
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        configurePopover()
        redraw()

        // Redraw the capsule whenever the monitor publishes new snapshots.
        monitor.$snapshots
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.redraw() }
            .store(in: &cancellables)

        monitor.onUpdate = { [weak self] in self?.redraw() }
    }

    // MARK: - Setup

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let root = PopoverView(
            monitor: monitor,
            onConnectSecond: { [weak self] in self?.closePopoverThen { self?.presentConnectAccount() } },
            onOpenSettings: { [weak self] in self?.closePopoverThen { self?.presentSettings() } },
            onReconnect: { [weak self] _ in self?.closePopoverThen { self?.presentConnectAccount() } }
        )
        popover.contentViewController = NSHostingController(rootView: root)
    }

    // MARK: - Drawing

    private func redraw() {
        guard let button = statusItem.button else { return }
        button.image = CapsuleStatusIcon.make(rings: CapsuleStatusIcon.rings(from: monitor))
    }

    // MARK: - Clicks

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            Task { await monitor.refresh() }
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func closePopoverThen(_ action: @escaping () -> Void) {
        popover.performClose(nil)
        DispatchQueue.main.async(execute: action)
    }

    // MARK: - Context menu

    private func showContextMenu() {
        let menu = NSMenu()

        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        menu.addItem(.separator())

        if monitor.isSingleAccountFirstRun {
            let connect = NSMenuItem(title: "Connect Second Account…", action: #selector(connectAccount), keyEquivalent: "")
            connect.target = self
            menu.addItem(connect)
        }
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let about = NSMenuItem(title: "About Claude Dials", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let update = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        menu.addItem(update)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Claude Dials", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
    }

    @objc private func refreshNow() { Task { await monitor.refresh() } }
    @objc private func connectAccount() { presentConnectAccount() }
    @objc private func openSettings() { presentSettings() }
    @objc private func openAbout() { presentAbout() }
    @objc private func checkForUpdates() { updater.checkForUpdates() }
}
