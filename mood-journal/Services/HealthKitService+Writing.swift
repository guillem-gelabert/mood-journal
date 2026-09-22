import Foundation
import HealthKit

extension HealthKitService {
    /// Saves a momentary emotion with valence only. Labels and associations stay empty:
    /// the log screen is a bare slider, and Health accepts a sample without either.
    func saveMomentaryEmotion(valence: Double, at date: Date) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.healthDataUnavailable
        }

        // Slider gestures can interpolate a hair past their bounds, and HKStateOfMind
        // rejects a valence outside -1...1.
        let clamped = min(max(valence, -1), 1)
        let sample = HKStateOfMind(
            date: date,
            kind: .momentaryEmotion,
            valence: clamped,
            labels: [],
            associations: []
        )

        try await healthStore.save(sample)
    }

    func shareAuthorizationStatus() -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: HKObjectType.stateOfMindType())
    }
}
