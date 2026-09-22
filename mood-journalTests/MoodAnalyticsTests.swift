import XCTest
@testable import mood_journal

final class MoodAnalyticsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testCenteredRollingAverageUsesDailyMeans() {
        let samples = [
            MoodCheckIn(date: date("2026-01-01 09:00"), valence: 1.0),
            MoodCheckIn(date: date("2026-01-01 10:00"), valence: -1.0),
            MoodCheckIn(date: date("2026-01-02 09:00"), valence: 0.6),
            MoodCheckIn(date: date("2026-01-03 09:00"), valence: 0.3)
        ]

        let rolling = MoodAnalytics.centeredRollingDailyMean(checkIns: samples, calendar: calendar, radiusInDays: 1)
        let jan2 = calendar.startOfDay(for: date("2026-01-02 09:00"))
        let point = rolling.first { $0.date == jan2 }

        XCTAssertEqual(point?.mean ?? .nan, 0.3, accuracy: 0.0001)
    }

    func testCenteredRawStandardDeviationUsesRawCheckIns() {
        let samples = [
            MoodCheckIn(date: date("2026-01-01 09:00"), valence: -1.0),
            MoodCheckIn(date: date("2026-01-02 09:00"), valence: 0.0),
            MoodCheckIn(date: date("2026-01-03 09:00"), valence: 1.0)
        ]

        let bands = MoodAnalytics.centeredRawStandardDeviationBand(checkIns: samples, calendar: calendar, radiusInDays: 1)
        let jan2 = calendar.startOfDay(for: date("2026-01-02 09:00"))
        let band = bands.first { $0.date == jan2 }

        XCTAssertEqual(band?.mean ?? .nan, 0.0, accuracy: 0.0001)
        XCTAssertEqual(band?.standardDeviation ?? .nan, sqrt(2.0 / 3.0), accuracy: 0.0001)
    }

    private func date(_ value: String) -> Date {
        Self.formatter.date(from: value)!
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
