import XCTest
@testable import mood_journal

final class InMemoryReminderStore: ReminderPersisting {
    private var stored: [Reminder]?

    init(seed: [Reminder]? = nil) { stored = seed }

    func load() -> [Reminder]? { stored }
    func save(_ reminders: [Reminder]) { stored = reminders }
}

/// Main-actor isolated because RemindersModel syncs from unstructured tasks: off the main
/// actor, two of them appending at once corrupted the array and crashed the test host.
@MainActor
final class SpyScheduler: ReminderScheduling {
    private(set) var syncedLists: [[Reminder]] = []
    private(set) var authorizationRequests = 0
    var response = ReminderAuthorization(isAuthorized: true, isTimeSensitiveEnabled: false)

    func requestAuthorization() async -> Bool {
        authorizationRequests += 1
        return response.isAuthorized
    }

    func authorization() async -> ReminderAuthorization { response }

    func sync(_ reminders: [Reminder]) async { syncedLists.append(reminders) }
}

final class ReminderTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let original = Reminder(hour: 17, minute: 30, isEnabled: false)
        let decoded = try JSONDecoder().decode(Reminder.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
    }

    func testIdentifierIsStableAndPrefixed() {
        let reminder = Reminder(hour: 9, minute: 0)
        XCTAssertTrue(reminder.notificationIdentifier.hasPrefix(Reminder.identifierPrefix))
        XCTAssertEqual(reminder.notificationIdentifier, reminder.notificationIdentifier)
    }

    // MARK: - ReminderPlan

    func testPlanAddsEveryEnabledReminder() {
        let reminders = [Reminder(hour: 9, minute: 0), Reminder(hour: 20, minute: 0)]
        let plan = ReminderPlan.diff(pending: [], desired: reminders)

        XCTAssertEqual(plan.toAdd, reminders)
        XCTAssertTrue(plan.toRemove.isEmpty)
    }

    func testPlanRemovesDisabledReminders() {
        let off = Reminder(hour: 9, minute: 0, isEnabled: false)
        let on = Reminder(hour: 20, minute: 0)
        let plan = ReminderPlan.diff(
            pending: [off.notificationIdentifier, on.notificationIdentifier],
            desired: [off, on]
        )

        XCTAssertEqual(plan.toRemove, [off.notificationIdentifier])
        XCTAssertEqual(plan.toAdd, [on])
    }

    func testPlanNeverTouchesForeignIdentifiers() {
        let mine = Reminder(hour: 9, minute: 0)
        let plan = ReminderPlan.diff(
            pending: ["some-other-app-request", mine.notificationIdentifier],
            desired: [mine]
        )

        XCTAssertTrue(plan.toRemove.isEmpty, "only requests carrying our prefix may be cancelled")
    }

    func testPlanRemovesDeletedReminders() {
        let deleted = Reminder(hour: 12, minute: 0)
        let kept = Reminder(hour: 20, minute: 0)
        let plan = ReminderPlan.diff(
            pending: [deleted.notificationIdentifier, kept.notificationIdentifier],
            desired: [kept]
        )

        XCTAssertEqual(plan.toRemove, [deleted.notificationIdentifier])
    }

    // MARK: - Seeding

    @MainActor
    func testFirstRunSeedsTheThreeDefaults() async {
        let store = InMemoryReminderStore(seed: nil)
        let model = RemindersModel(store: store, scheduler: SpyScheduler())

        XCTAssertEqual(model.reminders.map(\.hour), [9, 17, 20])
        await model.start()
        XCTAssertEqual(store.load()?.count, 3, "the seeds are persisted so a later clear sticks")
    }

    /// The bug this design exists to prevent: an empty stored list must stay empty.
    @MainActor
    func testClearedListIsNotResurrected() async {
        let store = InMemoryReminderStore(seed: [])
        let model = RemindersModel(store: store, scheduler: SpyScheduler())

        XCTAssertTrue(model.reminders.isEmpty)
        await model.start()
        XCTAssertTrue(model.reminders.isEmpty)
    }

    @MainActor
    func testMutationsPersistAndResync() async {
        let store = InMemoryReminderStore(seed: [])
        let scheduler = SpyScheduler()
        let model = RemindersModel(store: store, scheduler: scheduler)

        model.add(hour: 21, minute: 15)
        model.add(hour: 7, minute: 45)

        XCTAssertEqual(model.reminders.map(\.hour), [7, 21], "reminders stay in time order")
        XCTAssertEqual(store.load()?.count, 2)

        model.delete(at: IndexSet(integer: 0))
        XCTAssertEqual(model.reminders.map(\.hour), [21])
        XCTAssertEqual(store.load()?.count, 1)
    }

    @MainActor
    func testReminderCountIsCapped() {
        let model = RemindersModel(store: InMemoryReminderStore(seed: []), scheduler: SpyScheduler())

        for minute in 0..<(RemindersModel.maximumReminders + 3) {
            model.add(hour: 9, minute: minute)
        }

        XCTAssertEqual(model.reminders.count, RemindersModel.maximumReminders)
        XCTAssertFalse(model.canAddMore)
    }
}
