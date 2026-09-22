import Charts
import SwiftUI

struct ChartsDashboardView: View {
    @ObservedObject var viewModel: MoodJournalViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    MoodOverTimeChart(
                        checkIns: viewModel.checkIns,
                        rolling: viewModel.rollingMood,
                        bands: viewModel.moodBands,
                        monthStarts: viewModel.monthStarts,
                        fifteenthDates: viewModel.fifteenthDates,
                        subtitle: "\(viewModel.dateRangeSubtitle) - \(viewModel.checkIns.count) check-ins"
                    )

                    MoodByWeekdayChart(
                        samples: viewModel.weekdaySamples,
                        stats: viewModel.weekdayStats,
                        subtitle: "\(viewModel.dateRangeSubtitle) - Monday first"
                    )

                    ActiveEnergyChart(
                        energy: viewModel.dailyEnergy,
                        rolling: viewModel.rollingEnergy,
                        subtitle: "\(viewModel.dateRangeSubtitle) - \(viewModel.dailyEnergy.count) days"
                    )
                }
                .padding()
            }
            .background(Color.journalBackground)
            .navigationTitle("Mood Journal")
        }
    }
}

private struct MoodOverTimeChart: View {
    var checkIns: [MoodCheckIn]
    var rolling: [RollingMoodPoint]
    var bands: [RollingMoodBand]
    var monthStarts: [Date]
    var fifteenthDates: [Date]
    var subtitle: String

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
                    .interpolationMethod(.catmullRom)
                }

                ForEach(rolling) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("7-day average", point.mean)
                    )
                    .foregroundStyle(Color.journalInk)
                    .lineStyle(.init(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
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
            .frame(height: 280)
            .scrollZoomX(earliest: checkIns.first?.date ?? Date(), latest: checkIns.last?.date ?? Date())
        }
    }

    private func nearestSample(to date: Date) -> MoodCheckIn? {
        checkIns.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }
}

private struct MoodByWeekdayChart: View {
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

private struct ActiveEnergyChart: View {
    var energy: [DailyEnergy]
    var rolling: [DailyEnergy]
    var subtitle: String

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
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 240)
            .scrollZoomX(earliest: energy.first?.date ?? Date(), latest: energy.last?.date ?? Date())
        }
    }
}

private struct ChartPanel<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.title2, design: .serif).italic())
                .foregroundStyle(.journalInk)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Color.journalInk.opacity(0.72))

            content
                .padding(.top, 8)
        }
        .padding(.vertical, 8)
    }
}

private struct MoodPointPopover: View {
    var sample: MoodCheckIn

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.dateFormatter.string(from: sample.date))
            Text(MoodAnalytics.chartClassification(for: sample.valence).rawValue)
            Text(String(format: "%.2f", sample.valence))
        }
        .font(.caption2)
        .padding(6)
        .background(Color.journalBackground, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.journalInk.opacity(0.18), lineWidth: 1)
        )
        .foregroundStyle(.journalInk)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

/// Makes a time-series chart's x-axis horizontally scrollable and pinch-zoomable.
/// The visible window defaults to ~30 days (clamped to the data's full span) and
/// opens anchored to the most recent date. Pinch adjusts the window between 7 days
/// and the full range.
private struct ScrollZoomX: ViewModifier {
    private let earliest: Date
    private let latest: Date
    @State private var visibleDays: Double
    @State private var pinchBaseline: Double
    @State private var scrollPosition: Date

    init(earliest: Date, latest: Date) {
        self.earliest = earliest
        self.latest = latest
        let fullSpanDays = max(1, latest.timeIntervalSince(earliest) / 86_400)
        let initial = min(30, fullSpanDays)
        _visibleDays = State(initialValue: initial)
        _pinchBaseline = State(initialValue: initial)
        _scrollPosition = State(initialValue: latest.addingTimeInterval(-initial * 86_400))
    }

    private var fullSpanDays: Double {
        max(1, latest.timeIntervalSince(earliest) / 86_400)
    }

    func body(content: Content) -> some View {
        content
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleDays * 86_400)
            .chartScrollPosition(x: $scrollPosition)
            // Two-finger pinch zooms the horizontal (time) axis only; the y-axis
            // stays fixed. simultaneousGesture lets the pinch run alongside the
            // horizontal scroll instead of being swallowed by the scroll container.
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        visibleDays = min(max(pinchBaseline / value.magnification, 7), fullSpanDays)
                    }
                    .onEnded { _ in pinchBaseline = visibleDays }
            )
    }
}

private extension View {
    func scrollZoomX(earliest: Date, latest: Date) -> some View {
        modifier(ScrollZoomX(earliest: earliest, latest: latest))
    }
}
