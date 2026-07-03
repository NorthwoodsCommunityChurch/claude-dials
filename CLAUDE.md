# Claude Dials — Project Context

macOS menu-bar utility showing live Claude **session usage** for the logged-in account as a ring
dial in a dark capsule, with a broadcast-style detail popover. Internal Northwoods AVL tool.
Companion to Junk Drawer (same menu-bar-only stack). Stack: AppKit + SwiftUI + Sparkle,
menu-bar-only (`LSUIElement`), built with xcodegen. No third-party deps besides Sparkle.

> **Read first:** [README.md](README.md) (features, usage, build), [CREDITS.md](CREDITS.md),
> [DESIGN.md](DESIGN.md) (the locked design — SwiftUI is a faithful port of it). Org release +
> Sparkle details: `../App Updates/SPARKLE-GUIDE.md`.

---

## Status — 2026-07-03
- **Stage:** **released — v1.0.0 is live.** Built, verified locally (clean Release build), and
  shipped as this repo's first-ever GitHub release: `appcast-claudedials.xml` is created and
  serving on GitHub Pages, so the app now auto-updates via Sparkle like every other Northwoods
  app. The big 2026-06-16 single-account refactor + the 2026-06-22 signing fix + the 2026-07-03
  usage-schema fix were checkpointed and released together (first push since `b173cf8`).
- **2026-07-03 (later) — recurring Keychain prompt ROOT-CAUSED and fixed.** The "random" re-prompt
  (still open at v1.0.0) was finally reproduced and diagnosed: it was **never a code-signing
  problem** — Claude Dials' identity-based ACL grant was intact the whole time. The real trigger is
  the keychain item's **partition list**. macOS allows a silent read only if the caller is both in
  the item's trusted-app ACL *and* its code-signing partition is in the item's partition list.
  Claude Code owns the item and rewrites it on every token refresh, which **resets the partition
  list and drops Claude Dials' `teamid:TQ6Y49W7UW` partition** — so the next read prompts, "Always
  Allow" re-adds it, and the next refresh wipes it again (≈ Claude Code's refresh cadence = the
  "random" feel). Proven by dumping the ACL before/after a refresh: `teamid:` present → gone, while
  `apple-tool:` survived. **Fix:** `KeychainReader` now reads via `/usr/bin/security` (a subprocess)
  instead of in-process `SecItemCopyMatching`. `/usr/bin/security` lives in the `apple-tool:`
  partition — exactly the one Claude Code's writes preserve — so the read stays silent across
  refreshes. Verified: `security` read the secret silently *with the teamid partition already
  dropped* (the previously-prompting state). Net effect: at most one prompt ever on a fresh machine
  (to trust `/usr/bin/security` once), then silent forever. This also makes the app's own signature
  irrelevant to keychain access, so `build.sh`'s stable-signing is no longer load-bearing for the
  prompt (kept anyway — it's still the build script and gives a stable identity for other uses).
  **Shipped in v1.0.1** (build 2), released 2026-07-03 via the normal Sparkle flow.
- **2026-07-03 — repo made public to enable Sparkle.** Sparkle's update check is a plain
  unauthenticated HTTPS GET — a private repo's release assets 404 for it. Every other Northwoods
  Sparkle app (Junk Drawer, Synaxis, Whisper Verses, Canopy, etc.) is a public repo; none had ever
  combined "private repo" with "Sparkle auto-update" before this project. Aaron chose public over
  skipping Sparkle. The ToS caveat below is about the *technique* (reading Claude Code's OAuth
  token, hitting an unofficial endpoint) being more visible now, not about any leaked secret — the
  security review before release found none in the repo, and the token itself is read from the
  local user's own Keychain at runtime, never embedded in code.
- **Works:** single-account model — reads the **default Claude Code login** credential from the
  Keychain and the live `/api/oauth/usage` endpoint (verified HTTP 200, real utilization);
  single-ring capsule menu-bar icon; popover with a color-block header whose **name is resolved
  live from the logged-in account** (`~/.claude.json` → "Personal"/"Northwoods"), session ring +
  live countdown, week + dynamic per-model weekly segment meters; all degraded states (loading /
  stale / disconnected / token-expired / endpoint-down); Settings (read-only account row + poll
  interval); About; Sparkle.
- **2026-07-03 — usage API schema drift fixed; capsule color bug fixed.** Anthropic replaced the
  old dedicated `seven_day_opus` field (now always `null`) with a dynamic `limits[]` array that
  names whichever model currently carries its own scoped weekly cap — confirmed live: the account
  in use right now is scoped on **Fable at 85%**, not Opus. `UsageClient` now parses `limits[]`
  generically into `AccountUsage.modelWeeklyLimits: [ModelWeeklyLimit]`, and
  `AccountSectionView` renders one `SegmentMeter` per entry it finds (so it'll show Sonnet, Opus,
  or any future model automatically, whichever Anthropic actually scopes — never hardcoded).
  Legacy `seven_day_opus`/`seven_day_sonnet` top-level fields are kept as a fallback path only if
  `limits[]` is absent. While in there, found and fixed a real bug: `CapsuleStatusIcon`'s ring
  **color** was driven by session % alone, not `worstUtilization` — so the menu-bar capsule could
  show green while an account sat at 85%+ of a weekly cap. Now uses worst-window color as
  `CLAUDE.md`/`DESIGN.md` always said it should; fill fraction is still session %, unchanged.
- **Verified via** the `CLAUDEDIALS_DUMP` env-gated diagnostic that renders popover/capsule/about
  to PNG using live data (the menu-bar manager on the dev Mac hides the status item, so direct
  screenshotting of the capsule isn't reliable).
- **2026-06-16 — collapsed to one account.** Removed the entire second-account mechanism
  (`AccountSetupService`, `TokenRefresher`, `ConnectAccountView`, `OnboardingView`, multi-account
  discovery, the connect menu item/buttons). Old 2-account configs auto-collapse to the single
  default account on launch (`ConfigStore`). Fixes the three reported bugs: the name now tracks the
  live login (was frozen on first resolve because the resolved name got baked into the stored
  label); no more Keychain *write* prompts (token refresher deleted — Keychain access is read-only
  again); the chronically-expiring app-managed second account is gone. Orphaned on disk from the
  old flow (harmless, unread): `~/Library/Application Support/Claude Dials/account-2` + Keychain
  item `Claude Code-credentials-16052f99`.
- **2026-06-22 — stable signing fix.** Keychain access re-prompted on every rebuild because
  ad-hoc signing has no stable identity. Now `build.sh` re-signs the bundle (Sparkle inside-out)
  with the Apple Development cert → one "Always Allow" sticks across rebuilds/copies. See the
  signing gotcha below.
- **Next:** nothing pending. Future releases follow the standard bump → build → ad-hoc sign →
  zip → GitHub release → sign downloaded zip → update appcast flow (SPARKLE-GUIDE.md). The
  released zip is ad-hoc signed per the org distribution flow — the Apple Development cert
  `build.sh` uses is for *local* rebuild stability only, never for distribution.

> ⚠️ **ToS note:** reading the subscription OAuth token and calling `/api/oauth/usage` is, per
> Anthropic's Feb 2026 Consumer ToS, "not permitted" for third-party tools. Aaron opted in
> knowingly for internal use. The repo is **public** (required for Sparkle's unauthenticated
> download to work — see 2026-07-03 above); no secrets live in it. The endpoint is also
> unofficial and can break anytime — every failure is handled as a designed degraded state,
> never a crash.

## What it does
Menu-bar-only app. Places one `NSStatusItem` drawn as a warm-black capsule containing a single
status ring, filled to the 5-hour session utilization and colored by the worst of session / week /
whichever model(s) currently carry their own scoped weekly cap (green <60, gold 60–85, coral >85).
Left-click → popover; right-click → context menu. Polls every 3 min (configurable) + on popover
open + on demand.

## Architecture
```
ClaudeDialsApp (@main, SwiftUI App, Settings{EmptyView})  ← LSUIElement, no real Scene window
   └─ AppDelegate (NSApplicationDelegateAdaptor)
        ├─ FontRegistrar.registerBundledFonts()           Myriad Pro OTFs → CTFontManager
        ├─ SPUStandardUpdaterController (Sparkle)
        ├─ UsageMonitor (ObservableObject)                 polls the account, publishes a snapshot
        │     • KeychainReader → UsageClient → AccountState (+ live ~/.claude.json identity)
        ├─ StatusBarController(monitor:updater:)           capsule + popover + context menu
        │     • redraws CapsuleStatusIcon on monitor.$snapshots
        └─ on-demand NSWindows: Settings / About (built by AppDelegate)
```

### Where things live
```
ClaudeDials/
├── ClaudeDialsApp.swift          @main
├── AppDelegate.swift             wiring + on-demand windows + diagnostic dump hook
├── StatusBarController.swift     status item, popover, right-click menu
├── CapsuleStatusIcon.swift       CORE custom drawing: single-ring capsule NSImage
├── Theme.swift                   brand palette, surface tiers, Myriad type scale, spacing
├── Models/Account.swift          Account, AppConfig, ConfigStore (UserDefaults)
├── Models/Usage.swift            UsageWindow, ModelWeeklyLimit, AccountUsage, AccountState, AccountSnapshot
├── Services/KeychainReader.swift reads "Claude Code-credentials" via /usr/bin/security (read-only)
├── Services/AccountIdentityResolver.swift  ~/.claude.json oauthAccount → friendly name
├── Services/UsageClient.swift    GET /api/oauth/usage (+ ClaudeCodeVersion UA resolver)
├── Services/UsageMonitor.swift   coordinator/poller (@MainActor ObservableObject)
├── Services/FontRegistrar.swift  font registration
├── Services/DiagnosticDump.swift CLAUDEDIALS_DUMP → render UI to PNG (ships, env-gated)
├── Services/LaunchAtLogin.swift  login-item registration (Open at Login)
├── Views/                        RingDial, SegmentMeter, Components, AccountSectionView,
│                                 PopoverView, SettingsView, AboutView
├── Resources/Fonts/              MyriadPro-{Regular,Semibold,Black}.otf
├── Resources/northwoods-symbol-white.png
└── Assets.xcassets/AppIcon.appiconset
```

## Key identifiers
| Thing | Value |
|---|---|
| Type / stack | macOS Swift (AppKit + SwiftUI + Sparkle), menu-bar-only (`LSUIElement`) |
| GitHub repo | `NorthwoodsCommunityChurch/claude-dials` (public, since 2026-07-03 — required for Sparkle) |
| Bundle ID | `com.northwoodschurch.claudedials` |
| Current version | 1.0.1 (build 2) — released 2026-07-03 (Keychain-prompt fix) |
| Update feed (Sparkle) | `https://northwoodscommunitychurch.github.io/app-updates/appcast-claudedials.xml` (live) |
| Sparkle public key | `VIMxKZmmRokdMcHK5d3QU4+qHgBglmkVFP5aAVvxgqM=` (org key; private key in OneDrive) |
| Deployment target | macOS 15.0 · Xcode 16 · Swift 6.0 · Apple Silicon |

## Build / Run / Release
```bash
./build.sh   # xcodegen + xcodebuild + re-sign with a STABLE identity (see gotcha below)
# Verify UI without launching the menu bar (renders to /tmp/claudedials_*.png):
CLAUDEDIALS_DUMP=/tmp "build/Build/Products/Release/Claude Dials.app/Contents/MacOS/Claude Dials"
```
**Always build via `./build.sh`, not a bare `xcodebuild`.** A bare xcodebuild signs
ad-hoc, which re-triggers the Keychain prompt on every rebuild (see gotcha).
Release: standard Northwoods Sparkle flow (build, ad-hoc sign incl. nested Sparkle, zip, upload
to the `app-updates` GitHub release, download that zip, sign it, put the signature in
**`appcast-claudedials.xml`** — this app's own appcast). Full steps: `../App Updates/SPARKLE-GUIDE.md`.
Ask Aaron before bumping the version.

## Conventions & gotchas
- **Keychain read goes through `/usr/bin/security`, NOT in-process (2026-07-03 fix — the real
  cure for the recurring prompt).** macOS gates a *silent* keychain read on two things: the caller
  must be in the item's trusted-app ACL **and** its code-signing partition must be in the item's
  partition list. Claude Code owns the credential item and rewrites it on every token refresh,
  resetting the partition list and dropping Claude Dials' `teamid:TQ6Y49W7UW` partition → the next
  in-process read prompts. Reading via `/usr/bin/security` sidesteps this: that Apple binary is in
  the `apple-tool:` partition, which is exactly the partition Claude Code's writes *preserve*, so
  it never gets dropped. Because keychain access is now evaluated against `/usr/bin/security` (not
  Claude Dials' own bundle), **the app's own signature is irrelevant to keychain prompts.** Don't
  "optimize" this back to `SecItemCopyMatching` — that reintroduces the recurring prompt. The
  secret only ever crosses the subprocess's stdout, never a command-line argument.
- **`build.sh` stable signing (2026-06-22) — now belt-and-suspenders, not load-bearing.** It was
  originally the fix for a *rebuild* re-prompt: ad-hoc signing (`CODE_SIGN_IDENTITY "-"`) has no
  stable identity, so each rebuild looked like a new app to the in-process reader. Since the read
  now goes through `/usr/bin/security` (above), the app's signature no longer affects keychain
  prompts at all. `build.sh` still re-signs the bundle (Sparkle inside-out) with the Apple
  Development cert (`Apple Development: larson.central@pm.me`, team `TQ6Y49W7UW`, SHA-1
  `C7C47640D77786FC360C811388F289BB0B71143C`) for a stable identity, which is harmless and fine to
  keep — just no longer the thing standing between you and the prompt. Keep building via
  `./build.sh` regardless (it's the canonical build). If the cert expires/rotates, update the SHA-1
  (`security find-identity -v -p codesigning`).
- **Unofficial data source.** Endpoint, headers (`anthropic-beta: oauth-2025-04-20`, the REQUIRED
  `User-Agent: claude-code/<version>` — without it you get persistent 429s), response shape, and
  the Keychain service-name hash are all reverse-engineered. Treat 401/403/429/schema-drift as
  expected; never crash, degrade. Don't poll faster than ~60–180 s.
- **No token refresh, by design.** We re-read the Keychain each poll and piggyback on Claude
  Code's own refresh. If the token's expired we show `tokenExpired` (open Claude Code to refresh),
  never refresh ourselves — that would fight Claude Code over the rotating refresh token and needs
  a Keychain *write*. Keychain access is read-only — and as of 2026-07-03 the read is done by
  spawning `/usr/bin/security` (see the read-path gotcha below), not `SecItemCopyMatching`.
  Max-tier tokens last ~8 h, so this is fine in practice. (A v1 build briefly had a `TokenRefresher`
  for app-owned second-account profiles; removed with the second account on 2026-06-16.)
- **Keychain service name** (decompiled from Claude Code): the default login = `Claude
  Code-credentials` — the only item Claude Dials reads. (Claude Code also hashes a
  `CLAUDE_CONFIG_DIR` profile into `Claude Code-credentials-<8 hex of sha256(NFC(path))>`; we no
  longer use that scheme — it was how the removed second account coexisted.)
- **Account name is live, never persisted.** The dial's name + capsule initial come from
  `AccountIdentityResolver` (reads `~/.claude.json` → "Personal"/"Northwoods"), re-resolved every
  poll, so they track whoever is logged into Claude Code. Do **not** bake the resolved name into
  the stored `Account.label` — an earlier build did, which froze the name across account switches
  (the bug this replaced).
- **The capsule is custom-drawn**, non-template (colored), redrawn on every snapshot change. It is
  the app's silhouette — `CapsuleStatusIcon.make(rings:)`, now a single ring.
- **Worst-window-wins color.** The capsule ring color reflects
  `max(session, week, modelWeeklyLimits...)` so it never looks healthier than the tightest limit.
  Fill fraction is always session % — only the *color* considers the other windows.
- **The usage endpoint's per-model weekly cap is dynamic, not fixed to Opus (2026-07-03).**
  The old `seven_day_opus` top-level field is now always `null`. Anthropic moved to a `limits[]`
  array; entries with `kind == "weekly_scoped"` carry a `scope.model.display_name` naming
  whichever model currently has its own weekly cap — verified live to currently be **Fable**, not
  Opus, on this account. `UsageClient.modelWeeklyLimits(_:)` parses this generically and
  `AccountSectionView` renders one meter per entry found, so the UI adapts automatically to
  whatever Anthropic scopes next (Sonnet, Opus, a new model) without another code change. Don't
  hardcode a model name anywhere in this path again.
- **The recurring prompt was the partition list, not account switches (2026-07-03 — corrected).**
  Earlier notes blamed `claude login` account switches and treated the "random" prompt as
  unexplained. Both were wrong. The real mechanism (see the `/usr/bin/security` gotcha above) is
  that Claude Code resets the item's **partition list** on *every* token rewrite — refresh included,
  not just login — dropping Claude Dials' `teamid` partition and forcing a fresh "Always Allow".
  The signature-based ACL grant is intact throughout (verified by dumping the ACL: `entry 0 …
  (OK)` survives; only the `partition_id` entry loses `teamid:TQ6Y49W7UW` while `apple-tool:`
  stays). Since v1.0.1 reads via `/usr/bin/security`, this no longer prompts. If prompts ever
  return, re-dump the ACL (`security dump-keychain -a ~/Library/Keychains/login.keychain-db`) and
  check whether `apple-tool:` is still in the partition list — that's the assumption the fix rests
  on.
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
| 2026-06-16 | Collapsed two accounts → one (the default Claude Code login). Removed AccountSetupService, TokenRefresher, ConnectAccountView, OnboardingView + all connect UI; name now resolves live from `~/.claude.json` instead of a frozen stored label; Keychain access is read-only (no more write prompts); old 2-account configs auto-collapse on launch. |
| 2026-06-22 | Stable-signing fix for the repeating Keychain prompt: added `build.sh` (re-signs with the Apple Development cert so "Always Allow" sticks across rebuilds); switched build command to `./build.sh`; documented the signing gotcha. Synced README/DESIGN to the single-account model (both still described two accounts). |
| 2026-07-03 | Fixed usage-endpoint schema drift: `seven_day_opus` is now always `null`, replaced by a dynamic `limits[]` array (currently scoping **Fable**, not Opus, on this account). Added `ModelWeeklyLimit`; `UsageClient`/`AccountSectionView` now render whatever model(s) the API actually scopes instead of a hardcoded Opus meter. Fixed a real bug: capsule ring color was session-only, ignoring `worstUtilization` — now correctly worst-window. Diagnosed the recurring Keychain prompt: the June 22 fix is confirmed working (one valid identity-based ACL grant + harmless dead entries from old ad-hoc builds); remaining prompts happen on `claude login` account switches (expected, outside Claude Dials' control) plus an occasional unreproduced "random" case still open. |
| 2026-07-03 | **Shipped v1.0.0 — first release.** Made the repo public (was private) so Sparkle's unauthenticated download works, matching every other Northwoods Sparkle app; security-reviewed clean beforehand (no secrets in repo). Built + ad-hoc signed a distribution copy (separate from the locally dev-cert-signed daily-use copy), created the `v1.0.0` GitHub release, signed the downloaded zip, and created `appcast-claudedials.xml` in `app-updates` (this app's first appcast). |
| 2026-07-03 | **Root-caused & fixed the recurring Keychain prompt.** Not a signing issue — Claude Code resets the credential item's *partition list* on every token refresh, dropping Claude Dials' `teamid` partition and forcing a fresh "Always Allow". `KeychainReader` now reads via `/usr/bin/security` (inherits the stable `apple-tool:` partition Claude Code preserves) instead of in-process `SecItemCopyMatching`. Verified silent read in the previously-prompting state. Corrected the CLAUDE.md gotchas that had blamed signing/account-switches. |
| 2026-07-03 | **Shipped v1.0.1 (build 2)** — the Keychain-prompt fix above, released via the normal Sparkle flow (bump → build → ad-hoc sign → GitHub release → sign downloaded zip → appcast). Sparkle signing key was read from the login Keychain (service `https://sparkle-project.org`, acct `ed25519`) via `/usr/bin/security` since the `~/.sparkle` export had been cleaned up after v1.0.0. |
