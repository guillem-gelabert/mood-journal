import Foundation

@MainActor
final class MoodJournalViewModel: ObservableObject {
    static let historyWindowDays = 200

    @Published var checkIns: [MoodCheckIn] = []
    @Published var dailyEnergy: [DailyEnergy] = []
    @Published var sleepNights: [SleepNight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: HealthKitService
    private let calendar: Calendar

    init(service: HealthKitService = HealthKitService(), calendar: Calendar = .current) {
        self.service = service
        self.calendar = calendar
    }

    var dateRangeSubtitle: String {
        guard let start = windowStartDate(), let end = windowEndDate() else {
            return "No loaded data"
        }
        return "\(Self.dateFormatter.string(from: start)) - \(Self.dateFormatter.string(from: end))"
    }

    var diaryDays: [DiaryDay] {
        let end = windowEndDate() ?? Date()
        let start = windowStartDate() ?? calendar.date(byAdding: .day, value: -Self.historyWindowDays, to: end) ?? end
        return MoodAnalytics.diaryDays(
            checkIns: checkIns,
            sleep: sleepNights,
            energy: dailyEnergy,
            startDate: start,
            endDate: end,
            calendar: calendar
        )
    }

    var rollingMood: [RollingMoodPoint] {
        MoodAnalytics.centeredRollingDailyMean(checkIns: checkIns, calendar: calendar)
    }

    var moodBands: [RollingMoodBand] {
        MoodAnalytics.centeredRawStandardDeviationBand(checkIns: checkIns, calendar: calendar)
    }

    var rollingEnergy: [DailyEnergy] {
        MoodAnalytics.rollingEnergyAverage(values: dailyEnergy, calendar: calendar)
    }

    var weekdaySamples: [WeekdayMoodSample] {
        MoodAnalytics.weekdaySamples(checkIns: checkIns, calendar: calendar)
    }

    var weekdayStats: [WeekdayMoodStat] {
        MoodAnalytics.weekdayStats(checkIns: checkIns, endDate: windowEndDate() ?? Date(), calendar: calendar)
    }

    var monthStarts: [Date] {
        guard let start = windowStartDate(), let end = windowEndDate() else { return [] }
        return MoodAnalytics.monthStarts(from: start, through: end, calendar: calendar)
    }

    var fifteenthDates: [Date] {
        guard let start = windowStartDate(), let end = windowEndDate() else { return [] }
        return MoodAnalytics.fifteenthOfMonths(from: start, through: end, calendar: calendar)
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await service.requestAuthorization()
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -Self.historyWindowDays, to: endDate) ?? endDate
            let snapshot = try await service.loadSnapshot(from: startDate, to: endDate, calendar: calendar)
            checkIns = snapshot.moodCheckIns
            dailyEnergy = snapshot.dailyEnergy
            sleepNights = snapshot.sleepNights
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func windowStartDate() -> Date? {
        let dates = checkIns.map(\.date) + dailyEnergy.map(\.date) + sleepNights.map(\.date)
        return dates.min().map { calendar.startOfDay(for: $0) }
    }

    private func windowEndDate() -> Date? {
        let dates = checkIns.map(\.date) + dailyEnergy.map(\.date) + sleepNights.map(\.date)
        return dates.max().map { calendar.startOfDay(for: $0) }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
