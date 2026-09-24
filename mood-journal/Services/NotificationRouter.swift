import UIKit
import UserNotifications

/// Hears reminder taps. SwiftUI has no hook for them, so the app delegate installs this as
/// the notification center delegate before launch finishes, which is required for a tap
/// that launched the app to be delivered at all.
@MainActor
@Observable
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    /// Set by a tap and cleared by whoever acts on it. A flag rather than an event so a tap
    /// that launched the app, arriving before any view is observing, is not lost.
    private(set) var hasPendingTap = false

    func consumeTap() -> Bool {
        defer { hasPendingTap = false }
        return hasPendingTap
    }

    // Completion-handler forms, not async: the async ones return on whatever thread the task
    // ends on, and UIKit asserts that a response is completed on the main thread.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let isReminderTap = response.actionIdentifier == UNNotificationDefaultActionIdentifier
            && response.notification.request.content.categoryIdentifier == Reminder.notificationCategory
        DispatchQueue.main.async {
            if isReminderTap { MainActor.assumeIsolated { self.hasPendingTap = true } }
            completionHandler()
        }
    }

    /// Without this a reminder arriving while the app is open is dropped silently.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        return true
    }
}
