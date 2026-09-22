import XCTest
@testable import mood_journal

final class ChartDataTests: XCTestCase {
    /// Picking 1Y with six months of history should draw six months across the full width,
    /// not half a chart and half a void.
    func testDomainFollowsTheDataRatherThanTheRange() {
        let interval = DateInterval(start: Self.date("2026-01-01 00:00"), end: Self.date("2027-01-01 00:00"))
        let checkIns = [
            MoodCheckIn(date: Self.date("2026-03-04 09:00"), valence: 0.2),
            MoodCheckIn(date: Self.date("2026-06-20 21:00"), valence: -0.4)
        ]

        let data = MoodAnalytics.derive(
            snapshot: HealthSnapshot(moodCheckIns: checkIns, dailyEnergy: [], sleepNights: []),
            interval: interval,
            calendar: Self.utc
        )

        XCTAssertEqual(data.domain.lowerBound, Self.date("2026-03-04 00:00"))
        XCTAssertEqual(data.domain.upperBound, Self.date("2026-06-21 00:00"))
        XCTAssertLessThan(data.domain.upperBound, interval.end)
    }

    func testDomainSpansEverySeriesNotJustMood() {
        let interval = DateInterval(start: Self.date("2026-01-01 00:00"), end: Self.date("2026-12-01 00:00"))
        let snapshot = HealthSnapshot(
            moodCheckIns: [MoodCheckIn(date: Self.date("2026-05-10 09:00"), valence: 0.1)],
            dailyEnergy: [DailyEnergy(date: Self.date("2026-02-02 00:00"), kilojoules: 1200)],
            sleepNights: [SleepNight(date: Self.date("2026-08-08 00:00"), hours: 7)]
        )

        let data = MoodAnalytics.derive(snapshot: snapshot, interval: interval, calendar: Self.utc)

        // Energy starts earliest and sleep ends latest; the charts share one extent so they
        // stay vertically comparable.
        XCTAssertEqual(data.domain.lowerBound, Self.date("2026-02-02 00:00"))
        XCTAssertEqual(data.domain.upperBound, Self.date("2026-08-09 00:00"))
    }

    func testDomainFallsBackToTheRangeWithNoData() {
        let interval = DateInterval(start: Self.date("2026-01-01 00:00"), end: Self.date("2026-02-01 00:00"))
        let data = MoodAnalytics.derive(
            snapshot: HealthSnapshot(moodCheckIns: [], dailyEnergy: [], sleepNights: []),
            interval: interval,
            calendar: Self.utc
        )

        XCTAssertNil(data.dataInterval)
        XCTAssertEqual(data.domain.lowerBound, interval.start)
        XCTAssertEqual(data.domain.upperBound, interval.end)
    }

    func testDataExtentNeverRunsPastTheRange() {
        let interval = DateInterval(start: Self.date("2026-03-01 00:00"), end: Self.date("2026-03-15 00:00"))
        // A sample on the final day would otherwise push the extent to the day after the range.
        let checkIns = [MoodCheckIn(date: Self.date("2026-03-14 23:30"), valence: 0.5)]

        let data = MoodAnalytics.derive(
            snapshot: HealthSnapshot(moodCheckIns: checkIns, dailyEnergy: [], sleepNights: []),
            interval: interval,
            calendar: Self.utc
        )

        XCTAssertEqual(data.domain.upperBound, interval.end)
    }

    func testDomainIsAlwaysNonEmpty() {
        let data = ChartData.empty
        XCTAssertLessThan(data.domain.lowerBound, data.domain.upperBound)
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
