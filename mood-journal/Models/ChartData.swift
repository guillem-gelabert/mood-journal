import Foundation

/// Every series the charts and the PDF report read, derived once per load.
///
/// These used to be computed properties on the view model, which meant each one
/// recomputed on every body evaluation of every chart.
struct ChartData: Equatable {
    var checkIns: [MoodCheckIn] = []
    var dailyEnergy: [DailyEnergy] = []
    var sleepNights: [SleepNight] = []
    var rollingMood: [RollingMoodPoint] = []
    var moodBands: [RollingMoodBand] = []
    var rollingEnergy: [DailyEnergy] = []
    var weekdaySamples: [WeekdayMoodSample] = []
    var weekdayStats: [WeekdayMoodStat] = []
    var monthStarts: [Date] = []
    var fifteenthDates: [Date] = []
    var windowStart: Date?
    var windowEnd: Date?

    static let empty = ChartData()

    var dateRangeSubtitle: String {
        guard let windowStart, let windowEnd else { return "No loaded data" }
        return "\(Self.dateFormatter.string(from: windowStart)) - \(Self.dateFormatter.string(from: windowEnd))"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
