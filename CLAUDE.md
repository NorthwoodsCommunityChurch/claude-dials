# Claude Dials — Project Context

macOS menu-bar utility showing live Claude **session usage** for two accounts as twin ring
dials in a dark capsule, with a broadcast-style detail popover. Internal Northwoods AVL tool.
Companion to Junk Drawer (same menu-bar-only stack). Stack: AppKit + SwiftUI + Sparkle,
menu-bar-only (`LSUIElement`), built with xcodegen. No third-party deps besides Sparkle.

> **Read first:** [README.md](README.md) (features, usage, build), [CREDITS.md](CREDITS.md),
> [DESIGN.md](DESIGN.md) (the locked design — SwiftUI is a faithful port of it). Org release +
> Sparkle details: `../App Updates/SPARKLE-GUIDE.md`.

---

## Status — 2026-06-11
- **Stage:** built, verified locally, not yet released (no GitHub repo / appcast yet).
- **Works:** reads account-1 credential from the Keychain and the live `/api/oauth/usage`
  endpoint (verified HTTP 200, real utilization); twin-ring capsule menu-bar icon; popover with
  color-block account headers, session ring + live countdown, week/Opus segment meters; all
  degraded states (loading / stale / disconnected / token-expired / endpoint-down); onboarding
  hero; second-account connect flow (Terminal + CLAUDE_CONFIG_DIR); Settings; About; Sparkle.
- **Verified via** the `CLAUDEDIALS_DUMP` env-gated diagnostic that renders popover/capsule/about
  to PNG using live data (the menu-bar manager on the dev Mac hides the status item, so direct
  screenshotting of the capsule isn't reliable).
- **Next:** decide GitHub repo visibility (see ⚠️ below), push, cut v1.0.0, create
  `appcast-claudedials.xml`. App icon + all repo-standard files are done.

> ⚠️ **ToS caveat (load-bearing — discuss before public release):** reading the subscription
> OAuth token and calling `/api/oauth/usage` is, per Anthropic's Feb 2026 Consumer ToS, "not
> permitted" for third-party tools. Aaron opted in knowingly for internal use. Recommend the
> GitHub repo be **private**. The endpoint is also unofficial and can break anytime — every
> failure is handled as a designed degraded state, not a crash.

## What it does
Menu-bar-only app. Places one `NSStatusItem` drawn as a warm-black capsule containing up to two
status rings (one per account), each filled to the 5-hour session utilization and colored by the
worst of session/week/Opus (green <60, gold 60–85, coral >85). Left-click → popover; right-click
→ context menu. Polls every 3 min (configurable) + on popover open + on demand.

## Architecture
```
ClaudeDialsApp (@main, SwiftUI App, Settings{EmptyView})  ← LSUIElement, no real Scene window
   └─ AppDelegate (NSApplicationDelegateAdaptor)
        ├─ FontRegistrar.registerBundledFonts()           Myriad Pro OTFs → CTFontManager
        ├─ SPUStandardUpdaterController (Sparkle)
        ├─ UsageMonitor (ObservableObject)                 polls accounts, publishes snapshots
        │     • per-account: KeychainReader → UsageClient → AccountState
        ├─ StatusBarController(monitor:updater:)           capsule + popover + context menu
        │     • redraws CapsuleStatusIcon on monitor.$snapshots
        └─ on-demand NSWindows: Settings / About / ConnectAccount (built by AppDelegate)
```

### Where things live
```
ClaudeDials/
├── ClaudeDialsApp.swift          @main
├── AppDelegate.swift             wiring + on-demand windows + diagnostic dump hook
├── StatusBarController.swift     status item, popover, right-click menu
├── CapsuleStatusIcon.swift       CORE custom drawing: twin-ring capsule NSImage
├── Theme.swift                   brand palette, surface tiers, Myriad type scale, spacing
├── Models/Account.swift          Account, AppConfig, ConfigStore (UserDefaults)
├── Models/Usage.swift            UsageWindow, AccountUsage, AccountState, AccountSnapshot
├── Services/KeychainReader.swift reads "Claude Code-credentials[-<hash>]" generic password
├── Services/UsageClient.swift    GET /api/oauth/usage (+ ClaudeCodeVersion UA resolver)
├── Services/UsageMonitor.swift   coordinator/poller (@MainActor ObservableObject)
├── Services/AccountSetupService.swift  second-account login via CLAUDE_CONFIG_DIR + Terminal
├── Services/FontRegistrar.swift  font registration
├── Services/DiagnosticDump.swift CLAUDEDIALS_DUMP → render UI to PNG (ships, env-gated)
├── Views/                        RingDial, SegmentMeter, Components, AccountSectionView,
│                                 PopoverView, OnboardingView, SettingsView, AboutView,
│                                 ConnectAccountView
├── Resources/Fonts/              MyriadPro-{Regular,Semibold,Black}.otf
├── Resources/northwoods-symbol-white.png
└── Assets.xcassets/AppIcon.appiconset
```

## Key identifiers
| Thing | Value |
|---|---|
| Type / stack | macOS Swift (AppKit + SwiftUI + Sparkle), menu-bar-only (`LSUIElement`) |
| GitHub repo | `NorthwoodsCommunityChurch/claude-dials` (not created yet) |
| Bundle ID | `com.northwoodschurch.claudedials` |
| Current version | 1.0.0 (build 1) — unreleased |
| Update feed (Sparkle) | `https://northwoodscommunitychurch.github.io/app-updates/appcast-claudedials.xml` (not created yet) |
| Sparkle public key | `VIMxKZmmRokdMcHK5d3QU4+qHgBglmkVFP5aAVvxgqM=` (org key; private key in OneDrive) |
| Deployment target | macOS 15.0 · Xcode 16 · Swift 6.0 · Apple Silicon |

## Build / Run / Release
```bash
xcodegen generate
xcodebuild -scheme ClaudeDials -configuration Release -derivedDataPath build build
# Verify UI without launching the menu bar (renders to /tmp/claudedials_*.png):
CLAUDEDIALS_DUMP=/tmp "build/Build/Products/Release/Claude Dials.app/Contents/MacOS/Claude Dials"
```
Release: standard Northwoods Sparkle flow (build, ad-hoc sign incl. nested Sparkle, zip, upload
to the `app-updates` GitHub release, download that zip, sign it, put the signature in
**`appcast-claudedials.xml`** — this app's own appcast). Full steps: `../App Updates/SPARKLE-GUIDE.md`.
Ask Aaron before bumping the version.

## Conventions & gotchas
- **Unofficial data source.** Endpoint, headers (`anthropic-beta: oauth-2025-04-20`, the REQUIRED
  `User-Agent: claude-code/<version>` — without it you get persistent 429s), response shape, and
  the Keychain service-name hash are all reverse-engineered. Treat 401/403/429/schema-drift as
  expected; never crash, degrade. Don't poll faster than ~60–180 s.
- **No token refresh by design (v1).** We re-read the Keychain each poll and piggyback on Claude
  Code's own refresh. If the token's expired we show `tokenExpired`, not refresh ourselves —
  refreshing would fight Claude Code over the rotating refresh token and risks Keychain-write ACL
  issues. Max-tier tokens last ~8 h, so this is fine in practice.
- **Keychain service names** (decompiled from Claude Code): default = `Claude Code-credentials`;
  a `CLAUDE_CONFIG_DIR` profile = `Claude Code-credentials-<first 8 hex of sha256(NFC(path))>`.
  This hashing is how two accounts coexist — see `KeychainReader.serviceName`.
- **Two accounts = two config dirs.** A single config dir holds one login; `/login` overwrites it.
  `AccountSetupService` creates a dedicated dir (`~/Library/Application Support/Claude Dials/
  account-2`) and logs the second account in there so both Keychain items persist.
- **The capsule is custom-drawn**, non-template (colored), redrawn on every snapshot change. It is
  the app's silhouette — `CapsuleStatusIcon.make(rings:)`.
- **Worst-window-wins color.** The capsule ring color reflects `max(session, week, opus)` so it
  never looks healthier than the tightest limit.
- **Verifying UI on a Mac with a menu-bar manager:** the manager hides the status item, so use the
  `CLAUDEDIALS_DUMP` diagnostic rather than screenshotting the live menu bar.
- **GENERATE_INFOPLIST_FILE + Sparkle keys** injected via `INFOPLIST_KEY_*` (same pattern as Junk
  Drawer). Non-sandboxed (no entitlements file) — required to read another app's Keychain item and
  run the `claude` CLI.

## Update Protocol
| When you… | Update… |
|---|---|
| ship a version | Status date · Current version · appcast-claudedials.xml |
| add/rename a feature, view, or service | What it does · Architecture · Where things live |
| hit & fix a gotcha | Conventions & gotchas |
| change the data source / endpoint behavior | Conventions & gotchas + CREDITS.md |

End a work session with **`/save`**.

## Document history
| Date | Change |
|---|---|
| 2026-06-11 | Initial creation — app built, verified locally against live data, pre-release |
