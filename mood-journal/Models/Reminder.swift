import Foundation

struct Reminder: Identifiable, Codable, Equatable {
    var id: UUID
    var hour: Int
    var minute: Int
    var isEnabled: Bool

    init(id: UUID = UUID(), hour: Int, minute: Int, isEnabled: Bool = true) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
    }

    /// Stable across reschedules: re-adding a request with the same identifier replaces it,
    /// which is the clean way to move a reminder's time. The prefix also lets the scheduler
    /// tell our pending requests from anything else.
    static let identifierPrefix = "mood-reminder-"

    var notificationIdentifier: String { Self.identifierPrefix + id.uuidString }

    /// Hour and minute only, so the trigger matches daily.
    var dateComponents: DateComponents { DateComponents(hour: hour, minute: minute) }

    var sortKey: Int { hour * 60 + minute }

    static let defaults: [Reminder] = [
        Reminder(hour: 9, minute: 0),
        Reminder(hour: 17, minute: 0),
        Reminder(hour: 20, minute: 0)
    ]
}
