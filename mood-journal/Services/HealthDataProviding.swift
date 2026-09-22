import Foundation
import HealthKit

protocol HealthDataReading {
    func requestAuthorization() async throws
    func loadSnapshot(from startDate: Date, to endDate: Date, calendar: Calendar) async throws -> HealthSnapshot
}

protocol MoodLogging {
    func saveMomentaryEmotion(valence: Double, at date: Date) async throws
    func shareAuthorizationStatus() -> HKAuthorizationStatus
}

extension HealthKitService: HealthDataReading {}
extension HealthKitService: MoodLogging {}
