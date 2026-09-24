import Foundation

struct LoggedMood: Codable, Equatable {
    var date: Date
    var valence: Double
}

/// The newest mood logged, kept in the app group for the lock screen widget, which cannot
/// read Health while the phone is locked. Moods logged or deleted elsewhere (the watch, the
/// Health app) only reach it the next time the phone app reads Health.
struct LoggedMoodStore {
    private static let key = "lastLoggedMood.v1"

    var defaults: UserDefaults = AppGroup.defaults

    func load() -> LoggedMood? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(LoggedMood.self, from: data)
    }

    /// After a save. Ignores anything older than what is stored.
    func record(_ mood: LoggedMood) {
        if let current = load(), current.date >= mood.date { return }
        replace(with: mood)
    }

    /// With what Health says is newest, even if older than what is stored or nothing at all:
    /// that is how a deleted mood leaves the widget.
    func replace(with mood: LoggedMood?) {
        guard mood != load() else { return }
        if let mood, let data = try? JSONEncoder().encode(mood) {
            defaults.set(data, forKey: Self.key)
        } else {
            defaults.removeObject(forKey: Self.key)
        }
        AppGroup.reloadWidgets()
    }
}
