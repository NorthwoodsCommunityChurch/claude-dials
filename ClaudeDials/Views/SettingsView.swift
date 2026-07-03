import SwiftUI

/// Settings window — utility surface (stock Form is intentional here). Shows the
/// detected account read-only (the name comes from whoever is logged into Claude
/// Code, not a manual label) plus the poll interval.
struct SettingsView: View {
    @ObservedObject var monitor: UsageMonitor

    @State private var pollMinutes: Double = ConfigStore.shared.config.pollInterval / 60

    var body: some View {
        Form {
            Section("Account") {
                accountRow
            }

            Section("Polling") {
                VStack(alignment: .leading) {
                    Text("Refresh every \(Int(pollMinutes)) min")
                    Slider(value: $pollMinutes, in: 1...10, step: 1) { editing in
                        if !editing { save() }
                    }
                    Text("The usage endpoint is unofficial; ~3 min keeps well clear of its rate limit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Claude Dials reads the usage data that Claude Code's /usage screen shows for the account you're logged into. The endpoint is unofficial and may change.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 320)
    }

    @ViewBuilder
    private var accountRow: some View {
        let id = monitor.snapshots.first?.id
        let name = id.map { monitor.displayLabel(for: $0) } ?? "—"
        let email = id.flatMap { monitor.identities[$0]?.email }

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                if let email, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("Claude Code login")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        var config = ConfigStore.shared.config
        config.pollInterval = pollMinutes * 60
        ConfigStore.shared.save(config)
        monitor.reloadConfig()
    }
}
