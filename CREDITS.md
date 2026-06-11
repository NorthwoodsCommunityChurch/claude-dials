# Credits

## Frameworks & Libraries

| Name | Description | License |
|------|-------------|---------|
| [Sparkle](https://sparkle-project.org/) | Software update framework for macOS | [MIT](https://github.com/sparkle-project/Sparkle/blob/2.x/LICENSE) |

Everything else is Apple system frameworks (AppKit, SwiftUI, Combine, CryptoKit, Security).

## Fonts

| Name | Use | Source |
|------|-----|--------|
| Myriad Pro (Regular / Semibold / Black) | All UI text | Northwoods brand kit (`NorthwoodsCommunityChurch/northwoods-brand`) |

## Icons & Assets

- App icon and the menu-bar capsule are custom-drawn (CoreGraphics / SVG) for this project.
- Northwoods location-marker symbol (About pane): from the Northwoods brand kit.
- Utility glyphs (gear, refresh, etc.): Apple SF Symbols.

## Tools

| Tool | Purpose |
|------|---------|
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | Generates the Xcode project from `project.yml` |

## Data Source

Claude Dials reads the same per-account usage data that Claude Code's `/usage`
screen shows: the OAuth credential Claude Code stores in the macOS Keychain, and
the `GET /api/oauth/usage` endpoint. **This endpoint is unofficial and
undocumented** — it is the internal interface Claude Code uses, reverse-engineered
by the community, and Anthropic may change or remove it without notice. Claude
Dials treats every failure (auth, rate-limit, schema change) as an expected
degraded state. No tokens are stored by this app or sent anywhere except to
`api.anthropic.com`.

## Inspiration

Prior art surveyed while designing the data layer (all MIT-licensed): ClaudeBar,
CodexBar, Claude-God, Claude-Usage-Tracker, claude-monitor — community menu-bar
usage monitors that read the same Keychain credential and endpoint.
