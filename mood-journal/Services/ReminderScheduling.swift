import Foundation
import UserNotifications

struct ReminderAuthorization: Equatable {
    var isAuthorized: Bool
    var isTimeSensitiveEnabled: Bool

    static let unknown = ReminderAuthorization(isAuthorized: false, isTimeSensitiveEnabled: false)
}

protocol ReminderScheduling {
    func requestAuthorization() async -> Bool
    func authorization() async -> ReminderAuthorization
    func sync(_ reminders: [Reminder]) async
}

struct NotificationReminderScheduler: ReminderScheduling {
    private var center: UNUserNotificationCenter { .current() }

    func requestAuthorization() async -> Bool {
        // Never request .timeSensitive here: that option is deprecated. The interruption
        // level is set on the content instead.
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorization() async -> ReminderAuthorization {
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        return ReminderAuthorization(
            isAuthorized: authorized,
            isTimeSensitiveEnabled: settings.timeSensitiveSetting == .enabled
        )
    }

    func sync(_ reminders: [Reminder]) async {
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Reminder.notificationCategory,
                actions: [],
                intentIdentifiers: [],
                options: []
            )
        ])

        let pending = await center.pendingNotificationRequests()
        let plan = ReminderPlan.diff(pending: Set(pending.map(\.identifier)), desired: reminders)

        center.removePendingNotificationRequests(withIdentifiers: plan.toRemove)

        for reminder in plan.toAdd {
            let request = UNNotificationRequest(
                identifier: reminder.notificationIdentifier,
                content: Self.content(),
                trigger: UNCalendarNotificationTrigger(dateMatching: reminder.dateComponents, repeats: true)
            )
            try? await center.add(request)
        }
    }

    /// A one-off reminder a few seconds out, for trying the notification without waiting for
    /// the schedule. Outside the reminder prefix, so a sync never cancels it.
    func sendTestReminder(after seconds: TimeInterval = 5) async {
        let request = UNNotificationRequest(
            identifier: "mood-test-reminder",
            content: Self.content(),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        try? await center.add(request)
    }

    private static func content() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Mood check-in"
        content.body = "How are you feeling right now?"
        content.sound = .default
        // Long-pressing opens the slider in the notification itself.
        content.categoryIdentifier = Reminder.notificationCategory
        // Without the time-sensitive entitlement this is silently demoted to .active
        // rather than failing, so it is safe to set unconditionally.
        content.interruptionLevel = .timeSensitive
        return content
    }
}
