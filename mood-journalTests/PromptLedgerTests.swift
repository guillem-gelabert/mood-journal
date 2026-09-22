import XCTest
@testable import mood_journal

final class PromptLedgerTests: XCTestCase {
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testCompletionUsesAHalfOpenWindow() {
        let scheduled = Self.date("2026-03-10 09:00")
        let onTime = MoodCheckIn(date: Self.date("2026-03-10 09:30"), valence: 0.2)
        let exactlyAtTheEdge = MoodCheckIn(date: scheduled.addingTimeInterval(PromptLedger.completionWindow), valence: 0.2)
        let tooEarly = MoodCheckIn(date: Self.date("2026-03-10 08:59"), valence: 0.2)

        XCTAssertTrue(PromptLedger.isCompleted(promptAt: scheduled, checkIns: [onTime]))
        XCTAssertFalse(PromptLedger.isCompleted(promptAt: scheduled, checkIns: [exactlyAtTheEdge]))
        XCTAssertFalse(PromptLedger.isCompleted(promptAt: scheduled, checkIns: [tooEarly]))
        XCTAssertFalse(PromptLedger.isCompleted(promptAt: scheduled, checkIns: []))
    }

    func testMaterialiseRecordsOnePromptPerScheduledTime() {
        var state = PromptLedgerState(records: [], materialisedThrough: Self.date("2026-03-09 00:00"), didBackfill: true)
        let reminders = [Reminder(hour: 9, minute: 0), Reminder(hour: 20, minute: 0)]

        state = PromptLedger.materialise(
            state: state,
            reminders: reminders,
            checkIns: [],
            now: Self.date("2026-03-11 23:00"),
            calendar: Self.utc
        )

        // Two prompts a day across 9 Mar (after the cursor), 10 Mar and 11 Mar.
        XCTAssertEqual(state.records.count, 6)
        XCTAssertTrue(state.records.allSatisfy { !$0.isCompleted })
    }

    func testPromptStillInsideItsWindowIsNotRecorded() {
        var state = PromptLedgerState(records: [], materialisedThrough: Self.date("2026-03-10 00:00"), didBackfill: true)

        state = PromptLedger.materialise(
            state: state,
            reminders: [Reminder(hour: 9, minute: 0)],
            checkIns: [],
            now: Self.date("2026-03-10 10:00"),
            calendar: Self.utc
        )

        XCTAssertTrue(state.records.isEmpty, "09:00 is still answerable at 10:00, so it is not yet a miss")
    }

    func testDuplicateScheduledTimesAreDeduplicated() {
        var state = PromptLedgerState(records: [], materialisedThrough: Self.date("2026-03-10 00:00"), didBackfill: true)

        state = PromptLedger.materialise(
            state: state,
            reminders: [Reminder(hour: 9, minute: 0), Reminder(hour: 9, minute: 0)],
            checkIns: [],
            now: Self.date("2026-03-10 23:00"),
            calendar: Self.utc
        )

        XCTAssertEqual(state.records.count, 1, "one log must not be able to complete two identical prompts")
    }

    func testMaterialiseIsIdempotent() {
        var state = PromptLedgerState(records: [], materialisedThrough: Self.date("2026-03-09 00:00"), didBackfill: true)
        let now = Self.date("2026-03-11 23:00")
        let reminders = [Reminder(hour: 9, minute: 0)]

        state = PromptLedger.materialise(state: state, reminders: reminders, checkIns: [], now: now, calendar: Self.utc)
        let afterFirst = state.records.count
        state = PromptLedger.materialise(state: state, reminders: reminders, checkIns: [], now: now, calendar: Self.utc)

        XCTAssertEqual(state.records.count, afterFirst)
    }

    func testCompletedPromptsAreMarked() {
        var state = PromptLedgerState(records: [], materialisedThrough: Self.date("2026-03-10 00:00"), didBackfill: true)
        let answered = MoodCheckIn(date: Self.date("2026-03-10 09:20"), valence: 0.5)

        state = PromptLedger.materialise(
            state: state,
            reminders: [Reminder(hour: 9, minute: 0), Reminder(hour: 20, minute: 0)],
            checkIns: [answered],
            now: Self.date("2026-03-10 23:00"),
            calendar: Self.utc
        )

        XCTAssertEqual(state.records.filter(\.isCompleted).count, 1)
        XCTAssertEqual(state.records.count, 2)
    }

    // MARK: - Backfill

    func testBackfillMarksEverythingAsEstimatedAndRunsOnce() {
        let checkIns = [MoodCheckIn(date: Self.date("2026-03-08 09:10"), valence: 0.3)]
        var state = PromptLedger.backfill(
            state: PromptLedgerState(),
            reminders: [Reminder(hour: 9, minute: 0)],
            checkIns: checkIns,
            now: Self.date("2026-03-10 23:00"),
            calendar: Self.utc
        )

        XCTAssertTrue(state.didBackfill)
        XCTAssertFalse(state.records.isEmpty)
        XCTAssertTrue(state.records.allSatisfy(\.isEstimated))
        XCTAssertEqual(state.records.filter(\.isCompleted).count, 1)

        let countAfterFirst = state.records.count
        state = PromptLedger.backfill(
            state: state,
            reminders: [Reminder(hour: 9, minute: 0)],
            checkIns: checkIns,
            now: Self.date("2026-03-11 23:00"),
            calendar: Self.utc
        )
        XCTAssertEqual(state.records.count, countAfterFirst, "backfill is one-time")
    }

    func testBackfillWithNoRemindersInfersPromptsPerDayFromLogging() {
        // 28 logs over the trailing fortnight is two a day.
        let checkIns = (0..<28).map { index in
            MoodCheckIn(
                date: Self.date("2026-03-10 12:00").addingTimeInterval(-Double(index) * 12 * 3600),
                valence: 0.1
            )
        }

        let perDay = PromptLedger.inferredPromptsPerDay(
            checkIns: checkIns,
            now: Self.date("2026-03-10 23:00"),
            calendar: Self.utc
        )
        XCTAssertEqual(perDay, 2)

        let state = PromptLedger.backfill(
            state: PromptLedgerState(),
            reminders: [],
            checkIns: checkIns,
            now: Self.date("2026-03-10 23:00"),
            calendar: Self.utc
        )
        XCTAssertFalse(state.records.isEmpty)
        XCTAssertTrue(state.records.allSatisfy(\.isEstimated))
    }

    func testInferredPromptsPerDayIsAtLeastOne() {
        XCTAssertEqual(
            PromptLedger.inferredPromptsPerDay(checkIns: [], now: Self.date("2026-03-10 23:00"), calendar: Self.utc),
            1
        )
    }

    func testBackfillWithNoDataRecordsNothing() {
        let state = PromptLedger.backfill(
            state: PromptLedgerState(),
            reminders: [Reminder(hour: 9, minute: 0)],
            checkIns: [],
            now: Self.date("2026-03-10 23:00"),
            calendar: Self.utc
        )

        XCTAssertTrue(state.records.isEmpty)
        XCTAssertTrue(state.didBackfill)
        XCTAssertNotNil(state.materialisedThrough)
    }

    private static func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)!
    }
}
