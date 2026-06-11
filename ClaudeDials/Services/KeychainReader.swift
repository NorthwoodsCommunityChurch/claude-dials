import Foundation
import CryptoKit

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

/// Reads Claude Code's OAuth credentials from the macOS login Keychain.
///
/// Service-name scheme (decompiled from Claude Code): the default install uses
/// `"Claude Code-credentials"`; a `CLAUDE_CONFIG_DIR` profile uses
/// `"Claude Code-credentials-<first 8 hex of sha256(NFC(configDirPath))>"`.
/// Each profile is an isolated Keychain item, which is how two accounts can be
/// read at once.
enum KeychainReader {

    private static let baseService = "Claude Code-credentials"

    /// Computes the Keychain service name for a given config dir (nil = default).
    static func serviceName(forConfigDir configDir: String?) -> String {
        guard let configDir, !configDir.isEmpty else { return baseService }
        let normalized = (configDir as NSString).expandingTildeInPath
            .precomposedStringWithCanonicalMapping            // NFC
        let digest = SHA256.hash(data: Data(normalized.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(baseService)-\(hex.prefix(8))"
    }

    /// Reads and parses the credential for an account. Throws `.notFound` when no
    /// Keychain item exists (account is disconnected).
    static func credential(forConfigDir configDir: String?) throws -> ClaudeCredential {
        let service = serviceName(forConfigDir: configDir)
        let data = try rawData(service: service)
        return try parse(data)
    }

    /// Returns true if a Keychain item exists for this account (without reading the
    /// secret — useful for discovery without provoking the access prompt twice).
    static func hasCredential(forConfigDir configDir: String?) -> Bool {
        (try? rawData(service: serviceName(forConfigDir: configDir))) != nil
    }

    // MARK: - Private

    private static func rawData(service: String) throws -> Data {
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
