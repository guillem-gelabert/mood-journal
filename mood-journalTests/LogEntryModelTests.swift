import HealthKit
import XCTest
@testable import mood_journal

final class StubMoodLogger: MoodLogging {
    private(set) var authorizationCallCount = 0
    private(set) var savedValences: [Double] = []
    private(set) var savedDates: [Date] = []

    var errorToThrow: Error?

    func requestAuthorization() async throws {
        authorizationCallCount += 1
    }

    func saveMomentaryEmotion(valence: Double, at date: Date) async throws {
        if let errorToThrow { throw errorToThrow }
        savedValences.append(valence)
        savedDates.append(date)
    }

    func shareAuthorizationStatus() -> HKAuthorizationStatus { .sharingAuthorized }
}

@MainActor
final class LogEntryModelTests: XCTestCase {
    func testSaveWritesTheSliderValueThenResets() async {
        let logger = StubMoodLogger()
        let stamp = Date(timeIntervalSince1970: 1_800_000_000)
        let model = LogEntryModel(service: logger, now: { stamp }, confirmationDelay: .zero, didSave: { _ in })

        model.valence = 0.45
        await model.save()

        XCTAssertEqual(logger.savedValences, [0.45])
        XCTAssertEqual(logger.savedDates, [stamp])
        XCTAssertEqual(model.valence, 0, "the slider returns to neutral after a log")
        XCTAssertEqual(model.phase, .idle)
    }

    func testFailedSaveSurfacesTheErrorAndKeepsTheValue() async {
        let logger = StubMoodLogger()
        logger.errorToThrow = HealthKitServiceError.healthDataUnavailable
        let model = LogEntryModel(service: logger, confirmationDelay: .zero, didSave: { _ in })

        model.valence = -0.8
        await model.save()

        guard case .failed(let message) = model.phase else {
            return XCTFail("expected a failed phase, got \(model.phase)")
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertEqual(model.valence, -0.8, "a failed write must not discard what the user chose")

        model.dismissFailure()
        XCTAssertEqual(model.phase, .idle)
    }

    func testAuthorizationIsRequestedOnlyOnce() async {
        let logger = StubMoodLogger()
        let model = LogEntryModel(service: logger, confirmationDelay: .zero, didSave: { _ in })

        await model.prepare()
        await model.prepare()

        XCTAssertEqual(logger.authorizationCallCount, 1)
    }

    func testClassificationTracksTheSlider() {
        let model = LogEntryModel(service: StubMoodLogger(), didSave: { _ in })

        model.valence = 0.7
        XCTAssertEqual(model.classification, .veryPleasant)
        model.valence = 0
        XCTAssertEqual(model.classification, .neutral)
        model.valence = -0.9
        XCTAssertEqual(model.classification, .veryUnpleasant)
    }
}
