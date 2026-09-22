# mood-journal

Native SwiftUI mood logger for iOS 18+. The app opens on a slider: move it, tap Log, and a
momentary-emotion sample lands in Apple Health. Charts and settings live behind the gear.

## What it does

- **Log** — a valence slider (−1…1) writing `HKStateOfMind` momentary emotions with no labels
  or associations.
- **Reminders** — a custom list of daily prompts (defaults 09:00, 17:00, 20:00), each a
  repeating notification you can edit, disable or delete.
- **Charts** — mood over time with a rolling mean and standard-deviation band, mood by weekday,
  active energy, and sleep, over a range you pick (30D / 90D / 1Y / All).
- **Momentum and Resilience** — two adherence numbers over your reminder prompts.
- **Export** — the chart report as a two-page A4 PDF via the share sheet.

## Adherence metrics

With `xᵢ = 1` if prompt *i* was answered and `0` if missed, at times `tᵢ`:

```
M(t) = Σ xᵢ · 2^(−(t − tᵢ)/H) / Σ 2^(−(t − tᵢ)/H)      H = 7 days
R    = Σ (1 − xᵢ) · xᵢ₊₁ / Σ (1 − xᵢ)
```

**Momentum** is a half-life weighted answer rate — recent prompts dominate. **Resilience** is a
bounce-back rate: of all missed prompts, the share whose next prompt was answered.

A prompt counts as answered if a sample falls in `[tᵢ, tᵢ + 2h)`. Prompts still inside that
window are not recorded at all, so this morning's unanswered 09:00 is not yet a miss. Both
metrics are absolute, not scoped to the chart range.

HealthKit stores logs, not prompts, so `PromptLedger` reconstructs the prompt series from the
reminder schedule and the clock — it cannot be driven by notification taps, since the app runs
no code when a notification merely fires. On first run it backfills the earlier period and
marks those records as estimates, which the UI states.

## Setup

- Open `mood-journal.xcodeproj` in Xcode.
- Enable **HealthKit** under **Signing & Capabilities** if it is not already on.
- Set a signing team. A free personal team works; provisioning expires after 7 days.
- Real testing needs a physical device. The Simulator has no useful State of Mind or sleep data.

### Time Sensitive notifications

Reminders set `interruptionLevel = .timeSensitive`. Without the
`com.apple.developer.usernotifications.time-sensitive` entitlement the system silently delivers
them at normal priority instead — they still arrive, they just do not break through Focus or
Notification Summary. The reminders screen says so when that is the case. On a paid account, add
the capability in **Signing & Capabilities**; no code change is needed.

## Health data

Read: State of Mind (momentary emotions), Active Energy Burned (kJ), Sleep Analysis (asleep
states, attributed to the wake-up day, with overlapping samples from multiple sources counted
once).

Write: State of Mind momentary emotions.

## Appearance

The palette is a fixed paper-and-ink light theme, and the app pins itself to light mode so the
screen and the exported PDF match. There is no dark theme.

## Project layout

```
Models/      Value types: chart series, ranges, reminders, prompt records
Services/    HealthKit, notifications, persistence, PDF rendering (all protocol-backed)
Stores/      @Observable @MainActor state: mood data, log entry, reminders
Utilities/   Pure functions: analytics, adherence, interval merging
Views/       Screens, with Views/Charts/ holding the reusable chart views
Tools/       GenerateAppIcon.swift — run by hand, not a build phase
```

Sources are picked up through file-system-synchronized groups, so adding a file needs no
project edits.

## Tests

```
xcodebuild -project mood-journal.xcodeproj -scheme mood-journal \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build test
```

XCTest, covering the pure analytics (rolling means, population SD, adherence formulas, interval
merging), range resolution including DST, the prompt ledger, reminder scheduling and seeding,
the data store's re-entrancy and error handling, and PDF page geometry.

## App icon

`swift Tools/GenerateAppIcon.swift` redraws `AppIcon-1024.png` from Core Graphics paths. It is
run by hand rather than as a build phase: `ENABLE_USER_SCRIPT_SANDBOXING` is on, so a build
script writing into the source tree would fail. The output is opaque sRGB with no alpha channel.
