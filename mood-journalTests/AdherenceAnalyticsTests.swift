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

    private func prompt(daysAgo: Double, completed: Bool, estimated: Bool = false) -> PromptRecord {
        PromptRecord(
            scheduledAt: now.addingTimeInterval(-daysAgo * 86_400),
            isCompleted: completed,
            isEstimated: estimated
        )
    }
}
