import SwiftUI

/// The popover shown from the menu-bar capsule: the monitored account's live
/// session usage, with header and footer chrome.
struct PopoverView: View {
    @ObservedObject var monitor: UsageMonitor

    var onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ForEach(monitor.snapshots) { snapshot in
                AccountSectionView(
                    snapshot: snapshot,
                    tierBadge: snapshot.tier ?? "CLAUDE",
                    displayLabel: monitor.displayLabel(for: snapshot.id)
                )
            }
            footer
        }
        .frame(width: 330)
        .background(Theme.Surface.panel)
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
}
