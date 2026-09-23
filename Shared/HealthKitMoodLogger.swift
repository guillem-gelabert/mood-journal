import Foundation
import HealthKit

/// Writes momentary emotions to Health. Used by both apps, so the sample is built identically
/// on the phone and the watch.
///
/// `additionalReadTypes` exists so the phone can request its chart data in the same prompt as
/// the write permission; the watch passes none and asks only to write.
struct HealthKitMoodLogger: MoodLogging {
    let store: HKHealthStore
    var additionalReadTypes: Set<HKObjectType> = []

    init(store: HKHealthStore, additionalReadTypes: Set<HKObjectType> = []) {
        self.store = store
        self.additionalReadTypes = additionalReadTypes
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw MoodLoggingError.healthDataUnavailable
        }

        let stateOfMind = HKObjectType.stateOfMindType()
        try await store.requestAuthorization(
            toShare: [stateOfMind],
            read: additionalReadTypes.union([stateOfMind])
        )
    }

    func saveMomentaryEmotion(valence: Double, at date: Date) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw MoodLoggingError.healthDataUnavailable
        }

        // The Digital Crown and slider can both land a hair outside their bounds, and
        // HKStateOfMind rejects a valence outside -1...1.
        let clamped = min(max(valence, -1), 1)
        let sample = HKStateOfMind(
            date: date,
            kind: .momentaryEmotion,
            valence: clamped,
            labels: [],
            associations: []
        )

        try await store.save(sample)
    }

    func shareAuthorizationStatus() -> HKAuthorizationStatus {
        store.authorizationStatus(for: HKObjectType.stateOfMindType())
    }
}
