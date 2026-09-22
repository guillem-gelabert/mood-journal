# mood-journal

Native SwiftUI mood diary for iOS 18+. The app reads HealthKit on launch and whenever it becomes active, then shows chart-first mood, weekday, and active-energy views with a secondary diary table.

## HealthKit setup

- Open `mood-journal.xcodeproj` in Xcode.
- Select the app target, then enable **HealthKit** in **Signing & Capabilities** if Xcode does not show it automatically from the entitlement file.
- Set a signing team before running on a device. A free personal team works, but provisioning expires after 7 days.
- Real testing needs a physical device with Health data. The Simulator does not contain useful State of Mind or sleep samples.

## Data

The app requests read-only access to:

- State of Mind, using `HKObjectType.stateOfMindType()` and momentary emotion samples.
- Active Energy Burned, displayed in kJ.
- Sleep Analysis, summing current asleep states: core, deep, REM, and unspecified asleep.

Editable diary notes are stored locally with SwiftData. HealthKit prefill tags are merged into the note text and user edits are not overwritten on the next launch.

## Tests

The pure analytics functions have unit tests for rolling averages, rolling standard deviation, mood buckets, activity terciles, and time-of-day splitting.
