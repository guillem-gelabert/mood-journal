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
    var rollingSleep: [SleepNight] = []
    var weekdaySamples: [WeekdayMoodSample] = []
    var weekdayStats: [WeekdayMoodStat] = []
    var monthStarts: [Date] = []
    var fifteenthDates: [Date] = []
    var interval: DateInterval?
    /// From the first mood entry in `interval` to its end. Nil when the range holds no
    /// mood entries.
    var dataInterval: DateInterval?

    static let empty = ChartData()

    /// Every time-series chart shares this, so they stay vertically comparable and the PDF
    /// renders the same window the screen showed.
    ///
    /// Starts at the first mood entry rather than the picked range: choosing 1Y with six
    /// months of history draws six months across the full width instead of half a chart and
    /// half a void. Always ends today.
    var domain: ClosedRange<Date> {
        guard let effective = dataInterval ?? interval else {
            let now = Date()
            return now...now.addingTimeInterval(1)
        }
        return effective.start...effective.end
    }

    var dayCount: Int {
        guard let effective = dataInterval ?? interval else { return 0 }
        return Calendar.current.dateComponents([.day], from: effective.start, to: effective.end).day ?? 0
    }

    var dateRangeSubtitle: String {
        guard let effective = dataInterval ?? interval else { return "No loaded data" }
        let lastDay = effective.end.addingTimeInterval(-1)
        return "\(Self.dateFormatter.string(from: effective.start)) - \(Self.dateFormatter.string(from: lastDay))"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
