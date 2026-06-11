import Foundation

/// Who an account belongs to, resolved from `claude auth status`.
struct AccountIdentity: Equatable {
    let email: String?
    let orgName: String?
    let subscriptionType: String?

    /// A short, friendly label derived from the account's email — "Personal" for
    /// a free-provider address, otherwise the org from the email domain
    /// (e.g. `aaron.larson@northwoods.church` → "Northwoods"). Falls back to the
    /// org name if there's no usable email.
    var displayName: String? {
        if let label = Self.label(fromEmail: email) { return label }
        if let org = orgName, !org.isEmpty {
            return org.split(separator: " ").first.map(String.init)
        }
        return nil
    }

    private static let freeProviders: Set<String> = [
        "gmail.com", "googlemail.com", "icloud.com", "me.com", "mac.com",
        "outlook.com", "hotmail.com", "live.com", "msn.com",
        "yahoo.com", "ymail.com", "aol.com",
        "proton.me", "protonmail.com", "pm.me", "fastmail.com", "hey.com",
    ]

    private static func label(fromEmail email: String?) -> String? {
        guard let email,
              let at = email.firstIndex(of: "@") else { return nil }
        let domain = String(email[email.index(after: at)...]).lowercased()
        guard !domain.isEmpty else { return nil }
        if freeProviders.contains(domain) { return "Personal" }
        // Org domain: use the first label, capitalized (northwoods.church → Northwoods).
        guard let sld = domain.split(separator: ".").first, !sld.isEmpty else { return nil }
        return sld.prefix(1).uppercased() + sld.dropFirst()
    }
}
