import XCTest
@testable import mood_journal

/// Stands in for HealthKitService. Holds the snapshot call open on a continuation so a test
/// can observe the store mid-load.
final class StubHealthService: HealthDataReading {
    private(set) var authorizationCallCount = 0
    private(set) var snapshotCallCount = 0

    var snapshot = HealthSnapshot(moodCheckIns: [], dailyEnergy: [], sleepNights: [])
    var errorToThrow: Error?
    var holdsSnapshotCall = false

    private var continuation: CheckedContinuation<Void, Never>?

    func requestAuthorization() async throws {
        authorizationCallCount += 1
        if let errorToThrow { throw errorToThrow }
    }

    func loadSnapshot(from startDate: Date, to endDate: Date, calendar: Calendar) async throws -> HealthSnapshot {
        snapshotCallCount += 1
        // Only the first call is held. If a regression lets a second one through, it returns
        // immediately and the test fails on the count rather than deadlocking on a continuation
        // nothing will resume.
        if holdsSnapshotCall && snapshotCallCount == 1 {
            await withCheckedContinuation { continuation = $0 }
        }
        if let errorToThrow { throw errorToThrow }
        return snapshot
    }

    func releaseSnapshotCall() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
final class MoodDataStoreTests: XCTestCase {
    func testConcurrentRefreshesRunTheServiceOnce() async {
        let stub = StubHealthService()
        stub.holdsSnapshotCall = true
        let store = MoodDataStore(service: stub, calendar: Self.utcCalendar)

        let inFlight = Task { await store.refresh() }
        while stub.snapshotCallCount == 0 { await Task.yield() }

        // A cold launch fires .task and scenePhase == .active together; the second must bail.
        await store.refresh()
        stub.releaseSnapshotCall()
        await inFlight.value

        XCTAssertEqual(stub.snapshotCallCount, 1)
        XCTAssertEqual(stub.authorizationCallCount, 1)
    }

    func testFailedRefreshKeepsPreviouslyLoadedData() async {
        let stub = StubHealthService()
        stub.snapshot = HealthSnapshot(
            moodCheckIns: [MoodCheckIn(date: Self.date("2026-03-01 09:00"), valence: 0.4)],
            dailyEnergy: [],
            sleepNights: []
        )
        let store = MoodDataStore(service: stub, calendar: Self.utcCalendar)

        await store.refresh()
        XCTAssertEqual(store.chartData.checkIns.count, 1)

        stub.errorToThrow = HealthKitServiceError.queryFailed("network is down")
        await store.refresh()

        XCTAssertEqual(store.chartData.checkIns.count, 1, "a transient read failure must not blank the charts")
        XCTAssertNotNil(store.errorMessage)
    }

    func testForegroundRefreshDoesNothingBeforeTheFirstLoad() async {
        let stub = StubHealthService()
        let store = MoodDataStore(service: stub, calendar: Self.utcCalendar)

        await store.refreshOnForeground()
        XCTAssertEqual(stub.snapshotCallCount, 0)

        await store.refresh()
        await store.refreshOnForeground()
        XCTAssertEqual(stub.snapshotCallCount, 2)
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)!
    }
}
