import Foundation

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
    private var hasRequestedAuthorization = false

    init(
        service: any MoodLogging = HealthKitService(),
        now: @escaping () -> Date = Date.init,
        confirmationDelay: Duration = .seconds(1.5)
    ) {
        self.service = service
        self.now = now
        self.confirmationDelay = confirmationDelay
    }

    var classification: MoodChartClassification {
        MoodAnalytics.chartClassification(for: valence)
    }

    /// Charts are buried in settings now, so the log screen is the only reliable place to
    /// ask for HealthKit access. Asking again after a grant is a no-op.
    func prepare() async {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        try? await service.requestAuthorization()
    }

    func save() async {
        guard phase != .saving else { return }
        phase = .saving

        do {
            try await service.saveMomentaryEmotion(valence: valence, at: now())
            phase = .saved
            try? await Task.sleep(for: confirmationDelay)
            valence = 0
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func dismissFailure() {
        if case .failed = phase { phase = .idle }
    }
}
