import Charts
import SwiftUI

struct ChartsDashboardView: View {
    var store: MoodDataStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ChartRangePicker(range: Binding(
                    get: { store.range },
                    set: { newRange in Task { await store.select(range: newRange) } }
                ))

                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.journalInk.opacity(0.7))
                }

                let data = store.chartData

                MoodOverTimeChart(
                    checkIns: data.checkIns,
                    rolling: data.rollingMood,
                    bands: data.moodBands,
                    monthStarts: data.monthStarts,
                    fifteenthDates: data.fifteenthDates,
                    domain: data.domain,
                    interpolation: data.interpolation,
                    subtitle: "\(data.dateRangeSubtitle) - \(data.checkIns.count) check-ins"
                )

                MoodByWeekdayChart(
                    samples: data.weekdaySamples,
                    stats: data.weekdayStats,
                    subtitle: "\(data.dateRangeSubtitle) - Monday first"
                )

                ActiveEnergyChart(
                    energy: data.dailyEnergy,
                    rolling: data.rollingEnergy,
                    domain: data.domain,
                    interpolation: data.interpolation,
                    subtitle: "\(data.dateRangeSubtitle) - \(data.dailyEnergy.count) days"
                )
            }
            .padding()
        }
        .background(Color.journalBackground)
        .navigationTitle("Charts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
