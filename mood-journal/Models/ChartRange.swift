import Foundation

enum ChartRange: String, CaseIterable, Identifiable, Codable {
    case days30
    case days90
    case year1
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .days30: "30D"
        case .days90: "90D"
        case .year1: "1Y"
        case .all: "All"
        }
    }

    /// The displayed window. `end` is exclusive tomorrow-midnight so a sample logged late
    /// tonight falls inside today. All arithmetic goes through `Calendar`, never 86_400,
    /// so a DST day still counts as one day.
    ///
    /// Returns nil only for `.all` with no data at all, which the UI renders as an empty state.
    func interval(now: Date, earliestSample: Date?, calendar: Calendar) -> DateInterval? {
        guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return nil
        }

        let start: Date?
        switch self {
        case .days30: start = calendar.date(byAdding: .day, value: -30, to: end)
        case .days90: start = calendar.date(byAdding: .day, value: -90, to: end)
        case .year1: start = calendar.date(byAdding: .year, value: -1, to: end)
        case .all: start = earliestSample.map { calendar.startOfDay(for: $0) }
        }

        guard let start, start < end else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// The window to fetch, widened by the rolling radius on both sides. A centred rolling
    /// value at the range start needs data from before it; without this the left edge of
    /// every chart is quietly wrong.
    func fetchInterval(
        now: Date,
        earliestSample: Date?,
        calendar: Calendar,
        radiusInDays: Int = MoodAnalytics.rollingWindowRadiusInDays
    ) -> DateInterval? {
        guard let displayed = interval(now: now, earliestSample: earliestSample, calendar: calendar),
              let start = calendar.date(byAdding: .day, value: -radiusInDays, to: displayed.start),
              let end = calendar.date(byAdding: .day, value: radiusInDays, to: displayed.end)
        else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }
}
