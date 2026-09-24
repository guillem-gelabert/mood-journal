import SwiftUI

struct AdherenceSummaryView: View {
    var stats: AdherenceStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 32) {
                statBlock(
                    value: stats.momentum,
                    title: "Momentum",
                    caption: "recent prompts answered",
                    trend: stats.momentumTrend,
                    comparison: stats.usualMomentum.map { "usually \(Self.percent($0))" }
                )
                statBlock(
                    value: stats.resilience,
                    title: "Resilience",
                    caption: "missed, then back on · 90 days",
                    emptyCaption: stats.hasAnything ? "nothing missed lately" : nil,
                    trend: stats.resilienceTrend,
                    comparison: stats.resilienceBefore.map { "\(Self.percent($0)) before" }
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
    private func statBlock(
        value: Double?,
        title: String,
        caption: String,
        emptyCaption: String? = nil,
        trend: AdherenceTrend?,
        comparison: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.map(Self.percent) ?? "—")
                .font(.system(.largeTitle, design: .serif).italic())
                .foregroundStyle(trend.map(Self.color) ?? .journalInk)

            Text(title)
                .font(.caption)
                .foregroundStyle(.journalInk)

            Text(value == nil ? emptyCaption ?? "not enough prompts yet" : caption)
                .font(.caption2)
                .foregroundStyle(Color.journalInk.opacity(0.6))

            // The colour is never the only signal: the comparison says it in words too.
            if let trend, let comparison {
                Text("\(Self.symbol(trend)) \(comparison)")
                    .font(.caption2)
                    .foregroundStyle(Self.color(trend))
            }
        }
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func color(_ trend: AdherenceTrend) -> Color {
        switch trend {
        case .better: .journalTrendBetter
        case .steady: .journalTrendSteady
        case .worse: .journalTrendWorse
        }
    }

    private static func symbol(_ trend: AdherenceTrend) -> String {
        switch trend {
        case .better: "↑"
        case .steady: "≈"
        case .worse: "↓"
        }
    }
}
