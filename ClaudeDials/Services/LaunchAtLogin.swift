import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` for the "Open at Login" toggle.
/// Registers the *currently running* app bundle, so the app must run from a
/// stable location (e.g. /Applications) for the login item to survive — running
/// from a build folder registers a path that may later disappear.
@MainActor
enum LaunchAtLogin {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Claude Dials: launch-at-login toggle failed: \(error)")
        }
    }

    /// Turns launch-at-login on once, the first time the app ever runs, so a menu-
    /// bar utility the user expects to "just be there" comes back after a restart.
    /// Records that it configured the setting so it never overrides a later opt-out.
    static func enableOnFirstLaunch() {
        let key = "didConfigureLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        set(true)
        UserDefaults.standard.set(true, forKey: key)
    }
}
