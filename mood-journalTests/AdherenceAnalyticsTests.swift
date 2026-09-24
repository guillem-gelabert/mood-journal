import XCTest
@testable import mood_journal

final class AdherenceAnalyticsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Momentum

    func testMomentumIsOneWhenEveryPromptWasAnswered() {
        let prompts = (1...5).map { prompt(daysAgo: Double($0), completed: true) }
        XCTAssertEqual(AdherenceAnalytics.momentum(prompts: prompts, now: now) ?? .nan, 1, accuracy: 0.0001)
    }

    func testMomentumIsZeroWhenEveryPromptWasMissed() {
        let prompts = (1...5).map { prompt(daysAgo: Double($0), completed: false) }
        XCTAssertEqual(AdherenceAnalytics.momentum(prompts: prompts, now: now) ?? .nan, 0, accuracy: 0.0001)
    }

    func testMomentumIsNilWithNoPrompts() {
        XCTAssertNil(AdherenceAnalytics.momentum(prompts: [], now: now))
    }

    /// The defining property of the half-life: a prompt exactly H days old carries half the
    /// weight of one at t. One answered now against one missed a half-life ago gives 2/3.
    func testPromptOneHalfLifeOldCountsHalf() {
        let prompts = [
            prompt(daysAgo: 0, completed: true),
            prompt(daysAgo: 7, completed: false)
        ]
        let result = AdherenceAnalytics.momentum(prompts: prompts, now: now, halfLifeDays: 7)
        XCTAssertEqual(result ?? .nan, 1.0 / 1.5, accuracy: 0.0001)
    }

    func testRecentBehaviourDominatesOlderBehaviour() {
        let recentGood = (0...2).map { prompt(daysAgo: Double($0), completed: true) }
        let oldBad = (60...70).map { prompt(daysAgo: Double($0), completed: false) }
        let result = AdherenceAnalytics.momentum(prompts: recentGood + oldBad, now: now)

        XCTAssertGreaterThan(result ?? 0, 0.99, "eleven misses two months ago must not sink three answers today")
    }

    func testFuturePromptsAreExcluded() {
        let prompts = [
            prompt(daysAgo: 1, completed: true),
            prompt(daysAgo: -1, completed: false)
        ]
        XCTAssertEqual(AdherenceAnalytics.momentum(prompts: prompts, now: now) ?? .nan, 1, accuracy: 0.0001)
    }

    // MARK: - Resilience

    func testResilienceIsOneWhenEveryMissIsFollowedByAnAnswer() {
        let prompts = [
            prompt(daysAgo: 5, completed: false),
            prompt(daysAgo: 4, completed: true),
            prompt(daysAgo: 3, completed: false),
            prompt(daysAgo: 2, completed: true)
        ]
        XCTAssertEqual(AdherenceAnalytics.resilience(prompts: prompts) ?? .nan, 1, accuracy: 0.0001)
    }

    func testResilienceIsZeroWhenMissesNeverRecover() {
        let prompts = (1...4).reversed().map { prompt(daysAgo: Double($0), completed: false) }
        XCTAssertEqual(AdherenceAnalytics.resilience(prompts: prompts) ?? .nan, 0, accuracy: 0.0001)
    }

    func testResilienceIsNilWithNoMisses() {
        let prompts = (1...4).reversed().map { prompt(daysAgo: Double($0), completed: true) }
        XCTAssertNil(AdherenceAnalytics.resilience(prompts: prompts), "a clean record is not 0%")
    }

    func testHalfTheMissesRecovering() {
        let prompts = [
            prompt(daysAgo: 4, completed: false),
            prompt(daysAgo: 3, completed: true),
            prompt(daysAgo: 2, completed: false),
            prompt(daysAgo: 1, completed: false)
        ]
        XCTAssertEqual(AdherenceAnalytics.resilience(prompts: prompts) ?? .nan, 0.5, accuracy: 0.0001)
    }

    /// The last prompt has no successor, so a trailing miss belongs in neither sum.
    func testTrailingMissIsExcludedFromTheDenominator() {
        let withTrailingMiss = [
            prompt(daysAgo: 3, completed: false),
            prompt(daysAgo: 2, completed: true),
            prompt(daysAgo: 1, completed: false)
        ]
        XCTAssertEqual(AdherenceAnalytics.resilience(prompts: withTrailingMiss) ?? .nan, 1, accuracy: 0.0001)
    }

    func testResilienceIgnoresInputOrdering() {
        let ordered = [
            prompt(daysAgo: 3, completed: false),
            prompt(daysAgo: 2, completed: true),
            prompt(daysAgo: 1, completed: true)
        ]
        XCTAssertEqual(
            AdherenceAnalytics.resilience(prompts: ordered.shuffled()) ?? .nan,
            AdherenceAnalytics.resilience(prompts: ordered) ?? .nan,
            accuracy: 0.0001
        )
    }

    func testResilienceIsNilWithASinglePrompt() {
        XCTAssertNil(AdherenceAnalytics.resilience(prompts: [prompt(daysAgo: 1, completed: false)]))
    }

    // MARK: - Stats

    func testStatsFlagsEstimates() {
        let stats = AdherenceAnalytics.stats(
            prompts: [
                prompt(daysAgo: 2, completed: true, estimated: true),
                prompt(daysAgo: 1, completed: false)
            ],
            now: now
        )
        XCTAssertTrue(stats.includesEstimates)
        XCTAssertNotNil(stats.momentum)
    }

    func testEmptyStatsHaveNothingToShow() {
        XCTAssertFalse(AdherenceAnalytics.stats(prompts: [], now: now).hasAnything)
    }

    // MARK: - Compared with the past

    func testTrendNeedsFivePointsToCountAsChange() {
        XCTAssertEqual(AdherenceTrend(current: 0.70, past: 0.60), .better)
        XCTAssertEqual(AdherenceTrend(current: 0.62, past: 0.60), .steady)
        XCTAssertEqual(AdherenceTrend(current: 0.50, past: 0.60), .worse)
        XCTAssertNil(AdherenceTrend(current: 0.5, past: nil))
    }

    func testUsualMomentumReflectsTheLastNinetyDays() {
        // Answered everything until a week ago, then missed everything since.
        let prompts = (0...100).map { prompt(daysAgo: Double($0), completed: $0 > 7) }
        let current = AdherenceAnalytics.momentum(prompts: prompts, now: now) ?? .nan
        let usual = AdherenceAnalytics.usualMomentum(prompts: prompts, now: now) ?? .nan

        XCTAssertLessThan(current, 0.6)
        XCTAssertGreaterThan(usual, 0.85)
        XCTAssertEqual(AdherenceTrend(current: current, past: usual), .worse)
    }

    func testUsualMomentumNeedsTwoWeeksOfHistory() {
        let prompts = (0...10).map { prompt(daysAgo: Double($0), completed: true) }
        XCTAssertNil(AdherenceAnalytics.usualMomentum(prompts: prompts, now: now))
    }

    func testResilienceIsSplitIntoTheLastNinetyDaysAndBefore() {
        // Before: every miss was followed by another miss. Lately: every miss recovered.
        let before = (120...129).map { prompt(daysAgo: Double($0), completed: false) }
        let recent = (1...20).map { prompt(daysAgo: Double($0), completed: $0.isMultiple(of: 2)) }

        let split = AdherenceAnalytics.resilienceSplit(prompts: before + recent, now: now)

        XCTAssertEqual(split.before ?? .nan, 0, accuracy: 0.0001)
        XCTAssertEqual(split.recent ?? .nan, 1, accuracy: 0.0001)
        XCTAssertEqual(AdherenceTrend(current: split.recent, past: split.before), .better)
    }

    func testUsualMomentumIsYourWholeHistoryNotJustRecentMonths() {
        // A good year, then three slow months: the slow stretch must not become the standard.
        let goodYear = (91...455).map { prompt(daysAgo: Double($0), completed: true) }
        let slowMonths = (0...90).map { prompt(daysAgo: Double($0), completed: $0.isMultiple(of: 3)) }
        let prompts = goodYear + slowMonths

        let current = AdherenceAnalytics.momentum(prompts: prompts, now: now)
        let usual = AdherenceAnalytics.usualMomentum(prompts: prompts, now: now)

        XCTAssertEqual(AdherenceTrend(current: current, past: usual), .worse)
    }

    private func prompt(daysAgo: Double, completed: Bool, estimated: Bool = false) -> PromptRecord {
        PromptRecord(
            scheduledAt: now.addingTimeInterval(-daysAgo * 86_400),
            isCompleted: completed,
            isEstimated: estimated
        )
    }
}
