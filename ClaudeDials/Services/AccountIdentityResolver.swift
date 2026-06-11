import Foundation

/// Resolves an account's identity (email / org) by running `claude auth status
/// --json` against the account's config dir. Used to label dials by who they
/// belong to rather than "Account 1 / 2".
///
/// Subprocess rather than an API call because the email isn't in the Keychain
/// credential or the usage response — `claude auth status` is the reliable
/// source, and the `claude` subprocess uses its own Keychain access (no prompt).
enum AccountIdentityResolver {

    /// Runs off the main actor (blocking subprocess). Returns nil if the CLI is
    /// missing, the account isn't logged in, or output can't be parsed.
    static func resolve(configDir: String?) -> AccountIdentity? {
        guard let claude = cliPath() else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claude)
        process.arguments = ["auth", "status", "--json"]
        var env = ProcessInfo.processInfo.environment
        if let configDir, !configDir.isEmpty {
            env["CLAUDE_CONFIG_DIR"] = (configDir as NSString).expandingTildeInPath
        }
        process.environment = env

        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["loggedIn"] as? Bool) == true else {
            return nil
        }
        return AccountIdentity(
            email: root["email"] as? String,
            orgName: root["orgName"] as? String,
            subscriptionType: root["subscriptionType"] as? String
        )
    }

    private static func cliPath() -> String? {
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(NSHomeDirectory())/.claude/local/claude",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
