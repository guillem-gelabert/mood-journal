import XCTest
@testable import mood_journal

final class PromptScheduleTests: XCTestCase {
    private let reminders = [Reminder(hour: 9, minute: 0), Reminder(hour: 17, minute: 0)]

    func testNextPromptIsLaterTodayOrTomorrowMorning() {
        XCTAssertEqual(
            PromptSchedule.nextPrompt(after: Self.date("2026-03-10 12:00"), reminders: reminders, calendar: Self.utc),
            Self.date("2026-03-10 17:00")
        )
        XCTAssertEqual(
            PromptSchedule.nextPrompt(after: Self.date("2026-03-10 18:00"), reminders: reminders, calendar: Self.utc),
            Self.date("2026-03-11 09:00")
        )
    }

    func testDisabledRemindersAreIgnored() {
        let reminders = [Reminder(hour: 9, minute: 0, isEnabled: false)]
        XCTAssertNil(PromptSchedule.nextPrompt(after: Self.date("2026-03-10 08:00"), reminders: reminders, calendar: Self.utc))
    }

    func testPromptIsPendingUntilAnsweredOrItsWindowCloses() {
        let now = Self.date("2026-03-10 09:30")

        XCTAssertEqual(
            PromptSchedule.pendingPrompt(now: now, reminders: reminders, lastLog: Self.date("2026-03-09 20:00"), calendar: Self.utc),
            Self.date("2026-03-10 09:00")
        )
        XCTAssertNil(
            PromptSchedule.pendingPrompt(now: now, reminders: reminders, lastLog: Self.date("2026-03-10 09:10"), calendar: Self.utc)
        )
        XCTAssertNil(
            PromptSchedule.pendingPrompt(now: Self.date("2026-03-10 11:00"), reminders: reminders, lastLog: nil, calendar: Self.utc)
        )
    }

    func testLastNightsPromptCanStillBePendingAfterMidnight() {
        let reminders = [Reminder(hour: 23, minute: 30)]
        XCTAssertEqual(
            PromptSchedule.pendingPrompt(now: Self.date("2026-03-11 00:15"), reminders: reminders, lastLog: nil, calendar: Self.utc),
            Self.date("2026-03-10 23:30")
        )
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
