import Foundation

/// Decides what opening the app shows, and holds what the today summary displays.
///
/// Today is always underneath; the slider is a sheet over it, raised on its own only when a
/// prompt is waiting: opened from a reminder, or a reminder
/// fired inside its completion window and has not been answered. Any other open shows the
/// day so far and the time to the next prompt.
@MainActor
@Observable
final class TodayModel {
    enum Screen: Equatable {
        /// Before the first read, so an open never flashes the wrong screen.
        case deciding
        case summary
        case log
    }

    private(set) var screen: Screen = .deciding
    private(set) var todaysLogs: [MoodCheckIn] = []
    /// The newest mood from before today, shown only when today is empty.
    private(set) var lastLog: MoodCheckIn?
    private(set) var nextPrompt: Date?

    private let service: any MoodHistoryReading
    private let loggedMoods: LoggedMoodStore
    private let calendar: Calendar
    private let now: () -> Date
    private var openedFromReminder = false

    init(
        service: any MoodHistoryReading = HealthKitService(),
        loggedMoods: LoggedMoodStore = LoggedMoodStore(),
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.loggedMoods = loggedMoods
        self.calendar = calendar
        self.now = now
    }

    /// Re-reads Health and, unless the slider is already up, re-decides the screen.
    func refresh(reminders: [Reminder]) async {
        let reference = now()
        let startOfDay = calendar.startOfDay(for: reference)

        // Nil means the read failed, which is different from Health holding nothing.
        var healthNewest: MoodCheckIn??
        do {
            let today = try await service.loadMoodCheckIns(from: startOfDay, to: reference)
            todaysLogs = today.sorted { $0.date < $1.date }
            lastLog = nil
            if todaysLogs.isEmpty {
                lastLog = try await service.latestMoodCheckIn(before: reference)
            }
            healthNewest = .some(todaysLogs.last ?? lastLog)
        } catch {
            healthNewest = nil
        }
        nextPrompt = PromptSchedule.nextPrompt(after: reference, reminders: reminders, calendar: calendar)

        // Read before the store is overwritten below: it also hears saves from the notification,
        // which a read straight after the write might not include yet.
        let recorded = loggedMoods.load()

        if let healthNewest {
            // Health is the source of truth, so this replaces rather than only moving forward:
            // a mood deleted in Health, or logged on the watch, reaches the widget this way.
            loggedMoods.replace(with: healthNewest.map { LoggedMood(date: $0.date, valence: $0.valence) })
        }

        guard screen != .log else { return }
        let newest = todaysLogs.last ?? lastLog
        let lastLogged = [newest?.date, recorded?.date].compactMap { $0 }.max()
        let pending = PromptSchedule.pendingPrompt(
            now: reference,
            reminders: reminders,
            lastLog: lastLogged,
            calendar: calendar
        )
        screen = openedFromReminder || pending != nil ? .log : .summary
    }

    /// Tapping a reminder can arrive before or after the first read; either way it wins.
    func openFromReminder() {
        openedFromReminder = true
        screen = .log
    }

    func startLogging() {
        screen = .log
    }

    /// Backing out of the sheet without logging. Leaves a waiting prompt waiting, but does
    /// not bring the sheet straight back until the next open.
    func cancelLogging() {
        openedFromReminder = false
        screen = .summary
    }

    func didLog(reminders: [Reminder]) async {
        openedFromReminder = false
        screen = .summary
        await refresh(reminders: reminders)
    }

    /// Called on backgrounding, so the next open decides afresh instead of resuming the slider.
    func reset() {
        openedFromReminder = false
        screen = .deciding
    }
}
