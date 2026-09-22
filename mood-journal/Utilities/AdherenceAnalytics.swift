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

    static func stats(
        prompts: [PromptRecord],
        now: Date,
        halfLifeDays: Double = defaultHalfLifeDays
    ) -> AdherenceStats {
        AdherenceStats(
            momentum: momentum(prompts: prompts, now: now, halfLifeDays: halfLifeDays),
            resilience: resilience(prompts: prompts),
            includesEstimates: prompts.contains(where: \.isEstimated)
        )
    }
}
