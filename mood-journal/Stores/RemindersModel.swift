import Foundation

@MainActor
@Observable
final class RemindersModel {
    /// A repeating request costs one of the 64 pending slots, so the cap is about keeping the
    /// list sane rather than staying under the system limit.
    static let maximumReminders = 12

    private(set) var reminders: [Reminder] = []
    private(set) var authorization: ReminderAuthorization = .unknown

    private let store: any ReminderPersisting
    private let scheduler: any ReminderScheduling

    init(
        store: any ReminderPersisting = UserDefaultsReminderStore(),
        scheduler: any ReminderScheduling = NotificationReminderScheduler()
    ) {
        self.store = store
        self.scheduler = scheduler
        reminders = store.load() ?? Reminder.defaults
    }

    var canAddMore: Bool { reminders.count < Self.maximumReminders }

    func start() async {
        if store.load() == nil {
            // First run: persist the seeds so clearing the list later is respected.
            store.save(reminders)
            _ = await scheduler.requestAuthorization()
        }
        authorization = await scheduler.authorization()
        await scheduler.sync(reminders)
    }

    /// Re-synced on foreground so the schedule self-heals after a system notification reset.
    func refreshAuthorization() async {
        authorization = await scheduler.authorization()
        await scheduler.sync(reminders)
    }

    func add(hour: Int, minute: Int) {
        guard canAddMore else { return }
        commit(reminders + [Reminder(hour: hour, minute: minute)])
    }

    func update(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        var updated = reminders
        updated[index] = reminder
        commit(updated)
    }

    func delete(at offsets: IndexSet) {
        var updated = reminders
        updated.remove(atOffsets: offsets)
        commit(updated)
    }

    private func commit(_ updated: [Reminder]) {
        reminders = updated.sorted { $0.sortKey < $1.sortKey }
        store.save(reminders)
        AppGroup.reloadWidgets()
        Task { await scheduler.sync(reminders) }
    }
}
