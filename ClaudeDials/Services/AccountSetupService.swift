import Foundation
import AppKit

/// Drives connecting a *second* Claude account on a Mac that already has one
/// logged into Claude Code.
///
/// Why this is needed: Claude Code stores one credential per config directory,
/// keyed in the Keychain by a hash of that directory. Logging a second account
/// in via the normal flow *overwrites* the first. To watch both at once, the
/// second account gets its own `CLAUDE_CONFIG_DIR`; logging in there writes a
/// separate Keychain item the monitor can read independently.
@MainActor
enum AccountSetupService {

    /// Dedicated config dir for the app-managed second account.
    static var secondConfigDir: String {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Claude Dials/account-2", isDirectory: true)
        return base.path
    }

    /// Whether the second-account config dir already has a logged-in credential.
    static func secondAccountIsLoggedIn() -> Bool {
        KeychainReader.hasCredential(forConfigDir: secondConfigDir)
    }

    /// Locates the `claude` CLI. Returns nil if not found on common paths.
    static func claudeCLIPath() -> String? {
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(NSHomeDirectory())/.claude/local/claude",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Opens Terminal and runs the second-account login against the dedicated
    /// config dir. The user picks the *other* account in the browser that opens.
    /// Returns false if the `claude` CLI couldn't be located.
    @discardableResult
    static func launchSecondAccountLogin() -> Bool {
        let dir = secondConfigDir
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )

        guard let claude = claudeCLIPath() else { return false }

        // Run `claude` with an isolated config dir so login writes a separate
        // Keychain item. The CLI prompts to log in when the dir has no creds.
        let escapedDir = dir.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedClaude = claude.replacingOccurrences(of: "\"", with: "\\\"")
        let command = "CLAUDE_CONFIG_DIR=\"\(escapedDir)\" \"\(escapedClaude)\" /login"

        let appleScriptSource = """
        tell application "Terminal"
            activate
            do script "\(command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """

        if let script = NSAppleScript(source: appleScriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let error { NSLog("Claude Dials: login launch error \(error)") }
        }
        return true
    }

    /// Registers the now-logged-in second account in the config store.
    static func registerSecondAccount(label: String = "Account 2") {
        let dir = secondConfigDir
        let already = ConfigStore.shared.config.accounts.contains { $0.configDir == dir }
        guard !already else { return }
        ConfigStore.shared.addAccount(Account(label: label, configDir: dir))
    }
}
