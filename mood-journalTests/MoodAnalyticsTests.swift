import XCTest
@testable import mood_journal

final class MoodAnalyticsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testValenceToDiaryMoodBucket() {
        XCTAssertEqual(MoodAnalytics.diaryMoodBucket(for: 0.61), .veryGood)
        XCTAssertEqual(MoodAnalytics.diaryMoodBucket(for: 0.6), .good)
        XCTAssertEqual(MoodAnalytics.diaryMoodBucket(for: 0.2), .good)
        XCTAssertEqual(MoodAnalytics.diaryMoodBucket(for: -0.2), .normal)
        XCTAssertEqual(MoodAnalytics.diaryMoodBucket(for: -0.6), .bad)
        XCTAssertEqual(MoodAnalytics.diaryMoodBucket(for: -0.61), .veryBad)
    }

    func testTimeOfDaySplit() {
        XCTAssertEqual(MoodAnalytics.timeOfDaySlot(for: date("2026-01-10 00:00"), calendar: calendar), .morning)
        XCTAssertEqual(MoodAnalytics.timeOfDaySlot(for: date("2026-01-10 12:59"), calendar: calendar), .morning)
        XCTAssertEqual(MoodAnalytics.timeOfDaySlot(for: date("2026-01-10 13:00"), calendar: calendar), .midday)
        XCTAssertEqual(MoodAnalytics.timeOfDaySlot(for: date("2026-01-10 17:59"), calendar: calendar), .midday)
        XCTAssertEqual(MoodAnalytics.timeOfDaySlot(for: date("2026-01-10 18:00"), calendar: calendar), .evening)
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

    func testEnergyTercileBuckets() {
        let days = [
            DailyEnergy(date: date("2026-01-01 00:00"), kilojoules: 100),
            DailyEnergy(date: date("2026-01-02 00:00"), kilojoules: 200),
            DailyEnergy(date: date("2026-01-03 00:00"), kilojoules: 300),
            DailyEnergy(date: date("2026-01-04 00:00"), kilojoules: 400),
            DailyEnergy(date: date("2026-01-05 00:00"), kilojoules: 500)
        ]

        let buckets = MoodAnalytics.activityBuckets(for: days)

        XCTAssertEqual(buckets[days[0].date], .low)
        XCTAssertEqual(buckets[days[2].date], .normal)
        XCTAssertEqual(buckets[days[4].date], .high)
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
