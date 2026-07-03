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
/// only ever read — never write — so we never take ownership of the item or
/// trigger a "modify" prompt; the user grants read access once ("Always Allow").
enum KeychainReader {

    private static let service = "Claude Code-credentials"

    /// Reads and parses the credential. Throws `.notFound` when no Keychain item
    /// exists (the user isn't logged into Claude Code).
    static func credential() throws -> ClaudeCredential {
        try parse(rawData())
    }

    // MARK: - Private

    private static func rawData() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw KeychainError.malformed }
            return data
        case errSecItemNotFound:
            throw KeychainError.notFound
        default:
            throw KeychainError.unreadable(status)
        }
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
