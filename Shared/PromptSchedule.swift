import Foundation

/// When reminders fire, answered from the schedule alone so the app, the widget and the
/// prompt ledger agree without asking the notification center.
enum PromptSchedule {
    /// How long after a prompt a mood still counts as answering it.
    static let completionWindow: TimeInterval = 2 * 3600

    static func nextPrompt(after date: Date, reminders: [Reminder], calendar: Calendar = .current) -> Date? {
        occurrences(around: date, reminders: reminders, calendar: calendar).first { $0 > date }
    }

    static func latestPrompt(atOrBefore date: Date, reminders: [Reminder], calendar: Calendar = .current) -> Date? {
        occurrences(around: date, reminders: reminders, calendar: calendar).last { $0 <= date }
    }

    /// The prompt still waiting for an answer: it fired inside the completion window and
    /// nothing has been logged since.
    static func pendingPrompt(
        now: Date,
        reminders: [Reminder],
        lastLog: Date?,
        calendar: Calendar = .current
    ) -> Date? {
        guard let latest = latestPrompt(atOrBefore: now, reminders: reminders, calendar: calendar),
              now < latest.addingTimeInterval(completionWindow)
        else {
            return nil
        }
        if let lastLog, lastLog >= latest { return nil }
        return latest
    }

    /// Yesterday through tomorrow, sorted. Built from start of day plus minutes, the same way
    /// the ledger does, so a DST day lands both on the same instants.
    private static func occurrences(around date: Date, reminders: [Reminder], calendar: Calendar) -> [Date] {
        let minutes = Set(reminders.filter(\.isEnabled).map(\.sortKey))
        let today = calendar.startOfDay(for: date)
        return [-1, 0, 1]
            .compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
            .flatMap { day in minutes.compactMap { calendar.date(byAdding: .minute, value: $0, to: day) } }
            .sorted()
    }
}
