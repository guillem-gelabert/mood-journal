import Foundation

/// Turns a reminder schedule plus the clock into a record of which prompts fired and which
/// were answered.
///
/// It is driven by the schedule, not by notification taps: the app cannot run code when a
/// notification merely fires, so a tap-based ledger would only ever see the prompts you
/// already answered.
enum PromptLedger {
    static let completionWindow = PromptSchedule.completionWindow

    /// Prompts scheduled per synthetic backfill day are spread across this span.
    static let backfillDayStartHour = 9
    static let backfillDayEndHour = 21

    static func isCompleted(promptAt scheduledAt: Date, checkIns: [MoodCheckIn]) -> Bool {
        let deadline = scheduledAt.addingTimeInterval(completionWindow)
        return checkIns.contains { $0.date >= scheduledAt && $0.date < deadline }
    }

    /// Materialises every prompt whose window has closed since `state.materialisedThrough`.
    static func materialise(
        state: PromptLedgerState,
        reminders: [Reminder],
        checkIns: [MoodCheckIn],
        now: Date,
        calendar: Calendar = .current
    ) -> PromptLedgerState {
        var updated = state
        let resolvedThrough = now.addingTimeInterval(-completionWindow)
        guard let from = state.materialisedThrough else {
            updated.materialisedThrough = resolvedThrough
            return updated
        }
        guard resolvedThrough > from else { return state }

        let times = scheduledTimes(
            reminders: reminders,
            from: from,
            through: resolvedThrough,
            calendar: calendar
        )

        updated.records += times.map {
            PromptRecord(scheduledAt: $0, isCompleted: isCompleted(promptAt: $0, checkIns: checkIns))
        }
        updated.materialisedThrough = resolvedThrough
        return updated
    }

    /// One-time reconstruction so the numbers are not blank on day one. Uses the current
    /// reminder times where there are any; otherwise infers how many prompts a day to assume
    /// from how often moods were actually logged.
    static func backfill(
        state: PromptLedgerState,
        reminders: [Reminder],
        checkIns: [MoodCheckIn],
        now: Date,
        calendar: Calendar = .current
    ) -> PromptLedgerState {
        guard !state.didBackfill else { return state }

        var updated = state
        updated.didBackfill = true

        guard let earliest = checkIns.map(\.date).min() else {
            updated.materialisedThrough = now.addingTimeInterval(-completionWindow)
            return updated
        }

        let start = calendar.startOfDay(for: earliest)
        let end = now.addingTimeInterval(-completionWindow)
        let enabled = reminders.filter(\.isEnabled)

        let times: [Date]
        if enabled.isEmpty {
            let perDay = inferredPromptsPerDay(checkIns: checkIns, now: now, calendar: calendar)
            times = syntheticTimes(perDay: perDay, from: start, through: end, calendar: calendar)
        } else {
            times = scheduledTimes(reminders: enabled, from: start, through: end, calendar: calendar)
        }

        updated.records += times.map {
            PromptRecord(
                scheduledAt: $0,
                isCompleted: isCompleted(promptAt: $0, checkIns: checkIns),
                isEstimated: true
            )
        }
        updated.materialisedThrough = end
        return updated
    }

    /// Mean logs per day over the trailing two weeks, rounded, clamped to at least one.
    static func inferredPromptsPerDay(
        checkIns: [MoodCheckIn],
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard let windowStart = calendar.date(byAdding: .day, value: -14, to: now) else { return 1 }
        let recent = checkIns.filter { $0.date >= windowStart && $0.date <= now }
        guard !recent.isEmpty else { return 1 }
        return max(1, Int((Double(recent.count) / 14).rounded()))
    }

    // MARK: - Times

    private static func scheduledTimes(
        reminders: [Reminder],
        from: Date,
        through: Date,
        calendar: Calendar
    ) -> [Date] {
        // Two reminders at the same minute would otherwise let one log complete both.
        let minutes = Set(reminders.filter(\.isEnabled).map(\.sortKey)).sorted()
        guard !minutes.isEmpty else { return [] }

        return everyDay(from: from, through: through, calendar: calendar).flatMap { day in
            minutes.compactMap { minute in
                calendar.date(byAdding: .minute, value: minute, to: day)
            }
        }
        .filter { $0 > from && $0 <= through }
        .sorted()
    }

    private static func syntheticTimes(
        perDay: Int,
        from: Date,
        through: Date,
        calendar: Calendar
    ) -> [Date] {
        let span = backfillDayEndHour - backfillDayStartHour
        let minutes: [Int] = (0..<perDay).map { index in
            let offset = perDay == 1 ? span / 2 : index * span / max(1, perDay - 1)
            return (backfillDayStartHour + offset) * 60
        }

        return everyDay(from: from, through: through, calendar: calendar).flatMap { day in
            minutes.compactMap { calendar.date(byAdding: .minute, value: $0, to: day) }
        }
        .filter { $0 > from && $0 <= through }
        .sorted()
    }

    private static func everyDay(from: Date, through: Date, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var cursor = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: through)
        while cursor <= end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }
}
