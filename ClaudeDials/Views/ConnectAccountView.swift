import SwiftUI

/// Guides the user through logging a second Claude account into its own config
/// dir, then polls the Keychain until that account's credential appears.
struct ConnectAccountView: View {
    var monitor: UsageMonitor
    var onDone: () -> Void

    @State private var phase: Phase = .intro
    @State private var pollTask: Task<Void, Never>?

    enum Phase {
        case intro
        case waiting
        case success
        case cliMissing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.large) {
            header

            switch phase {
            case .intro:       intro
            case .waiting:     waiting
            case .success:     success
            case .cliMissing:  cliMissing
            }
        }
        .padding(Theme.Space.xlarge)
        .frame(width: 440)
        .background(Theme.Surface.window)
        .onDisappear { pollTask?.cancel() }
    }

    private var header: some View {
        HStack(spacing: Theme.Space.medium) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Brand.lightBlue)
            Text("CONNECT SECOND ACCOUNT")
                .font(Theme.Typo.sectionLabel)
                .tracking(1.6)
                .foregroundStyle(Theme.Ink.primary)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Text("Claude Code stores one login per profile, so your second account needs its own profile. This opens Terminal and runs a one-time login into a dedicated profile — pick your **other** account in the browser that appears.")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Ink.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            CapsuleButton(title: "Open Terminal and log in…") {
                start()
            }
        }
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            HStack(spacing: Theme.Space.medium) {
                ProgressView().controlSize(.small)
                Text("Waiting for the second account to finish logging in…")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Ink.secondary)
            }
            Text("Complete the login in Terminal and the browser. When it's done, this dial lights up automatically.")
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.Ink.tertiary)
                .lineSpacing(2)
            Button("Cancel") { phase = .intro; pollTask?.cancel() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Brand.lightBlue)
                .font(Theme.Typo.caption)
        }
    }

    private var success: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            HStack(spacing: Theme.Space.small) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.Brand.green)
                Text("Second account connected.")
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Ink.primary)
            }
            CapsuleButton(title: "Done", action: onDone)
        }
    }

    private var cliMissing: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Text("Couldn't find the **claude** command on this Mac. Install Claude Code, or open Terminal yourself and run this, then return here:")
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Ink.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Text("CLAUDE_CONFIG_DIR=\"\(AccountSetupService.secondConfigDir)\" claude /login")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.Ink.primary)
                .padding(Theme.Space.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Surface.raised)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .textSelection(.enabled)
            Button("I've logged in — check now") { beginPolling() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Brand.lightBlue)
                .font(Theme.Typo.body)
        }
    }

    // MARK: - Actions

    private func start() {
        if AccountSetupService.launchSecondAccountLogin() {
            phase = .waiting
            beginPolling()
        } else {
            phase = .cliMissing
        }
    }

    private func beginPolling() {
        phase = .waiting
        pollTask?.cancel()
        pollTask = Task {
            // Poll the Keychain until the second account's credential appears.
            for _ in 0..<600 {                       // up to ~10 minutes
                if Task.isCancelled { return }
                if AccountSetupService.secondAccountIsLoggedIn() {
                    AccountSetupService.registerSecondAccount()
                    monitor.reloadConfig()
                    await monitor.refresh()
                    phase = .success
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
