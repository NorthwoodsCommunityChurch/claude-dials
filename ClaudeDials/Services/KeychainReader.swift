import Foundation

/// The OAuth credential Claude Code stores in the login Keychain.
/// Shape verified from the Claude Code binary: `{ "claudeAiOauth": { ... } }`.
struct ClaudeCredential {
    let accessToken: String
    let refreshToken: String?
    /// Epoch milliseconds.
    let expiresAt: Double?
    let subscriptionType: String?
    let rateLimitTier: String?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date().timeIntervalSince1970 * 1000
    }

    /// Human-facing tier badge, e.g. "MAX 5×".
    var tierBadge: String {
        let tier = rateLimitTier?.lowercased() ?? ""
        if tier.contains("max") {
            if tier.contains("20x") { return "MAX 20×" }
            if tier.contains("5x")  { return "MAX 5×" }
            return "MAX"
        }
        if tier.contains("pro") { return "PRO" }
        if let sub = subscriptionType, !sub.isEmpty { return sub.uppercased() }
        return "CLAUDE"
    }
}

enum KeychainError: Error {
    case notFound
    case unreadable(OSStatus)
    case malformed
}

/// Reads Claude Code's OAuth credential from the macOS login Keychain.
///
/// Claude Dials watches the *default* Claude Code login only, stored under the
/// service name `"Claude Code-credentials"` (decompiled from Claude Code). We
/// only ever read — never write.
///
/// The read is done by shelling out to `/usr/bin/security`, NOT by calling
/// `SecItemCopyMatching` in-process. See `rawData()` for the full reasoning; the
/// short version is that it's the only way to avoid a recurring "Always Allow"
/// prompt, because Claude Code resets the item's partition list on every token
/// refresh and `/usr/bin/security` sits in the one partition those writes keep.
enum KeychainReader {

    private static let service = "Claude Code-credentials"

    /// Reads and parses the credential. Throws `.notFound` when no Keychain item
    /// exists (the user isn't logged into Claude Code).
    static func credential() throws -> ClaudeCredential {
        try parse(rawData())
    }

    // MARK: - Private

    /// Reads the raw credential blob via `/usr/bin/security` instead of an
    /// in-process `SecItemCopyMatching`.
    ///
    /// Why the subprocess (verified 2026-07-03): macOS gates a *silent* keychain
    /// read on TWO things — the caller must be in the item's trusted-application
    /// ACL **and** its code-signing partition must be in the item's partition
    /// list. Claude Code owns this item and rewrites it on every token refresh,
    /// which resets the partition list and drops Claude Dials' own
    /// `teamid:TQ6Y49W7UW` partition. So an in-process read goes silent right
    /// after an "Always Allow", then re-prompts at Claude Code's next refresh —
    /// this was the "random" recurring prompt. `/usr/bin/security` lives in the
    /// `apple-tool:` partition, which is exactly the partition Claude Code's
    /// writes *preserve*, so reading through it stays silent across refreshes.
    /// The secret only ever crosses the child's stdout — never a command-line
    /// argument (nothing here is sensitive: service name + flags only).
    private static func rawData() throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-w", "-s", service]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()   // swallow "could not be found" chatter

        do {
            try process.run()
        } catch {
            throw KeychainError.unreadable(-1)
        }
        // Read to EOF before waiting, so a full pipe buffer can't deadlock the child.
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        // `security` exits 44 (errSecItemNotFound) when the user isn't logged in.
        guard process.terminationStatus == 0 else { throw KeychainError.notFound }

        // `-w` prints the secret as text with a trailing newline; trim it so the
        // JSON parser sees clean bytes.
        guard
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty,
            let clean = text.data(using: .utf8)
        else { throw KeychainError.malformed }
        return clean
    }

    private static func parse(_ data: Data) throws -> ClaudeCredential {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = root["claudeAiOauth"] as? [String: Any],
            let accessToken = oauth["accessToken"] as? String
        else { throw KeychainError.malformed }

        return ClaudeCredential(
            accessToken: accessToken,
            refreshToken: oauth["refreshToken"] as? String,
            expiresAt: (oauth["expiresAt"] as? NSNumber)?.doubleValue,
            subscriptionType: oauth["subscriptionType"] as? String,
            rateLimitTier: oauth["rateLimitTier"] as? String
        )
    }
}
