import Foundation

/// One reminder prompt whose completion window has closed, and whether a mood was logged
/// inside it. Prompts still inside their window are not recorded at all: counting them as
/// missed would drag Momentum down every morning before you have had a chance to answer.
struct PromptRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var scheduledAt: Date
    var isCompleted: Bool
    /// True for records reconstructed on first run rather than observed as they happened.
    var isEstimated: Bool

    init(id: UUID = UUID(), scheduledAt: Date, isCompleted: Bool, isEstimated: Bool = false) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.isCompleted = isCompleted
        self.isEstimated = isEstimated
    }
}

struct PromptLedgerState: Codable, Equatable {
    var records: [PromptRecord] = []
    /// Everything up to here has been materialised, so a later run does not duplicate it.
    var materialisedThrough: Date?
    var didBackfill = false
}
