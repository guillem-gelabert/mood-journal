import Foundation

/// Pure diff between what is scheduled and what should be. Kept free of UserNotifications
/// so it can be tested as a table.
enum ReminderPlan {
    static func diff(
        pending: Set<String>,
        desired: [Reminder]
    ) -> (toRemove: [String], toAdd: [Reminder]) {
        let enabled = desired.filter(\.isEnabled)
        let wanted = Set(enabled.map(\.notificationIdentifier))

        // Filter to our own prefix first: never cancel a request we did not create.
        let ours = pending.filter { $0.hasPrefix(Reminder.identifierPrefix) }
        let toRemove = ours.subtracting(wanted).sorted()

        // Everything enabled is re-added; an existing identifier is replaced rather than
        // duplicated, which is how a time change takes effect.
        return (toRemove, enabled)
    }
}
