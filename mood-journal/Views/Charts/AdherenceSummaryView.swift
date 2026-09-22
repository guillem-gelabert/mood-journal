import SwiftUI

struct AdherenceSummaryView: View {
    var stats: AdherenceStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 32) {
                statBlock(
                    value: stats.momentum,
                    title: "Momentum",
                    caption: "recent prompts answered"
                )
                statBlock(
                    value: stats.resilience,
                    title: "Resilience",
                    caption: "missed, then back on"
                )
            }

            if stats.includesEstimates {
                Text("Includes prompts estimated from your logging history before reminders were tracked.")
                    .font(.caption2)
                    .foregroundStyle(Color.journalInk.opacity(0.55))
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func statBlock(value: Double?, title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                .font(.system(.largeTitle, design: .serif).italic())
                .foregroundStyle(.journalInk)

            Text(title)
                .font(.caption)
                .foregroundStyle(.journalInk)

            Text(value == nil ? "not enough prompts yet" : caption)
                .font(.caption2)
                .foregroundStyle(Color.journalInk.opacity(0.6))
        }
    }
}
