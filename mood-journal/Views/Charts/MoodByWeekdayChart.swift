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
                        // Shaft and chevron share a stroke and both end exactly on the recent
                        // value, so the head joins the line instead of sitting beside it.
                        RuleMark(
                            x: .value("Weekday", Double(stat.weekdayIndex)),
                            yStart: .value("Overall", stat.overallMean),
                            yEnd: .value("Recent", recent)
                        )
                        .foregroundStyle(Color.journalInk)
                        .lineStyle(Self.arrowStroke)
                        .zIndex(2)

                        PointMark(
                            x: .value("Weekday", Double(stat.weekdayIndex)),
                            y: .value("Recent", recent)
                        )
                        .foregroundStyle(Color.clear)
                        .symbolSize(0)
                        .annotation(position: .overlay, alignment: .center, spacing: 0) {
                            Chevron(pointsUp: recent > stat.overallMean)
                                .stroke(Color.journalInk, style: Self.arrowStroke)
                                .frame(width: Chevron.size, height: Chevron.size)
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

private extension MoodByWeekdayChart {
    static let arrowStroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
}

/// An open arrowhead whose tip is the centre of its frame, so an overlay annotation centred
/// on a point puts the tip exactly on that point.
private struct Chevron: Shape {
    static let size: CGFloat = 16
    var pointsUp: Bool

    func path(in rect: CGRect) -> Path {
        let tip = CGPoint(x: rect.midX, y: rect.midY)
        let reach: CGFloat = 4.5
        let armY = tip.y + (pointsUp ? reach : -reach)
        var path = Path()
        path.move(to: CGPoint(x: tip.x - reach, y: armY))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x + reach, y: armY))
        return path
    }
}
