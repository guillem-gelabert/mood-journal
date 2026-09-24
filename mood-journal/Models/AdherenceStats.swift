import Foundation

struct AdherenceStats: Equatable {
    /// Half-life weighted completion rate, 0...1. Nil when no prompt has resolved yet.
    var momentum: Double?
    /// Of the prompts missed in the last 90 days, the share whose next prompt was completed,
    /// 0...1. Nil when nothing was missed, which is a perfect record rather than a zero.
    var resilience: Double?
    /// Whether any contributing record was reconstructed rather than observed.
    var includesEstimates: Bool
    /// Your own standard: momentum's mean, sampled daily, over all tracked history.
    var usualMomentum: Double? = nil
    /// Resilience over the prompts before the last 90 days, to tell whether bouncing back
    /// has improved.
    var resilienceBefore: Double? = nil

    static let empty = AdherenceStats(momentum: nil, resilience: nil, includesEstimates: false)

    var hasAnything: Bool { momentum != nil }

    var momentumTrend: AdherenceTrend? { AdherenceTrend(current: momentum, past: usualMomentum) }
    var resilienceTrend: AdherenceTrend? { AdherenceTrend(current: resilience, past: resilienceBefore) }
}

/// Where a metric stands against its own past. Differences under five points read as
/// noise rather than change: one prompt either way moves a month of three-a-day by about one.
enum AdherenceTrend: Equatable {
    case better
    case steady
    case worse

    static let threshold = 0.05

    init?(current: Double?, past: Double?) {
        guard let current, let past else { return nil }
        let delta = current - past
        if delta >= Self.threshold {
            self = .better
        } else if delta <= -Self.threshold {
            self = .worse
        } else {
            self = .steady
        }
    }
}
