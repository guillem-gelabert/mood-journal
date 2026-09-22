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
    var interval: DateInterval?

    static let empty = ChartData()

    /// Every time-series chart shares this, so they stay vertically comparable and the PDF
    /// renders the same window the screen showed.
    var domain: ClosedRange<Date> {
        guard let interval else {
            let now = Date()
            return now...now.addingTimeInterval(1)
        }
        return interval.start...interval.end
    }

    var dayCount: Int {
        guard let interval else { return 0 }
        return Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
    }

    var dateRangeSubtitle: String {
        guard let interval else { return "No loaded data" }
        let lastDay = interval.end.addingTimeInterval(-1)
        return "\(Self.dateFormatter.string(from: interval.start)) - \(Self.dateFormatter.string(from: lastDay))"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
