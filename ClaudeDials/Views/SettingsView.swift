import SwiftUI

/// Settings window — utility surface (stock Form is intentional here), with the
/// account list rendered as custom rows since they carry brand identity.
struct SettingsView: View {
    var monitor: UsageMonitor
    var onConnectSecond: () -> Void

    @State private var accounts: [Account] = ConfigStore.shared.config.accounts
    @State private var pollMinutes: Double = ConfigStore.shared.config.pollInterval / 60

    var body: some View {
        Form {
            Section("Accounts") {
                ForEach($accounts) { $account in
                    AccountRow(account: $account) { save() }
                }
                if accounts.count < 2 {
                    Button("Connect second account…", action: onConnectSecond)
                }
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
                Text("Claude Dials reads the usage data that Claude Code's /usage screen shows. The endpoint is unofficial and may change.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 360)
        .onAppear { accounts = ConfigStore.shared.config.accounts }
    }

    private func save() {
        var config = ConfigStore.shared.config
        config.accounts = accounts
        config.pollInterval = pollMinutes * 60
        ConfigStore.shared.save(config)
        monitor.reloadConfig()
    }
}

private struct AccountRow: View {
    @Binding var account: Account
    var onCommit: () -> Void

    var body: some View {
        HStack {
            TextField("Label", text: $account.label)
                .textFieldStyle(.plain)
                .onSubmit(onCommit)
            Spacer()
            Text(account.configDir == nil ? "default" : "profile")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
