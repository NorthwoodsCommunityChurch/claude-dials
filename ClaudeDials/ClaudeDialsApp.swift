import SwiftUI

@main
struct ClaudeDialsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar-only app (LSUIElement). All UI is built by the AppDelegate:
        // the status-bar capsule, the popover, and on-demand Settings / About /
        // Connect Account windows. No Scene window is needed.
        Settings { EmptyView() }
    }
}
