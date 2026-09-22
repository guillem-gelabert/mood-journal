import Charts
import SwiftUI

struct MoodOverTimeChart: View {
    var checkIns: [MoodCheckIn]
    var rolling: [RollingMoodPoint]
    var bands: [RollingMoodBand]
    var monthStarts: [Date]
    var fifteenthDates: [Date]
    var domain: ClosedRange<Date>
    var interpolation: InterpolationMethod
    var subtitle: String
    var isInteractive = true
    var height: CGFloat = 280

    @State private var selected: MoodCheckIn?

    var body: some View {
        ChartPanel(title: "Mood over time", subtitle: subtitle) {
            Chart {
                ForEach(bands) { band in
                    AreaMark(
                        x: .value("Date", band.date),
                        yStart: .value("Lower", max(-1, band.lower)),
                        yEnd: .value("Upper", min(1, band.upper))
                    )
                    .foregroundStyle(Color.journalBand.opacity(0.65))
                    .interpolationMethod(interpolation)
                }

                ForEach(rolling) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("7-day average", point.mean)
                    )
                    .foregroundStyle(Color.journalInk)
                    .lineStyle(.init(lineWidth: 2))
                    .interpolationMethod(interpolation)
                }

                ForEach(checkIns) { sample in
                    PointMark(
                        x: .value("Date", sample.date),
                        y: .value("Valence", sample.valence)
                    )
                    .foregroundStyle(MoodAnalytics.chartClassification(for: sample.valence).color)
                    .symbolSize(selected?.id == sample.id ? 90 : 42)
                    .annotation(position: .top) {
                        if selected?.id == sample.id {
                            MoodPointPopover(sample: sample)
                        }
                    }
                }
            }
            .chartXScale(domain: domain)
            .chartYScale(domain: -1...1)
            .chartXAxis {
                AxisMarks(values: monthStarts) {
                    AxisGridLine().foregroundStyle(Color.journalInk.opacity(0.22))
                    AxisTick().foregroundStyle(Color.journalInk.opacity(0.5))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
                AxisMarks(values: fifteenthDates) {
                    AxisGridLine().foregroundStyle(Color.journalInk.opacity(0.10))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartOverlay { proxy in
                if isInteractive {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture()
                                    .onEnded { value in
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let origin = geometry[plotFrame].origin
                                        let x = value.location.x - origin.x
                                        guard let date = proxy.value(atX: x, as: Date.self) else { return }
                                        selected = nearestSample(to: date)
                                    }
                            )
                    }
                }
            }
            .frame(height: height)
        }
    }

    private func nearestSample(to date: Date) -> MoodCheckIn? {
        checkIns.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }
}
