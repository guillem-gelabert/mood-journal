import Charts
import SwiftUI

struct MoodByWeekdayChart: View {
    var samples: [WeekdayMoodSample]
    var stats: [WeekdayMoodStat]
    var subtitle: String

    var body: some View {
        ChartPanel(title: "Mood by weekday", subtitle: subtitle) {
            Chart {
                RectangleMark(
                    xStart: .value("Start", 5.5),
                    xEnd: .value("End", 7.5),
                    yStart: .value("Low", -1),
                    yEnd: .value("High", 1)
                )
                .foregroundStyle(Color.journalBand.opacity(0.28))

                ForEach(samples) { sample in
                    PointMark(
                        x: .value("Weekday", sample.jitteredX),
                        y: .value("Valence", sample.valence)
                    )
                    .foregroundStyle(MoodAnalytics.chartClassification(for: sample.valence).color.opacity(0.86))
                    .symbolSize(38)
                }

                ForEach(stats) { stat in
                    RectangleMark(
                        xStart: .value("Start", Double(stat.weekdayIndex) - 0.24),
                        xEnd: .value("End", Double(stat.weekdayIndex) + 0.24),
                        yStart: .value("Mean low", stat.overallMean - 0.006),
                        yEnd: .value("Mean high", stat.overallMean + 0.006)
                    )
                    .foregroundStyle(Color.black)

                    if let recent = stat.recentMean, abs(recent - stat.overallMean) >= 0.03 {
                        RectangleMark(
                            xStart: .value("Arrow x0", Double(stat.weekdayIndex) - 0.018),
                            xEnd: .value("Arrow x1", Double(stat.weekdayIndex) + 0.018),
                            yStart: .value("Overall", stat.overallMean),
                            yEnd: .value("Recent", recent)
                        )
                        .foregroundStyle(Color.black.opacity(0.55))

                        PointMark(
                            x: .value("Weekday", Double(stat.weekdayIndex)),
                            y: .value("Recent", recent)
                        )
                        .foregroundStyle(Color.clear)
                        .annotation(position: recent > stat.overallMean ? .top : .bottom) {
                            Image(systemName: recent > stat.overallMean ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                                .foregroundStyle(Color.journalInk)
                        }
                    }
                }
            }
            .chartXScale(domain: 0.5...7.5)
            .chartYScale(domain: -1...1)
            .chartXAxis {
                AxisMarks(values: Array(1...7)) { value in
                    AxisGridLine().foregroundStyle(Color.journalInk.opacity(0.08))
                    AxisTick()
                    AxisValueLabel {
                        if let index = value.as(Int.self) {
                            Text(MoodAnalytics.weekdayName(for: index))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 260)
        }
    }
}
