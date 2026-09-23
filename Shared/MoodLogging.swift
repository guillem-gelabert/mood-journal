import Foundation
import HealthKit

protocol MoodLogging {
    func requestAuthorization() async throws
    func saveMomentaryEmotion(valence: Double, at date: Date) async throws
    func shareAuthorizationStatus() -> HKAuthorizationStatus
}

enum MoodLoggingError: LocalizedError {
    case healthDataUnavailable

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable: "Health data is not available on this device."
        }
    }
}
