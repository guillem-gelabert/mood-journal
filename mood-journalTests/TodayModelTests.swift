import XCTest
@testable import mood_journal

private struct StubHistory: MoodHistoryReading {
    var checkIns: [MoodCheckIn]

    func loadMoodCheckIns(from startDate: Date, to endDate: Date) async throws -> [MoodCheckIn] {
        checkIns.filter { $0.date >= startDate && $0.date <= endDate }
    }

    func latestMoodCheckIn(before date: Date) async throws -> MoodCheckIn? {
        checkIns.filter { $0.date <= date }.max { $0.date < $1.date }
    }
}

@MainActor
final class TodayModelTests: XCTestCase {
    private let reminders = [Reminder(hour: 9, minute: 0), Reminder(hour: 17, minute: 0)]

    func testUnpromptedOpenShowsTheSummary() async {
        let model = makeModel(now: "2026-03-10 12:00", checkIns: [checkIn("2026-03-10 09:20")])
        await model.refresh(reminders: reminders)

        XCTAssertEqual(model.screen, .summary)
        XCTAssertEqual(model.todaysLogs.count, 1)
        XCTAssertNil(model.lastLog)
        XCTAssertEqual(model.nextPrompt, Self.date("2026-03-10 17:00"))
    }

    func testAnEmptyDayFallsBackToTheLastLog() async {
        let model = makeModel(now: "2026-03-10 12:00", checkIns: [checkIn("2026-03-07 20:00")])
        await model.refresh(reminders: reminders)

        XCTAssertTrue(model.todaysLogs.isEmpty)
        XCTAssertEqual(model.lastLog?.date, Self.date("2026-03-07 20:00"))
    }

    func testAnUnansweredPromptOpensTheSlider() async {
        let model = makeModel(now: "2026-03-10 09:30", checkIns: [checkIn("2026-03-09 20:00")])
        await model.refresh(reminders: reminders)

        XCTAssertEqual(model.screen, .log)
    }

    func testAReminderTapOpensTheSliderEvenWhenAnswered() async {
        let model = makeModel(now: "2026-03-10 12:00", checkIns: [checkIn("2026-03-10 09:20")])
        model.openFromReminder()
        await model.refresh(reminders: reminders)

        XCTAssertEqual(model.screen, .log)
    }

    func testClosingTheSheetStaysOnTheSummaryUntilTheNextOpen() async {
        let model = makeModel(now: "2026-03-10 09:30", checkIns: [])
        await model.refresh(reminders: reminders)
        XCTAssertEqual(model.screen, .log)

        model.cancelLogging()
        XCTAssertEqual(model.screen, .summary)

        model.reset()
        await model.refresh(reminders: reminders)
        XCTAssertEqual(model.screen, .log)
    }

    func testLoggingReturnsToTheSummaryBeforeHealthCatchesUp() async {
        let loggedMoods = LoggedMoodStore(defaults: UserDefaults(suiteName: "TodayModelTests.\(UUID().uuidString)")!)
        let model = makeModel(now: "2026-03-10 09:30", checkIns: [], loggedMoods: loggedMoods)
        model.openFromReminder()

        // The save is recorded, but the Health read does not include it yet.
        loggedMoods.record(LoggedMood(date: Self.date("2026-03-10 09:29"), valence: 0.2))
        await model.didLog(reminders: reminders)

        XCTAssertEqual(model.screen, .summary)
    }

    func testAMoodDeletedInHealthLeavesTheWidget() async {
        let loggedMoods = LoggedMoodStore(defaults: UserDefaults(suiteName: "TodayModelTests.\(UUID().uuidString)")!)
        loggedMoods.record(LoggedMood(date: Self.date("2026-03-10 11:00"), valence: 0.9))
        let model = makeModel(now: "2026-03-10 12:00", checkIns: [checkIn("2026-03-10 09:20")], loggedMoods: loggedMoods)

        await model.refresh(reminders: reminders)

        XCTAssertEqual(loggedMoods.load()?.date, Self.date("2026-03-10 09:20"))
    }

    func testAnEmptyHealthClearsTheWidget() async {
        let loggedMoods = LoggedMoodStore(defaults: UserDefaults(suiteName: "TodayModelTests.\(UUID().uuidString)")!)
        loggedMoods.record(LoggedMood(date: Self.date("2026-03-10 11:00"), valence: 0.9))
        let model = makeModel(now: "2026-03-10 12:00", checkIns: [], loggedMoods: loggedMoods)

        await model.refresh(reminders: reminders)

        XCTAssertNil(loggedMoods.load())
    }

    private func makeModel(
        now: String,
        checkIns: [MoodCheckIn],
        loggedMoods: LoggedMoodStore = LoggedMoodStore(defaults: UserDefaults(suiteName: "TodayModelTests.\(UUID().uuidString)")!)
    ) -> TodayModel {
        let reference = Self.date(now)
        return TodayModel(
            service: StubHistory(checkIns: checkIns),
            loggedMoods: loggedMoods,
            calendar: Self.utc,
            now: { reference }
        )
    }

    private func checkIn(_ value: String) -> MoodCheckIn {
        MoodCheckIn(date: Self.date(value), valence: 0.3)
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)!
    }
}
