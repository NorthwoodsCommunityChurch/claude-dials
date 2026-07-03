import SwiftUI

/// The account's full section: color-block header, session ring + countdown,
/// week/Opus segment meters, and any degraded-state strip. Every state from
/// DESIGN.md (ok / stale / disconnected / token-expired / endpoint-down) renders
/// here — none fall through to a blank.
struct AccountSectionView: View {
    let snapshot: AccountSnapshot
    let tierBadge: String
    /// Resolved, email-derived label ("Personal" / "Northwoods").
    let displayLabel: String

    private var usage: AccountUsage? { snapshot.state.usage }

    var body: some View {
        VStack(spacing: 0) {
            ColorBlockHeader(
                name: displayLabel,
                tier: tierBadge,
                color: Theme.Brand.blue
            )

            VStack(alignment: .leading, spacing: 0) {
                sessionRow
                    .padding(.bottom, usage != nil ? Theme.Space.small : 0)

                if let usage {
                    SegmentMeter(label: "WEEK", utilization: usage.week?.utilization)
                        .padding(.top, Theme.Space.tight)
                    ForEach(usage.modelWeeklyLimits) { limit in
                        SegmentMeter(label: limit.modelName.uppercased(), utilization: limit.window.utilization)
                            .padding(.top, Theme.Space.tight)
                    }
                }
            }
            .padding(.horizontal, Theme.Space.large)
            .padding(.vertical, Theme.Space.medium)
            .opacity(isStale ? 0.55 : 1)

            strip
        }
    }

    // MARK: - Session row (ring + countdown / status)

    private var sessionRow: some View {
        HStack(spacing: Theme.Space.large) {
            RingDial(utilization: sessionUtilization)

            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text("SESSION")
                    .font(Theme.Typo.meterLabel)
                    .tracking(1.8)
                    .foregroundStyle(Theme.Ink.tertiary)
                sessionDetail
            }
            Spacer(minLength: 0)
        }
    }

    private var sessionUtilization: Double? {
        switch snapshot.state {
        case .disconnected, .tokenExpired, .loading:
            return nil
        default:
            return usage?.session?.utilization
        }
    }

    @ViewBuilder
    private var sessionDetail: some View {
        switch snapshot.state {
        case .loading:
            Text("checking…")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Ink.tertiary)
        case .disconnected:
            Text("not connected")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Ink.tertiary)
        case .tokenExpired:
            Text("token expired")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Brand.coral)
        case .stale:
            if let updated = snapshot.lastUpdated {
                Text("stale · \(updated.compactAge()) ago")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Ink.tertiary)
            }
        case .ok, .endpointDown:
            if usage?.session?.resetsAt != nil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: Theme.Space.tight) {
                        Text(Countdown.timecode(until: usage?.session?.resetsAt, now: context.date))
                            .font(Theme.Typo.timecode())
                            .foregroundStyle(Theme.Ink.primary)
                        Text("until reset")
                            .font(Theme.Typo.caption)
                            .foregroundStyle(Theme.Ink.tertiary)
                    }
                }
            } else {
                Text("no reset time")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Ink.tertiary)
            }
        }
    }

    private var isStale: Bool {
        if case .stale = snapshot.state { return true }
        return false
    }

    // MARK: - Degraded strips

    @ViewBuilder
    private var strip: some View {
        switch snapshot.state {
        case .endpointDown:
            WarningStrip(kind: .caution, title: "ENDPOINT NOT RESPONDING", subtitle: "· retrying")
        case .tokenExpired:
            // The default Claude Code login refreshes itself on next use — there's
            // nothing for this app to reconnect, so this is informational only.
            WarningStrip(kind: .alert, title: "TOKEN EXPIRED", subtitle: "· open Claude Code to refresh")
        default:
            EmptyView()
        }
    }
}
