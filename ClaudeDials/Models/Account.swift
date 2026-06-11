import Foundation

/// A Claude account the app monitors. Identified by an optional Claude Code
/// config directory — `nil` means the default `~/.claude` install, a non-nil
/// path means a separate `CLAUDE_CONFIG_DIR` profile (the mechanism for a
/// second simultaneous account on one Mac).
struct Account: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String
    /// Absolute path to the account's `CLAUDE_CONFIG_DIR`, or nil for the default install.
    var configDir: String?

    init(id: UUID = UUID(), label: String, configDir: String? = nil) {
        self.id = id
        self.label = label
        self.configDir = configDir
    }
}

/// Persisted app configuration: which accounts to monitor and the poll interval.
/// Stored in `UserDefaults` (no secrets — only labels + config-dir paths).
struct AppConfig: Codable {
    var accounts: [Account]
    /// Seconds between background polls. The endpoint is safe at ~180 s with the
    /// claude-code User-Agent.
    var pollInterval: TimeInterval

    static let `default` = AppConfig(
        accounts: [Account(label: "Account 1", configDir: nil)],
        pollInterval: 180
    )
}

/// Loads/saves `AppConfig` to `UserDefaults`. On first launch, seeds a single
/// default-config-dir account (the one Claude Code logs in by default).
@MainActor
final class ConfigStore {
    static let shared = ConfigStore()

    private let key = "appConfig"
    private(set) var config: AppConfig

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = decoded
        } else {
            config = .default
        }
    }

    func save(_ newConfig: AppConfig) {
        config = newConfig
        if let data = try? JSONEncoder().encode(newConfig) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func addAccount(_ account: Account) {
        var c = config
        c.accounts.append(account)
        save(c)
    }

    func updateAccount(_ account: Account) {
        var c = config
        if let idx = c.accounts.firstIndex(where: { $0.id == account.id }) {
            c.accounts[idx] = account
            save(c)
        }
    }

    func removeAccount(id: UUID) {
        var c = config
        c.accounts.removeAll { $0.id == id }
        save(c)
    }
}
