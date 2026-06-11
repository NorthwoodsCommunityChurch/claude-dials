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

        // Write a double-clickable `.command` script and open it with its default
        // handler (Terminal). This avoids needing Apple Events (Automation)
        // permission, which silently blocks the older "tell Terminal to do script"
        // approach on an ad-hoc-signed app.
        //
        // `claude auth login` (NOT the interactive `/login`) honors
        // CLAUDE_CONFIG_DIR and writes a SEPARATE per-profile Keychain item
        // instead of overwriting the default profile. `--claudeai` selects
        // subscription auth.
        let scriptPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("connect-second-claude-account.command")
        let script = """
        #!/bin/zsh
        export CLAUDE_CONFIG_DIR="\(dir)"
        clear
        echo "────────────────────────────────────────────"
        echo "  Claude Dials — connect your SECOND account"
        echo "────────────────────────────────────────────"
        echo
        echo "A browser will open. Sign in with the account you are ADDING"
        echo "(not the one already on your first dial). If your browser is"
        echo "already signed in, use the account switcher or a private window."
        echo
        "\(claude)" auth login --claudeai
        echo
        echo "Done — you can close this window. The second dial lights up shortly."
        """
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: scriptPath
            )
        } catch {
            NSLog("Claude Dials: failed to write connect script: \(error)")
            return false
        }

        // Opening a .command file launches Terminal to run it — no Apple Events.
        if !NSWorkspace.shared.open(URL(fileURLWithPath: scriptPath)) {
            NSLog("Claude Dials: NSWorkspace failed to open connect script")
            return false
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
