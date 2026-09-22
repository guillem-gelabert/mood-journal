import Foundation

enum MoodAnalytics {
    static let rollingWindowRadiusInDays = 3

    /// Derives every chart series for `interval`.
    ///
    /// `snapshot` is expected to cover a wider window than `interval` (see
    /// `ChartRange.fetchInterval`): the centred rolling functions need data either side of the
    /// range start, so the series are computed over everything loaded and only then clipped.
    static func derive(
        snapshot: HealthSnapshot,
        interval: DateInterval?,
        calendar: Calendar = .current
    ) -> ChartData {
        guard let interval else { return .empty }

        func inRange(_ date: Date) -> Bool { date >= interval.start && date < interval.end }

        let checkIns = snapshot.moodCheckIns.filter { inRange($0.date) }
        let rangeDays = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0

        return ChartData(
            checkIns: checkIns,
            dailyEnergy: snapshot.dailyEnergy.filter { inRange($0.date) },
            sleepNights: snapshot.sleepNights.filter { inRange($0.date) },
            rollingMood: centeredRollingDailyMean(checkIns: snapshot.moodCheckIns, calendar: calendar)
                .filter { inRange($0.date) },
            moodBands: centeredRawStandardDeviationBand(checkIns: snapshot.moodCheckIns, calendar: calendar)
                .filter { inRange($0.date) },
            rollingEnergy: rollingEnergyAverage(values: snapshot.dailyEnergy, calendar: calendar)
                .filter { inRange($0.date) },
            weekdaySamples: weekdaySamples(checkIns: checkIns, calendar: calendar),
            weekdayStats: weekdayStats(
                checkIns: checkIns,
                endDate: interval.end,
                recentWindowDays: max(14, rangeDays / 4),
                calendar: calendar
            ),
            monthStarts: monthStarts(from: interval.start, through: interval.end, calendar: calendar),
            fifteenthDates: fifteenthOfMonths(from: interval.start, through: interval.end, calendar: calendar),
            interval: interval
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
        checkIns.map { sample in
            let weekday = mondayFirstWeekdayIndex(for: sample.date, calendar: calendar)
            let jitter = deterministicJitter(for: sample.id)
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
        recentWindowDays: Int = 14,
        calendar: Calendar = .current
    ) -> [WeekdayMoodStat] {
        let grouped = Dictionary(grouping: checkIns) { mondayFirstWeekdayIndex(for: $0.date, calendar: calendar) }
        let recentStart = calendar.date(byAdding: .day, value: -recentWindowDays, to: endDate) ?? endDate

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

    /// Keyed off the sample's identity, not its index: keying off array position made every
    /// point in the weekday scatter jump whenever the range changed the array's contents.
    /// Uses a UUID byte rather than hashValue, which is seeded per process and so unstable.
    private static func deterministicJitter(for id: UUID) -> Double {
        let sequence = [-0.26, 0.18, -0.08, 0.28, 0.04, -0.20, 0.12]
        return sequence[Int(id.uuid.0) % sequence.count]
    }
}
