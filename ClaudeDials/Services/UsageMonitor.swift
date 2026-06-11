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

    // MARK: - Refresh

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(of: FetchResult.self) { group in
            for account in accounts {
                group.addTask { [account] in
                    await Self.fetchState(for: account)
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
    }

    private struct FetchResult {
        let id: UUID
        let state: AccountState
        let tier: String?
    }

    /// Reads the Keychain and hits the endpoint for one account, mapping every
    /// failure to a designed degraded state. Runs off the main actor.
    private nonisolated static func fetchState(for account: Account) async -> FetchResult {
        let credential: ClaudeCredential
        do {
            credential = try KeychainReader.credential(forConfigDir: account.configDir)
        } catch {
            return FetchResult(id: account.id, state: .disconnected, tier: nil)
        }

        let tier = credential.tierBadge
        if credential.isExpired {
            return FetchResult(id: account.id, state: .tokenExpired, tier: tier)
        }

        do {
            let usage = try await UsageClient.fetchUsage(using: credential)
            return FetchResult(id: account.id, state: .ok(usage), tier: tier)
        } catch UsageClient.ClientError.tokenExpired,
                UsageClient.ClientError.unauthorized {
            return FetchResult(id: account.id, state: .tokenExpired, tier: tier)
        } catch {
            // Rate-limited, server error, transport, or schema drift: keep last data.
            return FetchResult(id: account.id, state: .endpointDown(lastKnown: nil), tier: tier)
        }
    }
}
