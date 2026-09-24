import Foundation

protocol ReminderPersisting {
    /// nil means "never written", which is different from "the user deleted them all".
    /// Seeding on an empty array instead would resurrect the three defaults every launch
    /// after someone clears the list.
    func load() -> [Reminder]?
    func save(_ reminders: [Reminder])
}

/// Lives in the app group so the lock screen widget can count down to the next prompt.
struct UserDefaultsReminderStore: ReminderPersisting {
    private static let key = "reminders.v1"

    var defaults: UserDefaults = AppGroup.defaults
    /// Where reminders were kept before the app group existed; read once and copied over.
    var legacyDefaults: UserDefaults? = .standard

    func load() -> [Reminder]? {
        if defaults.data(forKey: Self.key) == nil,
           let legacyDefaults, legacyDefaults !== defaults,
           let legacy = legacyDefaults.data(forKey: Self.key) {
            defaults.set(legacy, forKey: Self.key)
        }
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode([Reminder].self, from: data)
    }

    func save(_ reminders: [Reminder]) {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
