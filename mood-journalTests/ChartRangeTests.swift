import XCTest
@testable import mood_journal

final class ChartRangeTests: XCTestCase {
    func testStartIsDayAlignedAndEndIsExclusiveTomorrow() {
        let now = Self.date("2026-03-15 14:37", in: Self.utc)
        let interval = ChartRange.days30.interval(now: now, earliestSample: nil, calendar: Self.utc)

        XCTAssertEqual(interval?.start, Self.date("2026-02-14 00:00", in: Self.utc))
        XCTAssertEqual(interval?.end, Self.date("2026-03-16 00:00", in: Self.utc))
    }

    func testLateEveningSampleTodayFallsInsideTheRange() {
        let now = Self.date("2026-03-15 14:37", in: Self.utc)
        let lateSample = Self.date("2026-03-15 23:30", in: Self.utc)
        let interval = ChartRange.days30.interval(now: now, earliestSample: nil, calendar: Self.utc)

        XCTAssertEqual(interval?.contains(lateSample), true)
    }

    func testAllStartsAtTheEarliestSampleDay() {
        let now = Self.date("2026-03-15 14:37", in: Self.utc)
        let earliest = Self.date("2024-07-09 16:20", in: Self.utc)
        let interval = ChartRange.all.interval(now: now, earliestSample: earliest, calendar: Self.utc)

        XCTAssertEqual(interval?.start, Self.date("2024-07-09 00:00", in: Self.utc))
    }

    func testAllWithNoDataHasNoInterval() {
        let now = Self.date("2026-03-15 14:37", in: Self.utc)
        XCTAssertNil(ChartRange.all.interval(now: now, earliestSample: nil, calendar: Self.utc))
    }

    /// 2026-03-29 is the European DST spring-forward, a 23-hour day. Calendar arithmetic
    /// must still land on midnight; 86_400-second arithmetic would drift an hour.
    func testRangeSurvivesADaylightSavingTransition() {
        let now = Self.date("2026-03-30 09:00", in: Self.zurich)
        let interval = ChartRange.days30.interval(now: now, earliestSample: nil, calendar: Self.zurich)

        let start = try? XCTUnwrap(interval?.start)
        XCTAssertEqual(Self.zurich.component(.hour, from: start ?? .distantPast), 0)
        XCTAssertEqual(interval?.start, Self.date("2026-03-01 00:00", in: Self.zurich))
        XCTAssertEqual(interval?.end, Self.date("2026-03-31 00:00", in: Self.zurich))
    }

    func testFetchIntervalWidensByTheRollingRadiusOnBothSides() {
        let now = Self.date("2026-03-15 14:37", in: Self.utc)
        let displayed = ChartRange.days30.interval(now: now, earliestSample: nil, calendar: Self.utc)
        let fetched = ChartRange.days30.fetchInterval(now: now, earliestSample: nil, calendar: Self.utc)

        // A centred rolling value at the range start needs the three days before it.
        XCTAssertEqual(fetched?.start, Self.date("2026-02-11 00:00", in: Self.utc))
        XCTAssertEqual(fetched?.end, Self.date("2026-03-19 00:00", in: Self.utc))
        XCTAssertLessThan(fetched?.start ?? .distantFuture, displayed?.start ?? .distantPast)
    }

    private static let utc = calendar(for: "GMT")
    private static let zurich = calendar(for: "Europe/Zurich")

    private static func calendar(for identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private static func date(_ value: String, in calendar: Calendar) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = calendar.timeZone
        return formatter.date(from: value)!
    }
}
