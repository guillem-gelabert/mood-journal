import Charts
import SwiftUI

struct ActiveEnergyChart: View {
    var energy: [DailyEnergy]
    var rolling: [DailyEnergy]
    var domain: ClosedRange<Date>
    var interpolation: InterpolationMethod
    var subtitle: String
    var height: CGFloat = 240

    var body: some View {
        ChartPanel(title: "Active energy", subtitle: subtitle) {
            Chart {
                ForEach(energy) { day in
                    BarMark(
                        x: .value("Date", day.date),
                        y: .value("kJ", day.kilojoules)
                    )
                    .foregroundStyle(Color.journalEnergy.opacity(0.45))
                }

                ForEach(rolling) { day in
                    LineMark(
                        x: .value("Date", day.date),
                        y: .value("7-day average", day.kilojoules)
                    )
                    .foregroundStyle(Color.journalInk)
                    .lineStyle(.init(lineWidth: 2))
                    .interpolationMethod(interpolation)
                }
            }
            .chartXScale(domain: domain)
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxisLabel("kJ", position: .leading)
            .frame(height: height)
        }
    }
}
