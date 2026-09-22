import Foundation

protocol ReminderPersisting {
    /// nil means "never written", which is different from "the user deleted them all".
    /// Seeding on an empty array instead would resurrect the three defaults every launch
    /// after someone clears the list.
    func load() -> [Reminder]?
    func save(_ reminders: [Reminder])
}

struct UserDefaultsReminderStore: ReminderPersisting {
    private static let key = "reminders.v1"

    var defaults: UserDefaults = .standard

    func load() -> [Reminder]? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode([Reminder].self, from: data)
    }

    func save(_ reminders: [Reminder]) {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
