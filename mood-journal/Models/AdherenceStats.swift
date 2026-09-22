import Foundation

struct AdherenceStats: Equatable {
    /// Half-life weighted completion rate, 0...1. Nil when no prompt has resolved yet.
    var momentum: Double?
    /// Of all missed prompts, the share whose next prompt was completed, 0...1.
    /// Nil when nothing has been missed, which is a perfect record rather than a zero.
    var resilience: Double?
    /// Whether any contributing record was reconstructed rather than observed.
    var includesEstimates: Bool

    static let empty = AdherenceStats(momentum: nil, resilience: nil, includesEstimates: false)

    var hasAnything: Bool { momentum != nil }
}
