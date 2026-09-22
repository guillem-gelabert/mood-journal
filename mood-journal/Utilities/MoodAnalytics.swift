import Foundation

enum MoodAnalytics {
    static let rollingWindowRadiusInDays = 3

    static func derive(snapshot: HealthSnapshot, calendar: Calendar = .current) -> ChartData {
        let dates = snapshot.moodCheckIns.map(\.date)
            + snapshot.dailyEnergy.map(\.date)
            + snapshot.sleepNights.map(\.date)
        let windowStart = dates.min().map { calendar.startOfDay(for: $0) }
        let windowEnd = dates.max().map { calendar.startOfDay(for: $0) }

        return ChartData(
            checkIns: snapshot.moodCheckIns,
            dailyEnergy: snapshot.dailyEnergy,
            sleepNights: snapshot.sleepNights,
            rollingMood: centeredRollingDailyMean(checkIns: snapshot.moodCheckIns, calendar: calendar),
            moodBands: centeredRawStandardDeviationBand(checkIns: snapshot.moodCheckIns, calendar: calendar),
            rollingEnergy: rollingEnergyAverage(values: snapshot.dailyEnergy, calendar: calendar),
            weekdaySamples: weekdaySamples(checkIns: snapshot.moodCheckIns, calendar: calendar),
            weekdayStats: weekdayStats(
                checkIns: snapshot.moodCheckIns,
                endDate: windowEnd ?? Date(),
                calendar: calendar
            ),
            monthStarts: windowStart.flatMap { start in
                windowEnd.map { monthStarts(from: start, through: $0, calendar: calendar) }
            } ?? [],
            fifteenthDates: windowStart.flatMap { start in
                windowEnd.map { fifteenthOfMonths(from: start, through: $0, calendar: calendar) }
            } ?? [],
            windowStart: windowStart,
            windowEnd: windowEnd
        )
    }

    static func chartClassification(for valence: Double) -> MoodChartClassification {
        if valence > 0.6 { return .veryPleasant }
        if valence >= 0.3 { return .pleasant }
        if valence >= 0.1 { return .slightlyPleasant }
        if valence >= -0.1 { return .neutral }
        if valence >= -0.3 { return .slightlyUnpleasant }
        if valence >= -0.6 { return .unpleasant }
        return .veryUnpleasant
    }

    static func dailyMeans(for checkIns: [MoodCheckIn], calendar: Calendar = .current) -> [Date: Double] {
        let grouped = Dictionary(grouping: checkIns) { calendar.startOfDay(for: $0.date) }
        return grouped.mapValues { samples in
            samples.map(\.valence).reduce(0, +) / Double(samples.count)
        }
    }

    static func centeredRollingDailyMean(
        checkIns: [MoodCheckIn],
        calendar: Calendar = .current,
        radiusInDays: Int = rollingWindowRadiusInDays
    ) -> [RollingMoodPoint] {
        let means = dailyMeans(for: checkIns, calendar: calendar)
        return means.keys.sorted().compactMap { day in
            let windowDays = datesAround(day, radiusInDays: radiusInDays, calendar: calendar)
            let values = windowDays.compactMap { means[$0] }
            guard !values.isEmpty else { return nil }
            return RollingMoodPoint(date: day, mean: values.reduce(0, +) / Double(values.count))
        }
    }

    static func centeredRawStandardDeviationBand(
        checkIns: [MoodCheckIn],
        calendar: Calendar = .current,
        radiusInDays: Int = rollingWindowRadiusInDays
    ) -> [RollingMoodBand] {
        let centerDays = dailyMeans(for: checkIns, calendar: calendar).keys.sorted()
        return centerDays.compactMap { day in
            guard
                let start = calendar.date(byAdding: .day, value: -radiusInDays, to: day),
                let inclusiveEnd = calendar.date(byAdding: .day, value: radiusInDays + 1, to: day)
            else {
                return nil
            }

            let values = checkIns
                .filter { $0.date >= start && $0.date < inclusiveEnd }
                .map(\.valence)
            guard !values.isEmpty else { return nil }

            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
            return RollingMoodBand(date: day, mean: mean, standardDeviation: sqrt(variance))
        }
    }

    static func rollingEnergyAverage(
        values: [DailyEnergy],
        calendar: Calendar = .current,
        radiusInDays: Int = rollingWindowRadiusInDays
    ) -> [DailyEnergy] {
        let byDay = Dictionary(uniqueKeysWithValues: values.map { (calendar.startOfDay(for: $0.date), $0.kilojoules) })
        return byDay.keys.sorted().compactMap { day in
            let windowDays = datesAround(day, radiusInDays: radiusInDays, calendar: calendar)
            let windowValues = windowDays.compactMap { byDay[$0] }
            guard !windowValues.isEmpty else { return nil }
            return DailyEnergy(date: day, kilojoules: windowValues.reduce(0, +) / Double(windowValues.count))
        }
    }

    static func weekdaySamples(checkIns: [MoodCheckIn], calendar: Calendar = .current) -> [WeekdayMoodSample] {
        checkIns.enumerated().map { index, sample in
            let weekday = mondayFirstWeekdayIndex(for: sample.date, calendar: calendar)
            let jitter = deterministicJitter(index: index)
            return WeekdayMoodSample(
                id: sample.id,
                weekdayIndex: weekday,
                jitteredX: Double(weekday) + jitter,
                valence: sample.valence
            )
        }
    }

    static func weekdayStats(
        checkIns: [MoodCheckIn],
        endDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [WeekdayMoodStat] {
        let grouped = Dictionary(grouping: checkIns) { mondayFirstWeekdayIndex(for: $0.date, calendar: calendar) }
        let recentStart = calendar.date(byAdding: .day, value: -14, to: endDate) ?? endDate

        return (1...7).compactMap { weekday in
            guard let samples = grouped[weekday], !samples.isEmpty else { return nil }
            let overall = samples.map(\.valence).reduce(0, +) / Double(samples.count)
            let recent = samples.filter { $0.date >= recentStart }
            let recentMean = recent.isEmpty ? nil : recent.map(\.valence).reduce(0, +) / Double(recent.count)
            return WeekdayMoodStat(weekdayIndex: weekday, overallMean: overall, recentMean: recentMean)
        }
    }

    static func monthStarts(from startDate: Date, through endDate: Date, calendar: Calendar = .current) -> [Date] {
        var components = calendar.dateComponents([.year, .month], from: startDate)
        components.day = 1
        guard var cursor = calendar.date(from: components) else { return [] }

        var result: [Date] = []
        while cursor <= endDate {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    static func fifteenthOfMonths(from startDate: Date, through endDate: Date, calendar: Calendar = .current) -> [Date] {
        monthStarts(from: startDate, through: endDate, calendar: calendar).compactMap {
            calendar.date(byAdding: .day, value: 14, to: $0)
        }
        .filter { $0 >= startDate && $0 <= endDate }
    }

    static func mondayFirstWeekdayIndex(for date: Date, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    static func weekdayName(for index: Int) -> String {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][max(1, min(7, index)) - 1]
    }

    private static func datesAround(_ day: Date, radiusInDays: Int, calendar: Calendar) -> [Date] {
        (-radiusInDays...radiusInDays).compactMap {
            calendar.date(byAdding: .day, value: $0, to: day).map { calendar.startOfDay(for: $0) }
        }
    }

    private static func deterministicJitter(index: Int) -> Double {
        let sequence = [-0.26, 0.18, -0.08, 0.28, 0.04, -0.20, 0.12]
        return sequence[index % sequence.count]
    }
}
