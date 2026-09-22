import Foundation
import HealthKit

protocol HealthDataReading {
    func requestAuthorization() async throws
    func loadSnapshot(from startDate: Date, to endDate: Date, calendar: Calendar) async throws -> HealthSnapshot
    /// Floor for the `.all` range. Without it `.all` would either lie about its span or make
    /// the statistics collection query enumerate an absurd number of daily buckets.
    func earliestPermittedSampleDate() -> Date
}

protocol MoodLogging {
    /// Declared here as well as on `HealthDataReading` so the log screen can ask for access
    /// without depending on the reading side. `HealthKitService` satisfies both with one method.
    func requestAuthorization() async throws
    func saveMomentaryEmotion(valence: Double, at date: Date) async throws
    func shareAuthorizationStatus() -> HKAuthorizationStatus
}

extension HealthKitService: HealthDataReading {}
extension HealthKitService: MoodLogging {}
