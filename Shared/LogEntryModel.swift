import Foundation
import HealthKit

@MainActor
@Observable
final class LogEntryModel {
    enum SavePhase: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    var valence: Double = 0
    private(set) var phase: SavePhase = .idle

    private let service: any MoodLogging
    private let now: () -> Date
    private let confirmationDelay: Duration
    private let didSave: (LoggedMood) -> Void
    private var hasRequestedAuthorization = false

    init(
        service: any MoodLogging = HealthKitMoodLogger(store: HKHealthStore()),
        now: @escaping () -> Date = Date.init,
        confirmationDelay: Duration = .seconds(1.5),
        didSave: @escaping (LoggedMood) -> Void = { LoggedMoodStore().record($0) }
    ) {
        self.service = service
        self.now = now
        self.confirmationDelay = confirmationDelay
        self.didSave = didSave
    }

    var classification: MoodChartClassification {
        MoodChartClassification.classification(for: valence)
    }

    /// Charts are buried in settings now, so the log screen is the only reliable place to
    /// ask for HealthKit access. Asking again after a grant is a no-op.
    func prepare() async {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        try? await service.requestAuthorization()
    }

    /// Returns once the confirmation has shown, true if the mood reached Health.
    @discardableResult
    func save() async -> Bool {
        guard phase != .saving else { return false }
        phase = .saving

        do {
            let date = now()
            try await service.saveMomentaryEmotion(valence: valence, at: date)
            didSave(LoggedMood(date: date, valence: valence))
            phase = .saved
            try? await Task.sleep(for: confirmationDelay)
            valence = 0
            phase = .idle
            return true
        } catch {
            phase = .failed(error.localizedDescription)
            return false
        }
    }

    func dismissFailure() {
        if case .failed = phase { phase = .idle }
    }
}
