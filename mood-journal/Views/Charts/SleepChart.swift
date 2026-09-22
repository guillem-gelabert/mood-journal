import Charts
import SwiftUI

struct SleepChart: View {
    var nights: [SleepNight]
    var rolling: [SleepNight]
    var domain: ClosedRange<Date>
    var interpolation: InterpolationMethod
    var subtitle: String

    var body: some View {
        ChartPanel(title: "Sleep", subtitle: subtitle) {
            Chart {
                ForEach(nights) { night in
                    BarMark(
                        x: .value("Date", night.date),
                        y: .value("Hours", night.hours)
                    )
                    .foregroundStyle(Color.journalSleep.opacity(0.45))
                }

                ForEach(rolling) { night in
                    LineMark(
                        x: .value("Date", night.date),
                        y: .value("7-day average", night.hours)
                    )
                    .foregroundStyle(Color.journalInk)
                    .lineStyle(.init(lineWidth: 2))
                    .interpolationMethod(interpolation)
                }

                RuleMark(y: .value("Target", 8))
                    .foregroundStyle(Color.journalInk.opacity(0.35))
                    .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
            }
            .chartXScale(domain: domain)
            .chartYScale(domain: 0...yMax)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartYAxisLabel("h", position: .leading)
            .frame(height: 240)
        }
    }

    /// Floored at 10 so a single long night does not rescale the axis into uselessness.
    private var yMax: Double {
        max(10, (nights.map(\.hours).max() ?? 0).rounded(.up))
    }
}
