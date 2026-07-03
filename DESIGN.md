# Claude Dials — Design

Menu-bar utility showing live Claude session usage for two accounts as twin ring dials in a
dark capsule, with a broadcast-style detail popover. Companion-family app to Junk Drawer.

> ⚠️ **Superseded in part (2026-06-16):** the app collapsed from **two accounts → one** (the
> default Claude Code login). The **twin-ring** capsule is now a **single ring**, and the
> **onboarding / "Connect second account"** sections below describe removed functionality —
> read them as the original locked design, not current behavior. Everything else (aesthetic
> direction, palette, ring/meter treatment, degraded states) still holds. See
> [CLAUDE.md](CLAUDE.md) for the current single-account architecture.

---

## 1. Aesthetic direction (one sentence)

> **Industrial / Broadcast Cockpit** — a usage limit is a meter, and meters are control-room
> language: Claude Dials is a tally light for your Claude budget, living in the same menu bar
> family as Junk Drawer on production Macs.

## 2. The unforgettable thing (one sentence)

> **Twin rings in a black broadcast capsule** — two Claude accounts as side-by-side tally
> gauges in the menu bar, going green → amber → red like an on-air light.

## 3. Three reference apps as the bar

| App | Specific thing to learn |
|---|---|
| Logic Pro | Meters as the primary visual element; each account section composed like a channel strip with a full-bleed color-block header, label reversed out of the color |
| ATEM Software Control | Broadcast tally color discipline — green/amber/red mean exactly one thing each, everywhere, so one glance reads state without reading text |
| iStat Menus | Gauges that stay legible at 18 pt menu-bar scale; popover density achieved through hierarchy (big numeral → meter → caption), never clutter |

## 4. Visual system

### Type scale

| Role | Font + weight | Size | Notes |
|---|---|---|---|
| Dial numeral (session %) | Myriad Pro Black | 22 pt | `.monospacedDigit()`, status-colored |
| Account label / section header | Myriad Pro Black | 11 pt | ALL-CAPS, tracking 1.5–2.0, reversed out of color block |
| Tier badge (MAX 5×) | Myriad Pro Semibold | 9 pt | ALL-CAPS, 70 % white on color block |
| Body / messages | Myriad Pro Regular | 13 pt | |
| Countdown / timecode | Myriad Pro Semibold | 12 pt | `.monospacedDigit()` — reads like a broadcast clock |
| Caption / meta | Myriad Pro Regular | 10 pt | secondary foreground |
| About-pane tagline | RedRock Regular | — | "Hope lives here." About pane only |

Minion Pro intentionally absent from the main UI — serif isn't cockpit language. (May appear
in About credits.)

### Color usage rules

- **Dominant surface:** warm-black tiers derived from brand black `#2D2926` — window backdrop
  `#1B1815`, panel `#242019`, raised/capsule `#2D2926`, hairlines `rgba(255,255,255,0.08)`.
  Never pure `#000000`.
- **Status colors are exact brand accents mapped to broadcast convention:**
  green `#86AD3F` = healthy (< 60 %), gold `#F1BE48` = caution (60–85 %),
  coral `#FF6D6A` = near limit (> 85 %). Status colors are *never* decorative.
- **Light blue `#009CDE` = interactive only** (buttons, links, refresh). Never a status color.
- **Color block device (signature):** each account section opens with a full-bleed brand color
  strip — Pantone 2945 blue `#004C97` for account 1, dark navy `#002855` for account 2 —
  account name reversed out in white, Logic-track-header style.
- **The thing we NEVER do:** primary blue `#004C97` as text or fine lines on dark (fails
  WCAG AA); pure black surfaces; status colors for decoration.

### Spacing rhythm

`tight 4 / small 8 / medium 12 / large 16 / xlarge 24 / xxlarge 36` — `Theme.Space`, no raw literals.

### Motion personality

> **Snap** (broadcast). Ring value changes animate 0.18 s; error strips slide in 0.12 s;
> countdown ticks with no animation (clocks don't ease); nothing bounces.

### Iconography stance

- Rings, segment meters, capsule status icon: **custom-drawn** (Canvas / CoreGraphics), never SF Symbols
- Onboarding hero: **custom composed SVG illustration** (capsule motif) — `ContentUnavailableView` forbidden
- **Pointer symbol** (Northwoods brand device): marks the row that **resets next** across both accounts
- Northwoods location marker: About pane, from bundled brand assets
- SF Symbols: utility only (gear, refresh)

## 5. Surfaces — ASCII sketches

### Menu bar capsule (the hero)

```
.... ◧ 🔊 📶 🔋  ( ◔ᴾ ◕ᴺ )  Wed 9:41 AM
                ╰──────╯
        18 pt warm-black capsule, hairline border,
        two 13 pt rings w/ tiny account initial,
        ring fill = 5-hour session utilization,
        ring color = status (worst window wins)
```

States: filled ring (ok) · dimmed ring (stale data, last-known %) · hollow dashed ring
(disconnected / no credential) · hollow ring + dot (endpoint down).

### Popover — populated (primary view)

> The second meter row below is labeled "OPUS" in this original mockup, but the label is
> illustrative, not fixed — it renders whichever model Anthropic currently metes out its own
> scoped weekly cap for (verified 2026-07-03 to currently be Fable, not Opus). See CLAUDE.md
> "Conventions & gotchas" for the current field semantics.

```
┌──────────────────────────────────┐
│ CLAUDE DIALS            ⟳  12s   │  header, all-caps + refresh + age
│ ████████ PERSONAL · MAX 5× ██████│  color block #004C97
│  ╭───╮   SESSION                 │
│  │42%│   resets in 2:14:09       │  44pt ring + timecode countdown
│  ╰───╯                           │
│  WEEK  ▮▮▮▮▮▮▮▯▯▯▯▯  67%        │  segmented LED meters
│  OPUS  ▮▮▯▯▯▯▯▯▯▯▯▯  23%        │
│ ████████ NORTHWOODS · MAX 5× ████│  color block #002855
│ ▸╭───╮   SESSION                 │  ▸ = pointer device: resets next
│  │88%│   resets in 0:41:33       │  ring coral at 88%
│  ╰───╯                           │
│  WEEK  ▮▮▮▮▮▮▮▮▮▯▯▯  74%        │
│  OPUS  ▮▮▮▮▮▮▯▯▯▯▯▯  51%        │
│ ──────────────────────────────── │
│ Updated 12 s ago              ⚙  │  footer
└──────────────────────────────────┘
```

### Onboarding / empty state (the cover)

```
┌──────────────────────────────────┐
│        [capsule illustration]    │  custom SVG: one ring lit green,
│         ( ◉    ◌ )               │  one dashed + dark
│                                  │
│   One dial connected.            │  Myriad Black headline
│   Found your Max account from    │
│   Claude Code. Connect the       │
│   second account to light the    │
│   other dial.                    │
│                                  │
│   [ Connect second account… ]    │  light-blue capsule button
│   One-time login · about a min   │  caption
└──────────────────────────────────┘
```

### Degraded / error state

```
┌──────────────────────────────────┐
│ ████████ PERSONAL · MAX 5× ██████│
│  ╭───╮   SESSION  (dimmed ring)  │  stale: last-known % at 40% opacity
│  │42%│   last update 6 m ago     │
│  ╰───╯                           │
│ ████████ NORTHWOODS · MAX 5× ████│
│  ╭╌╌╌╮                           │  hollow dashed ring, no numeral
│  ┆ — ┆                           │
│  ╰╌╌╌╯                           │
│ ▓▓ ENDPOINT NOT RESPONDING ▓▓▓▓▓ │  gold strip, warm-black text,
│ ▓▓ retrying in 60 s        ▓▓▓▓▓ │  broadcast warning bar
└──────────────────────────────────┘
```

Token-expired uses the same pattern with a coral strip + `RECONNECT` action.

## 6. Custom components inventory

| Stock control | Replacement | Notes |
|---|---|---|
| Template `NSImage` status icon | `CapsuleStatusIcon` — CG-drawn warm-black capsule + twin progress rings | the app's silhouette; re-rendered on data change |
| `Gauge` / `ProgressView(.circular)` | `RingDial` (Canvas) | 270°-capable arc, status color, monospaced numeral center |
| `ProgressView(.linear)` | `SegmentMeter` | segmented LED-style bar (12 segments), broadcast meter language |
| Plain section header | `ColorBlockHeader` | full-bleed brand color strip, reversed-out label (signature device) |
| `ContentUnavailableView` | bespoke onboarding hero w/ composed SVG capsule illustration | forbidden on first impression |
| `.borderedProminent` button | `CapsuleButton` | light-blue fill, warm-black label, snap hover |
| `Form` settings | kept stock (utility surface) except account rows → custom | per skill: stock is fine when intentional |

## 7. Animation / motion specifics

| Surface | Trigger | Animation |
|---|---|---|
| Ring values (menu bar + popover) | data refresh | animate arc 0.18 s snap |
| Countdown timecode | every second | none — hard tick |
| Error / warning strip | appears | slide-in 0.12 s |
| Refresh glyph | manual refresh | single rotation, no easing tail |
| Onboarding hero | first appearance | staggered reveal: illustration → headline → button (0.1 s steps) |
| Status color change | threshold crossed | color crossfade 0.18 s (no flash — it's a meter, not an alarm) |

## 8. Implementation gates

- [ ] Myriad Pro (Regular/Semibold/Black) bundled + registered at launch (`CTFontManagerRegisterFontsForURL`)
- [ ] No hex literals in view code — all colors from `Theme.Brand` / `Theme.Surface` / `Theme.Status`
- [ ] No raw spacing literals — `Theme.Space.*`
- [ ] No `ContentUnavailableView` anywhere user-facing
- [ ] Onboarding capsule illustration bundled (composed SVG → asset)
- [ ] Northwoods location marker in About pane (bundled `-white` variant, not redrawn)
- [ ] Color block device on every account section header
- [ ] Pointer symbol used as the resets-next marker
- [ ] Aesthetic + unforgettable thing committed above

---

## Data notes that shape the design (not the data layer itself)

- Each account has exactly four designed states: **ok**, **stale** (dimmed last-known),
  **disconnected** (hollow dashed — no credential), **endpoint down** (hollow + warning strip).
  No state may fall through to a blank.
- Menu bar ring shows the **5-hour session** window; its color reflects the *worst* of
  session/week/opus so the capsule never under-reports. Popover shows all three.
- Data comes from an **unofficial** endpoint (the one Claude Code's own `/usage` uses); the
  degraded states above are first-class citizens, not afterthoughts, because breakage is an
  expected failure mode.
