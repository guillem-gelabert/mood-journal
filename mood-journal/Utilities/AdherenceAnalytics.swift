import Foundation

enum AdherenceAnalytics {
    static let defaultHalfLifeDays: Double = 7

    /// M(t) = Σ xᵢ·2^(-(t - tᵢ)/H) / Σ 2^(-(t - tᵢ)/H)
    ///
    /// A half-life weighted completion rate: a prompt one half-life old counts half as much
    /// as one answered now. Prompts scheduled after `now` are excluded.
    static func momentum(
        prompts: [PromptRecord],
        now: Date,
        halfLifeDays: Double = defaultHalfLifeDays
    ) -> Double? {
        let past = prompts.filter { $0.scheduledAt <= now }
        guard !past.isEmpty, halfLifeDays > 0 else { return nil }

        var weighted = 0.0
        var total = 0.0
        for prompt in past {
            let elapsedDays = now.timeIntervalSince(prompt.scheduledAt) / 86_400
            let weight = pow(2, -elapsedDays / halfLifeDays)
            total += weight
            if prompt.isCompleted { weighted += weight }
        }

        guard total > 0 else { return nil }
        return weighted / total
    }

    /// R = Σ (1 - xᵢ)·xᵢ₊₁ / Σ (1 - xᵢ)
    ///
    /// With binary x this is a bounce-back rate: of all missed prompts, the share whose next
    /// prompt was completed. The final prompt has no successor, so it belongs in neither sum.
    /// Nil when nothing was missed — a clean record is not 0%.
    static func resilience(prompts: [PromptRecord]) -> Double? {
        let ordered = prompts.sorted { $0.scheduledAt < $1.scheduledAt }
        guard ordered.count > 1 else { return nil }

        var recovered = 0.0
        var missed = 0.0
        for (current, next) in zip(ordered, ordered.dropFirst()) where !current.isCompleted {
            missed += 1
            if next.isCompleted { recovered += 1 }
        }

        guard missed > 0 else { return nil }
        return recovered / missed
    }

    /// Fewer daily samples than this and "usual" would just be last week restated.
    static let minimumUsualMomentumSamples = 14
    static let recentResilienceDays = 90

    /// The mean of M evaluated at the same time of day on every earlier day back to the first
    /// prompt. Momentum already weights toward the present, so its value right now is compared
    /// against what that value has typically been, not against a flat past rate. All of
    /// history rather than a recent window, so a slow stretch never becomes the standard.
    static func usualMomentum(
        prompts: [PromptRecord],
        now: Date,
        halfLifeDays: Double = defaultHalfLifeDays
    ) -> Double? {
        guard let first = prompts.map(\.scheduledAt).min() else { return nil }
        let days = Int(now.timeIntervalSince(first) / 86_400)
        guard days >= 1 else { return nil }

        let samples = (1...days).compactMap { daysAgo in
            momentum(prompts: prompts, now: now.addingTimeInterval(-Double(daysAgo) * 86_400), halfLifeDays: halfLifeDays)
        }
        guard samples.count >= minimumUsualMomentumSamples else { return nil }
        return samples.reduce(0, +) / Double(samples.count)
    }

    /// R split at `days` ago: the recent figure shown, and the earlier one it is judged against.
    /// Over all of history R barely moves once there is a lot of it, so improvement only shows
    /// when the recent stretch stands on its own.
    static func resilienceSplit(
        prompts: [PromptRecord],
        now: Date,
        days: Int = recentResilienceDays
    ) -> (recent: Double?, before: Double?) {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        return (
            resilience(prompts: prompts.filter { $0.scheduledAt >= cutoff && $0.scheduledAt <= now }),
            resilience(prompts: prompts.filter { $0.scheduledAt < cutoff })
        )
    }

    static func stats(
        prompts: [PromptRecord],
        now: Date,
        halfLifeDays: Double = defaultHalfLifeDays
    ) -> AdherenceStats {
        let split = resilienceSplit(prompts: prompts, now: now)
        return AdherenceStats(
            momentum: momentum(prompts: prompts, now: now, halfLifeDays: halfLifeDays),
            resilience: split.recent,
            includesEstimates: prompts.contains(where: \.isEstimated),
            usualMomentum: usualMomentum(prompts: prompts, now: now, halfLifeDays: halfLifeDays),
            resilienceBefore: split.before
        )
    }
}
