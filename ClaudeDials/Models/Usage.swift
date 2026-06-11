import Foundation

/// A single rate-limit window as reported by the usage endpoint.
struct UsageWindow: Equatable {
    /// 0–100.
    let utilization: Double
    let resetsAt: Date?
}

/// The parsed `/api/oauth/usage` response for one account.
/// Field names mirror the endpoint: five_hour / seven_day / seven_day_opus.
struct AccountUsage: Equatable {
    let session: UsageWindow?      // five_hour
    let week: UsageWindow?         // seven_day
    let weekOpus: UsageWindow?     // seven_day_opus

    /// Worst utilization across all known windows — drives the capsule color so it
    /// never under-reports.
    var worstUtilization: Double {
        [session, week, weekOpus].compactMap { $0?.utilization }.max() ?? 0
    }
}

/// Everything the UI needs to render one account at a moment in time.
enum AccountState: Equatable {
    case loading
    case ok(AccountUsage)
    /// Last good data, but the most recent fetch failed.
    case stale(AccountUsage, since: Date)
    /// No credential found in the Keychain for this account.
    case disconnected
    /// Credential found but its access token has expired (open Claude Code to refresh).
    case tokenExpired
    /// Credential valid but the endpoint is failing; keep showing last data if we have it.
    case endpointDown(lastKnown: AccountUsage?)

    /// The usage to render, if any state carries it.
    var usage: AccountUsage? {
        switch self {
        case .ok(let u):                return u
        case .stale(let u, _):          return u
        case .endpointDown(let u):      return u
        case .loading, .disconnected, .tokenExpired: return nil
        }
    }

    var isConnected: Bool {
        switch self {
        case .disconnected: return false
        default:            return true
        }
    }
}

/// A point-in-time result paired with its account, held by the monitor.
struct AccountSnapshot: Identifiable {
    let id: UUID            // Account.id
    var state: AccountState
    var lastUpdated: Date?
    /// Tier badge from the last successful credential read, e.g. "MAX 5×".
    var tier: String?
}
