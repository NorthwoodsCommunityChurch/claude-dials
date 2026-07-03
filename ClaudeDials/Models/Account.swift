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

/// Loads/saves `AppConfig` to `UserDefaults`. Claude Dials watches exactly one
/// account — the default Claude Code login — so the stored config is always
/// collapsed to that single account on load.
@MainActor
final class ConfigStore {
    static let shared = ConfigStore()

    private let key = "appConfig"
    private(set) var config: AppConfig

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = Self.collapsedToSingleAccount(decoded)
        } else {
            config = .default
        }
    }

    /// Older builds could persist a second `CLAUDE_CONFIG_DIR` profile alongside
    /// the default login. We now watch only the default account, so drop any
    /// extra profiles and keep the single default-config-dir account.
    private static func collapsedToSingleAccount(_ config: AppConfig) -> AppConfig {
        var c = config
        let defaultAccount = c.accounts.first { $0.configDir == nil }
            ?? Account(label: "Account 1", configDir: nil)
        c.accounts = [defaultAccount]
        return c
    }

    func save(_ newConfig: AppConfig) {
        config = newConfig
        if let data = try? JSONEncoder().encode(newConfig) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
