import CoreGraphics
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ChartReportRequest {
    var data: ChartData
    var adherence: AdherenceStats
    var generatedAt: Date
}

enum ChartReportError: LocalizedError {
    case contextUnavailable

    var errorDescription: String? {
        switch self {
        case .contextUnavailable: "Could not start a PDF document."
        }
    }
}

@MainActor
enum ChartReportPDFRenderer {
    /// A4 in points. A4 rather than US Letter given where this app is used.
    static let pageSize = CGSize(width: 595.2, height: 841.8)
    static let margin: CGFloat = 36
    static let pageCount = 2

    static func render(_ request: ChartReportRequest, to url: URL) throws -> URL {
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard
            let consumer = CGDataConsumer(url: url as CFURL),
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            throw ChartReportError.contextUnavailable
        }

        draw(page(1, for: request), into: context)
        draw(page(2, for: request), into: context)
        context.closePDF()

        return url
    }

    static func defaultURL(for date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // The share sheet shows the filename, so it is named for the reader, not for us.
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("Mood Journal \(formatter.string(from: date)).pdf")
    }

    private static func draw(_ view: some View, into context: CGContext) {
        // Forced light: the palette is light-only and a viewer's dark mode would otherwise
        // leak a black background into the document.
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.proposedSize = ProposedViewSize(pageSize)

        renderer.render(rasterizationScale: 1) { size, draw in
            context.beginPDFPage(nil)
            context.translateBy(x: 0, y: pageSize.height - size.height)
            draw(context)
            context.endPDFPage()
        }
    }

    @ViewBuilder
    private static func page(_ number: Int, for request: ChartReportRequest) -> some View {
        let data = request.data
        let subtitle = "\(data.dateRangeSubtitle) - \(data.checkIns.count) check-ins"

        if number == 1 {
            ChartReportPage(
                title: "Mood Journal",
                subtitle: subtitle,
                pageNumber: 1,
                pageCount: pageCount,
                size: pageSize,
                margin: margin
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    if request.adherence.hasAnything {
                        AdherenceSummaryView(stats: request.adherence)
                    }

                    MoodOverTimeChart(
                        checkIns: data.checkIns,
                        rolling: data.rollingMood,
                        bands: data.moodBands,
                        monthStarts: data.monthStarts,
                        fifteenthDates: data.fifteenthDates,
                        domain: data.domain,
                        interpolation: data.interpolation,
                        subtitle: subtitle,
                        isInteractive: false,
                        height: 230
                    )

                    MoodByWeekdayChart(
                        samples: data.weekdaySamples,
                        stats: data.weekdayStats,
                        subtitle: "Monday first",
                        height: 210
                    )
                }
            }
        } else {
            ChartReportPage(
                title: "Activity and sleep",
                subtitle: subtitle,
                pageNumber: 2,
                pageCount: pageCount,
                size: pageSize,
                margin: margin
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    ActiveEnergyChart(
                        energy: data.dailyEnergy,
                        rolling: data.rollingEnergy,
                        domain: data.domain,
                        interpolation: data.interpolation,
                        subtitle: "\(data.dailyEnergy.count) days",
                        height: 250
                    )

                    SleepChart(
                        nights: data.sleepNights,
                        rolling: data.rollingSleep,
                        domain: data.domain,
                        interpolation: data.interpolation,
                        subtitle: "\(data.sleepNights.count) nights",
                        height: 250
                    )
                }
            }
        }
    }
}
