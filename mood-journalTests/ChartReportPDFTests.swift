import CoreGraphics
import XCTest
@testable import mood_journal

@MainActor
final class ChartReportPDFTests: XCTestCase {
    func testReportRendersTwoPages() throws {
        let url = try render(request(withData: true))
        let document = try XCTUnwrap(CGPDFDocument(url as CFURL))

        XCTAssertEqual(document.numberOfPages, ChartReportPDFRenderer.pageCount)
    }

    func testPagesAreA4() throws {
        let url = try render(request(withData: true))
        let document = try XCTUnwrap(CGPDFDocument(url as CFURL))
        let page = try XCTUnwrap(document.page(at: 1))
        let box = page.getBoxRect(.mediaBox)

        XCTAssertEqual(box.width, ChartReportPDFRenderer.pageSize.width, accuracy: 0.5)
        XCTAssertEqual(box.height, ChartReportPDFRenderer.pageSize.height, accuracy: 0.5)
    }

    func testReportIsNotEmpty() throws {
        let url = try render(request(withData: true))
        let size = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)

        // An empty context still produces a valid but tiny file; real drawing is far larger.
        XCTAssertGreaterThan(size, 5_000)
    }

    func testReportRendersWithNoSamples() throws {
        let url = try render(request(withData: false))
        let document = try XCTUnwrap(CGPDFDocument(url as CFURL))

        XCTAssertEqual(document.numberOfPages, ChartReportPDFRenderer.pageCount)
    }

    func testFilenameCarriesTheDate() {
        let url = ChartReportPDFRenderer.defaultURL(for: Self.date("2026-03-15 12:00"))
        XCTAssertTrue(url.lastPathComponent.contains("2026-03-15"))
        XCTAssertEqual(url.pathExtension, "pdf")
    }

    // MARK: - Helpers

    private func render(_ request: ChartReportRequest) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("report-test-\(UUID().uuidString).pdf")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return try ChartReportPDFRenderer.render(request, to: url)
    }

    private func request(withData: Bool) -> ChartReportRequest {
        let start = Self.date("2026-02-14 00:00")
        let end = Self.date("2026-03-16 00:00")
        let interval = DateInterval(start: start, end: end)

        let snapshot: HealthSnapshot
        if withData {
            let checkIns = (0..<30).map { day in
                MoodCheckIn(
                    date: start.addingTimeInterval(Double(day) * 86_400 + 9 * 3600),
                    valence: sin(Double(day) / 4)
                )
            }
            let energy = (0..<30).map { day in
                DailyEnergy(date: start.addingTimeInterval(Double(day) * 86_400), kilojoules: 1500 + Double(day) * 20)
            }
            let sleep = (0..<30).map { day in
                SleepNight(date: start.addingTimeInterval(Double(day) * 86_400), hours: 7 + Double(day % 3) * 0.5)
            }
            snapshot = HealthSnapshot(moodCheckIns: checkIns, dailyEnergy: energy, sleepNights: sleep)
        } else {
            snapshot = HealthSnapshot(moodCheckIns: [], dailyEnergy: [], sleepNights: [])
        }

        return ChartReportRequest(
            data: MoodAnalytics.derive(snapshot: snapshot, interval: interval, calendar: Self.utc),
            adherence: AdherenceStats(momentum: 0.82, resilience: 0.6, includesEstimates: true),
            generatedAt: Self.date("2026-03-15 12:00")
        )
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)!
    }
}
