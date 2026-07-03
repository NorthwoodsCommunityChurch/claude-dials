import Foundation
import Combine

/// Coordinates the credential read + usage fetch for the monitored account and
/// publishes the resulting snapshot. Polls on an interval and on demand. Holds
/// no secrets beyond the in-memory access token for the duration of a fetch.
@MainActor
final class UsageMonitor: ObservableObject {

    @Published private(set) var snapshots: [AccountSnapshot] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh: Date?
    /// Live identity (email/org → friendly name), keyed by account id. Re-resolved
    /// every poll so the displayed name tracks whoever is logged in.
    @Published private(set) var identities: [UUID: AccountIdentity] = [:]

    /// Called after every refresh so the menu-bar capsule can redraw.
    var onUpdate: (() -> Void)?

    private var accounts: [Account] = []
    private var timer: Timer?
    private var pollInterval: TimeInterval = 180

    init() {
        reloadConfig()
    }

    /// Re-reads the persisted account and seeds a snapshot for it.
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

    func account(for id: UUID) -> Account? {
        accounts.first { $0.id == id }
    }

    /// The name to show for the account: the email-derived identity ("Personal" /
    /// "Northwoods"), resolved live from the logged-in account. Falls back to a
    /// neutral label until the first resolve lands (or when logged out).
    func displayLabel(for id: UUID) -> String {
        identities[id]?.displayName ?? "Claude"
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

        // Cache the live identity so the name + capsule initial follow whichever
        // account is currently logged into Claude Code. Cleared when it can't be
        // resolved so a stale name never lingers — this is the fix for the name
        // not updating across an account switch.
        identities[result.id] = result.identity
    }

    private struct FetchResult {
        let id: UUID
        let state: AccountState
        let tier: String?
        let identity: AccountIdentity?
    }

    /// Reads the Keychain and hits the endpoint for the account, mapping every
    /// failure to a designed degraded state. Runs off the main actor. Re-resolves
    /// the identity each poll (a cheap `.claude.json` read) so the displayed name
    /// reflects whoever is logged in right now.
    private nonisolated static func fetchState(for account: Account) async -> FetchResult {
        let identity = AccountIdentityResolver.resolve()

        let credential: ClaudeCredential
        do {
            credential = try KeychainReader.credential()
        } catch {
            return FetchResult(id: account.id, state: .disconnected, tier: nil, identity: identity)
        }

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
