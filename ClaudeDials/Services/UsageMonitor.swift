import Foundation
import Combine

/// Coordinates credential reads + usage fetches for every configured account and
/// publishes the resulting snapshots. Polls on an interval and on demand. Holds
/// no secrets beyond the in-memory access token for the duration of a fetch.
@MainActor
final class UsageMonitor: ObservableObject {

    @Published private(set) var snapshots: [AccountSnapshot] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh: Date?
    /// Resolved identities (email/org → friendly name), cached per account.
    @Published private(set) var identities: [UUID: AccountIdentity] = [:]

    /// Called after every refresh so the menu-bar capsule can redraw.
    var onUpdate: (() -> Void)?

    private var accounts: [Account] = []
    private var timer: Timer?
    private var pollInterval: TimeInterval = 180

    init() {
        reloadConfig()
    }

    /// Re-reads the persisted account list and resets snapshots for any new accounts.
    func reloadConfig() {
        discoverSecondAccountIfPresent()
        let config = ConfigStore.shared.config
        accounts = config.accounts
        pollInterval = config.pollInterval

        // Preserve existing snapshots where the account still exists; seed new ones.
        var rebuilt: [AccountSnapshot] = []
        for account in accounts {
            if let existing = snapshots.first(where: { $0.id == account.id }) {
                rebuilt.append(existing)
            } else {
                rebuilt.append(AccountSnapshot(id: account.id, state: .loading, lastUpdated: nil))
            }
        }
        snapshots = rebuilt
        restartTimer()
    }

    /// Self-healing: if the dedicated second-account profile has a logged-in
    /// credential but isn't in the account list (e.g. settings were reset, or the
    /// connect flow's registration didn't land), register it automatically.
    private func discoverSecondAccountIfPresent() {
        let dir = AccountSetupService.secondConfigDir
        guard KeychainReader.hasCredential(forConfigDir: dir) else { return }
        let already = ConfigStore.shared.config.accounts.contains { $0.configDir == dir }
        guard !already else { return }
        ConfigStore.shared.addAccount(Account(label: "Account 2", configDir: dir))
    }

    func start() {
        restartTimer()
        Task { await refresh() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    /// Whether the monitor is in its first-run shape: exactly one account and it's
    /// the default install. Drives the onboarding "connect second account" surface.
    var isSingleAccountFirstRun: Bool {
        accounts.count == 1 && accounts.first?.configDir == nil
    }

    func account(for id: UUID) -> Account? {
        accounts.first { $0.id == id }
    }

    func index(of id: UUID) -> Int {
        accounts.firstIndex { $0.id == id } ?? 0
    }

    /// The label to show for an account: a manual (non-generic) label wins;
    /// otherwise the email-derived name ("Personal" / "Northwoods"); else the
    /// stored label.
    func displayLabel(for id: UUID) -> String {
        let stored = account(for: id)?.label ?? "Account"
        if !Self.isGenericLabel(stored) { return stored }
        return identities[id]?.displayName ?? stored
    }

    private static func isGenericLabel(_ label: String) -> Bool {
        label.range(of: #"^Account \d+$"#, options: .regularExpression) != nil
            || label.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Refresh

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let cachedIdentities = identities
        await withTaskGroup(of: FetchResult.self) { group in
            for account in accounts {
                let cached = cachedIdentities[account.id]
                group.addTask { [account] in
                    await Self.fetchState(for: account, cachedIdentity: cached)
                }
            }
            for await result in group {
                apply(result)
            }
        }

        lastRefresh = Date()
        onUpdate?()
    }

    private func apply(_ result: FetchResult) {
        guard let idx = snapshots.firstIndex(where: { $0.id == result.id }) else { return }
        let previous = snapshots[idx]

        // On a soft endpoint failure, fall back to last-known usage rather than blanking.
        let resolved: AccountState
        if case .endpointDown = result.state {
            resolved = .endpointDown(lastKnown: previous.state.usage)
        } else {
            resolved = result.state
        }

        let didSucceed = { if case .ok = resolved { return true } else { return false } }()
        snapshots[idx] = AccountSnapshot(
            id: result.id,
            state: resolved,
            lastUpdated: didSucceed ? Date() : previous.lastUpdated,
            tier: result.tier ?? previous.tier
        )

        // Cache the resolved identity and, if the account still has a generic
        // label, persist the email-derived name so Settings shows it too.
        if let identity = result.identity {
            identities[result.id] = identity
            if let name = identity.displayName,
               var account = account(for: result.id),
               Self.isGenericLabel(account.label) {
                account.label = name
                if let i = accounts.firstIndex(where: { $0.id == account.id }) {
                    accounts[i] = account
                }
                ConfigStore.shared.updateAccount(account)
            }
        }
    }

    private struct FetchResult {
        let id: UUID
        let state: AccountState
        let tier: String?
        let identity: AccountIdentity?
    }

    /// Reads the Keychain and hits the endpoint for one account, mapping every
    /// failure to a designed degraded state. Runs off the main actor. Resolves the
    /// account identity only when not already cached (it requires a subprocess).
    private nonisolated static func fetchState(
        for account: Account,
        cachedIdentity: AccountIdentity?
    ) async -> FetchResult {
        let credential: ClaudeCredential
        do {
            credential = try KeychainReader.credential(forConfigDir: account.configDir)
        } catch {
            return FetchResult(id: account.id, state: .disconnected, tier: nil, identity: cachedIdentity)
        }

        // Resolve identity once (subprocess); reuse the cache on later polls.
        let identity = cachedIdentity ?? AccountIdentityResolver.resolve(configDir: account.configDir)

        let tier = credential.tierBadge
        if credential.isExpired {
            return FetchResult(id: account.id, state: .tokenExpired, tier: tier, identity: identity)
        }

        do {
            let usage = try await UsageClient.fetchUsage(using: credential)
            return FetchResult(id: account.id, state: .ok(usage), tier: tier, identity: identity)
        } catch UsageClient.ClientError.tokenExpired,
                UsageClient.ClientError.unauthorized {
            return FetchResult(id: account.id, state: .tokenExpired, tier: tier, identity: identity)
        } catch {
            // Rate-limited, server error, transport, or schema drift: keep last data.
            return FetchResult(id: account.id, state: .endpointDown(lastKnown: nil), tier: tier, identity: identity)
        }
    }
}
