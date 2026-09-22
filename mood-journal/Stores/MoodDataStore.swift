import Foundation

@MainActor
@Observable
final class MoodDataStore {
    private(set) var chartData: ChartData = .empty
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var range: ChartRange
    private(set) var adherence: AdherenceStats = .empty

    private let service: any HealthDataReading
    private let calendar: Calendar
    private let defaults: UserDefaults
    private let promptLog: any PromptLogPersisting
    private let now: () -> Date
    private var hasLoadedOnce = false

    private static let rangeDefaultsKey = "charts.range"
    /// The adherence ledger is deliberately not range-scoped; this bounds the work.
    private static let adherenceWindowDays = 400

    init(
        service: any HealthDataReading = HealthKitService(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard,
        promptLog: any PromptLogPersisting = FilePromptLogStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.calendar = calendar
        self.defaults = defaults
        self.promptLog = promptLog
        self.now = now
        self.range = defaults.string(forKey: Self.rangeDefaultsKey)
            .flatMap(ChartRange.init(rawValue:)) ?? .days90
    }

    func select(range newRange: ChartRange) async {
        guard newRange != range else { return }
        range = newRange
        defaults.set(newRange.rawValue, forKey: Self.rangeDefaultsKey)
        await refresh()
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

            let reference = now()
            let earliest = service.earliestPermittedSampleDate()
            guard let fetch = range.fetchInterval(
                now: reference,
                earliestSample: earliest,
                calendar: calendar
            ) else {
                chartData = .empty
                return
            }

            let snapshot = try await service.loadSnapshot(from: fetch.start, to: fetch.end, calendar: calendar)
            let displayed = range.interval(now: reference, earliestSample: earliest, calendar: calendar)
            chartData = MoodAnalytics.derive(snapshot: snapshot, interval: displayed, calendar: calendar)
        } catch {
            // Keep whatever was already loaded: a transient read failure should not blank the charts.
            errorMessage = error.localizedDescription
        }
    }

    /// Updates the prompt ledger, then recomputes Momentum and Resilience from it.
    /// Separate from `refresh()` because it deliberately ignores the chart range.
    func updateAdherence(reminders: [Reminder]) async {
        let reference = now()
        guard let windowStart = calendar.date(byAdding: .day, value: -Self.adherenceWindowDays, to: reference) else {
            return
        }

        guard let checkIns = try? await service.loadMoodCheckIns(from: windowStart, to: reference) else { return }

        var state = promptLog.load() ?? PromptLedgerState()
        state = PromptLedger.backfill(
            state: state,
            reminders: reminders,
            checkIns: checkIns,
            now: reference,
            calendar: calendar
        )
        state = PromptLedger.materialise(
            state: state,
            reminders: reminders,
            checkIns: checkIns,
            now: reference,
            calendar: calendar
        )
        promptLog.save(state)

        adherence = AdherenceAnalytics.stats(prompts: state.records, now: reference)
    }

    /// Foregrounding refreshes only after a first load has completed, so returning to the app
    /// mid-launch does not queue a second identical fetch.
    func refreshOnForeground() async {
        guard hasLoadedOnce else { return }
        await refresh()
    }
}
