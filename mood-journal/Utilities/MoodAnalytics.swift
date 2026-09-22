import Foundation

enum MoodAnalytics {
    static let rollingWindowRadiusInDays = 3

    static func diaryMoodBucket(for valence: Double) -> DiaryMoodBucket {
        if valence > 0.6 { return .veryGood }
        if valence >= 0.2 { return .good }
        if valence >= -0.2 { return .normal }
        if valence >= -0.6 { return .bad }
        return .veryBad
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

    static func timeOfDaySlot(
        for date: Date,
        calendar: Calendar = .current,
        boundaries: DiaryTimeBoundaries = .standard
    ) -> TimeOfDaySlot {
        let hour = calendar.component(.hour, from: date)
        if hour < boundaries.morningEndHour { return .morning }
        if hour < boundaries.middayEndHour { return .midday }
        return .evening
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

    static func activityBuckets(for energy: [DailyEnergy]) -> [Date: ActivityBucket] {
        let values = energy.map(\.kilojoules).sorted()
        guard !values.isEmpty else { return [:] }

        let lowCutoff = percentile(values, percentile: 1.0 / 3.0)
        let highCutoff = percentile(values, percentile: 2.0 / 3.0)

        return Dictionary(uniqueKeysWithValues: energy.map { item in
            let bucket: ActivityBucket
            if item.kilojoules < lowCutoff {
                bucket = .low
            } else if item.kilojoules > highCutoff {
                bucket = .high
            } else {
                bucket = .normal
            }
            return (item.date, bucket)
        })
    }

    static func diaryDays(
        checkIns: [MoodCheckIn],
        sleep: [SleepNight],
        energy: [DailyEnergy],
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .current,
        boundaries: DiaryTimeBoundaries = .standard
    ) -> [DiaryDay] {
        let dayStart = calendar.startOfDay(for: startDate)
        let dayEnd = calendar.startOfDay(for: endDate)
        let sleepByDay = Dictionary(uniqueKeysWithValues: sleep.map { (calendar.startOfDay(for: $0.date), $0.hours) })
        let activityByDay = activityBuckets(for: energy)

        let groupedByDay = Dictionary(grouping: checkIns) { calendar.startOfDay(for: $0.date) }
        let allDays = days(from: dayStart, through: dayEnd, calendar: calendar).reversed()

        return allDays.map { day in
            let daySamples = groupedByDay[day] ?? []
            let groupedBySlot = Dictionary(grouping: daySamples) {
                timeOfDaySlot(for: $0.date, calendar: calendar, boundaries: boundaries)
            }
            let entries = TimeOfDaySlot.allCases.map { slot in
                let values = groupedBySlot[slot]?.map(\.valence) ?? []
                let mean = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
                return DiaryTimeEntry(slot: slot, meanValence: mean, mood: mean.map(diaryMoodBucket))
            }
            let tags = daySamples.flatMap { $0.associations + $0.labels }
            return DiaryDay(
                date: day,
                entries: entries,
                sleepHours: sleepByDay[day],
                activity: activityByDay[day],
                autoNotes: joinedUnique(tags)
            )
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

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func mergedNoteText(autoText: String, userText: String?) -> String {
        let trimmedAuto = autoText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = (userText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAuto.isEmpty else { return trimmedUser }
        guard !trimmedUser.isEmpty else { return trimmedAuto }

        let userLower = trimmedUser.lowercased()
        let missingAutoParts = trimmedAuto
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !userLower.contains($0.lowercased()) }

        guard !missingAutoParts.isEmpty else { return trimmedUser }
        return (missingAutoParts + [trimmedUser]).joined(separator: ", ")
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

    private static func days(from startDate: Date, through endDate: Date, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        while cursor <= end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private static func percentile(_ sortedValues: [Double], percentile: Double) -> Double {
        guard let first = sortedValues.first else { return 0 }
        guard sortedValues.count > 1 else { return first }

        let position = percentile * Double(sortedValues.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        guard lowerIndex != upperIndex else { return sortedValues[lowerIndex] }

        let fraction = position - Double(lowerIndex)
        return sortedValues[lowerIndex] + (sortedValues[upperIndex] - sortedValues[lowerIndex]) * fraction
    }

    private static func deterministicJitter(index: Int) -> Double {
        let sequence = [-0.26, 0.18, -0.08, 0.28, 0.04, -0.20, 0.12]
        return sequence[index % sequence.count]
    }

    private static func joinedUnique(_ values: [String]) -> String {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                result.append(trimmed)
            }
        }
        return result.joined(separator: ", ")
    }
}
