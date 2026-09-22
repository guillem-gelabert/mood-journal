import Charts
import SwiftUI

struct MoodByWeekdayChart: View {
    var samples: [WeekdayMoodSample]
    var stats: [WeekdayMoodStat]
    var subtitle: String
    var height: CGFloat = 260

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
                    .zIndex(0)
                }

                ForEach(stats) { stat in
                    RectangleMark(
                        xStart: .value("Start", Double(stat.weekdayIndex) - 0.24),
                        xEnd: .value("End", Double(stat.weekdayIndex) + 0.24),
                        yStart: .value("Mean low", stat.overallMean - 0.006),
                        yEnd: .value("Mean high", stat.overallMean + 0.006)
                    )
                    .foregroundStyle(Color.journalInk)
                    .zIndex(1)

                    if let recent = stat.recentMean, abs(recent - stat.overallMean) >= 0.03 {
                        // The shaft stops short of the recent value so the head, drawn as an
                        // overlay centred there, completes the arrow instead of floating past it.
                        RectangleMark(
                            xStart: .value("Arrow x0", Double(stat.weekdayIndex) - 0.018),
                            xEnd: .value("Arrow x1", Double(stat.weekdayIndex) + 0.018),
                            yStart: .value("Overall", stat.overallMean),
                            yEnd: .value("Recent", recent + (recent > stat.overallMean ? -0.035 : 0.035))
                        )
                        .foregroundStyle(Color.journalInk)
                        .zIndex(2)

                        PointMark(
                            x: .value("Weekday", Double(stat.weekdayIndex)),
                            y: .value("Recent", recent)
                        )
                        .foregroundStyle(Color.clear)
                        .symbolSize(0)
                        .annotation(position: .overlay, alignment: .center, spacing: 0) {
                            Image(systemName: recent > stat.overallMean ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.journalInk)
                        }
                        .zIndex(3)
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
            .frame(height: height)
        }
    }
}
