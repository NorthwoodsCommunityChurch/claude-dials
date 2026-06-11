import SwiftUI

/// The popover shown from the menu-bar capsule. Routes between the onboarding
/// hero (single-account first run) and the populated multi-account view.
struct PopoverView: View {
    @ObservedObject var monitor: UsageMonitor
    @AppStorage("onboardingDismissed") private var onboardingDismissed = false

    var onConnectSecond: () -> Void
    var onOpenSettings: () -> Void
    var onReconnect: (UUID) -> Void

    private var showOnboarding: Bool {
        monitor.isSingleAccountFirstRun && !onboardingDismissed
    }

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(
                    monitor: monitor,
                    onConnect: onConnectSecond,
                    onSkip: { onboardingDismissed = true }
                )
            } else {
                populated
            }
        }
        .frame(width: 330)
        .background(Theme.Surface.panel)
    }

    // MARK: - Populated

    private var populated: some View {
        VStack(spacing: 0) {
            header
            ForEach(monitor.snapshots) { snapshot in
                if let account = monitor.account(for: snapshot.id) {
                    AccountSectionView(
                        account: account,
                        snapshot: snapshot,
                        accountIndex: monitor.index(of: snapshot.id),
                        resetsNext: resetsNextID == snapshot.id,
                        tierBadge: snapshot.tier ?? "CLAUDE",
                        onReconnect: { onReconnect(snapshot.id) }
                    )
                }
            }
            footer
        }
    }

    private var header: some View {
        HStack {
            Text("CLAUDE DIALS")
                .font(Theme.Typo.sectionLabel)
                .tracking(2)
                .foregroundStyle(Theme.Ink.primary)
            Spacer()
            Button(action: { Task { await monitor.refresh() } }) {
                HStack(spacing: Theme.Space.tight) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                    if let last = monitor.lastRefresh {
                        Text(last.compactAge())
                            .font(Theme.Typo.caption)
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(Theme.Ink.tertiary)
            }
            .buttonStyle(.plain)
            .disabled(monitor.isRefreshing)
        }
        .padding(.horizontal, Theme.Space.large)
        .padding(.top, Theme.Space.medium)
        .padding(.bottom, Theme.Space.small)
    }

    private var footer: some View {
        HStack {
            if let last = monitor.lastRefresh {
                Text("Updated \(last.compactAge()) ago")
            } else {
                Text("Updating…")
            }
            Spacer()
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
        .font(Theme.Typo.caption)
        .foregroundStyle(Theme.Ink.tertiary)
        .padding(.horizontal, Theme.Space.large)
        .padding(.vertical, Theme.Space.small)
        .overlay(Rectangle().fill(Theme.Surface.hairline).frame(height: 1), alignment: .top)
    }

    /// The account whose session window resets soonest — marked with the pointer.
    private var resetsNextID: UUID? {
        monitor.snapshots
            .compactMap { snap -> (UUID, Date)? in
                guard let reset = snap.state.usage?.session?.resetsAt else { return nil }
                return (snap.id, reset)
            }
            .min { $0.1 < $1.1 }?
            .0
    }
}
