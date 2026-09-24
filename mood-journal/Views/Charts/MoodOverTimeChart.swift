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
    /// Off for the PDF: a scrollable chart renders as its viewport, not its content.
    var isInteractive = true
    var height: CGFloat = 280

    /// Nil until the user pinches, so the visible window tracks incoming data instead of
    /// being frozen at whatever the range was on first render.
    @State private var zoomedDays: Double?
    @State private var pinchBaseline: Double?

    private var fullSpanDays: Double {
        max(1, domain.upperBound.timeIntervalSince(domain.lowerBound) / 86_400)
    }

    private var visibleDays: Double {
        min(zoomedDays ?? fullSpanDays, fullSpanDays)
    }

    var body: some View {
        ChartPanel(title: "Mood over time", subtitle: subtitle) {
            chart
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
                .frame(height: height)
                .modifier(PinchZoomX(
                    isEnabled: isInteractive,
                    fullSpanDays: fullSpanDays,
                    visibleDays: visibleDays,
                    zoomedDays: $zoomedDays,
                    pinchBaseline: $pinchBaseline
                ))
        }
    }

    private var chart: some View {
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

            ForEach(checkIns) { sample in
                PointMark(
                    x: .value("Date", sample.date),
                    y: .value("Valence", sample.valence)
                )
                .foregroundStyle(MoodAnalytics.chartClassification(for: sample.valence).color)
                .symbolSize(42)
            }

            // Marks draw in declaration order, so the average goes last to sit on top of the dots.
            ForEach(rolling) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("7-day average", point.mean)
                )
                .foregroundStyle(Color.journalInk)
                .lineStyle(.init(lineWidth: 2))
                .interpolationMethod(interpolation)
            }
        }
    }
}

/// Pinch to narrow the visible x window, between a week and the full span.
///
/// Applied only on screen. The zoom state is optional and the effective window is derived,
/// so it never needs re-seeding when data arrives after the first render.
private struct PinchZoomX: ViewModifier {
    var isEnabled: Bool
    var fullSpanDays: Double
    var visibleDays: Double
    @Binding var zoomedDays: Double?
    @Binding var pinchBaseline: Double?

    func body(content: Content) -> some View {
        if isEnabled && fullSpanDays > 7 {
            content
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: visibleDays * 86_400)
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            let baseline = pinchBaseline ?? visibleDays
                            pinchBaseline = baseline
                            zoomedDays = min(max(baseline / value.magnification, 7), fullSpanDays)
                        }
                        .onEnded { _ in pinchBaseline = nil }
                )
        } else {
            content
        }
    }
}
