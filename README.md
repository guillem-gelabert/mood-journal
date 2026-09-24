# mood-journal

Native SwiftUI mood logger for iOS 18+. When a reminder is waiting, the app opens on a slider:
move it, tap Log, and a momentary-emotion sample lands in Apple Health. Any other time it opens
on today's moods and the time to the next reminder. Charts and settings live behind the gear.

## What it does

- **Log** — a valence slider (−1…1) writing `HKStateOfMind` momentary emotions with no labels
  or associations.
- **Reminders** — a custom list of daily prompts (defaults 09:00, 17:00, 20:00), each a
  repeating notification you can edit, disable or delete. Long-press one to log from the
  notification itself without opening the app.
- **Today** — what an unprompted open shows: the day's moods (or the last one if today is
  empty), the next reminder, and a Log now button. The slider comes up instead when opened from
  a reminder, or when a reminder fired in the last two hours and is still unanswered.
- **Lock screen widget** — the next reminder time with a countdown, "due" while a prompt is
  unanswered, and the last mood logged. It reads the app group, not Health, which is locked
  while the phone is; moods logged on the watch reach it the next time the phone app opens.
- **Charts** — mood over time with a rolling mean and standard-deviation band, mood by weekday,
  active energy, and sleep, over a range you pick (30D / 90D / 1Y / All).
- **Momentum and Resilience** — two adherence numbers over your reminder prompts.
- **Export** — the chart report as a two-page A4 PDF via the share sheet.
- **Apple Watch** — a companion app that logs and nothing else: Digital Crown for valence, one
  button to save, writing straight to Health on the watch.

## Adherence metrics

With `xᵢ = 1` if prompt *i* was answered and `0` if missed, at times `tᵢ`:

```
M(t) = Σ xᵢ · 2^(−(t − tᵢ)/H) / Σ 2^(−(t − tᵢ)/H)      H = 7 days
R    = Σ (1 − xᵢ) · xᵢ₊₁ / Σ (1 − xᵢ)
```

**Momentum** is a half-life weighted answer rate — recent prompts dominate. **Resilience** is a
bounce-back rate: of the missed prompts, the share whose next prompt was answered.

A prompt counts as answered if a sample falls in `[tᵢ, tᵢ + 2h)`. Prompts still inside that
window are not recorded at all, so this morning's unanswered 09:00 is not yet a miss. Neither
metric is scoped to the chart range.

Each number is coloured against its own past: green at least 5 points better, red at least 5
worse, yellow in between, with the comparison spelled out underneath.

- **Momentum** answers "am I being consistent by my own standards?". It is compared with its
  usual value, the mean of M sampled daily over all tracked history (needs 14 days), so a slow
  stretch never becomes the standard.
- **Resilience** answers "has my bouncing back improved?". The number shown is R over the last
  90 days, compared with R over everything before. R is roughly one over the typical run of
  misses: 50% means a lapse usually lasts two prompts.

## Setup

Signing identifiers are not in the repository. Before building:

```sh
cp Config/Signing.local.example.xcconfig Config/Signing.local.xcconfig
```

and put your own Apple Development team and bundle identifier in it. The file is gitignored;
`Config/Signing.xcconfig` reads it through an optional include, so the project still opens and
builds for the Simulator without it.

- Open `mood-journal.xcodeproj` in Xcode.
- The app and its two extensions share the app group `group.<bundle id>`. Automatic signing
  registers it on the first device build (`-allowProvisioningUpdates` from the command line).
- Enable **HealthKit** under **Signing & Capabilities** if it is not already on.
- A free personal team is enough, including for HealthKit. Provisioning expires after 7 days.
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

Write: State of Mind momentary emotions, from either the phone or the watch. The watch has its
own HealthKit store and asks only for write access; Health syncs the samples to the phone.

## Appearance

The palette is a fixed paper-and-ink light theme, and the app pins itself to light mode so the
screen and the exported PDF match. There is no dark theme.

## Project layout

```
Shared/                  Code every target uses: classification, palette, HealthKit writer,
                         log-entry state machine, slider, reminders, prompt schedule,
                         app-group storage
mood-journal/
  Models/                Value types: chart series, ranges, reminders, prompt records
  Services/              HealthKit reads, notifications, persistence, PDF rendering
  Stores/                @Observable @MainActor state: mood data, reminders
  Utilities/             Pure functions: analytics, adherence, interval merging
  Views/                 Screens, with Views/Charts/ holding the reusable chart views
mood-journal Watch App/  The watch app: one screen, Crown-driven
MoodNotification/        Notification content extension: the slider inside a reminder
MoodWidget/              Lock screen widget: next reminder and last mood
Tools/                   GenerateAppIcon.swift — run by hand, not a build phase
```

Sources are picked up through file-system-synchronized groups, so adding a file needs no
project edits. `Shared/` is a member of both app targets, which is why the classification
cutoffs exist once rather than twice.

The watch app is embedded in the iOS app, so it installs alongside it. That means **building
the iOS scheme requires a watchOS simulator runtime**, even for the tests:

```sh
xcodebuild -downloadPlatform watchOS
```

Without it the build fails with "watchOS N must be installed in order to run the scheme".

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
