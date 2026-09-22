import Foundation

@MainActor
@Observable
final class MoodDataStore {
    static let historyWindowDays = 200

    private(set) var chartData: ChartData = .empty
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service: any HealthDataReading
    private let calendar: Calendar
    private var hasLoadedOnce = false

    init(service: any HealthDataReading = HealthKitService(), calendar: Calendar = .current) {
        self.service = service
        self.calendar = calendar
    }

    func refresh() async {
        // A cold launch fires both .task and the first scenePhase == .active. Without this
        // guard the two runs raced and each published a full set of results.
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoadedOnce = true
        }

        do {
            try await service.requestAuthorization()
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -Self.historyWindowDays, to: endDate) ?? endDate
            let snapshot = try await service.loadSnapshot(from: startDate, to: endDate, calendar: calendar)
            chartData = MoodAnalytics.derive(snapshot: snapshot, calendar: calendar)
        } catch {
            // Keep whatever was already loaded: a transient read failure should not blank the charts.
            errorMessage = error.localizedDescription
        }
    }

    /// Foregrounding refreshes only after a first load has completed, so returning to the app
    /// mid-launch does not queue a second identical fetch.
    func refreshOnForeground() async {
        guard hasLoadedOnce else { return }
        await refresh()
    }
}
