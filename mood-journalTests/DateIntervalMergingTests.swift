import XCTest
@testable import mood_journal

final class DateIntervalMergingTests: XCTestCase {
    func testEmptyIsZero() {
        XCTAssertEqual(DateIntervalMerging.mergedDuration(of: []), 0)
    }

    func testSingleIntervalIsItsOwnDuration() {
        XCTAssertEqual(DateIntervalMerging.mergedDuration(of: [Self.hours(0, 8)]), 8 * 3600)
    }

    func testDisjointIntervalsSum() {
        let merged = DateIntervalMerging.mergedDuration(of: [Self.hours(0, 3), Self.hours(5, 7)])
        XCTAssertEqual(merged, 5 * 3600)
    }

    /// The case that motivated this: a watch and a phone both recording the same night.
    func testIdenticalIntervalsCountOnce() {
        let merged = DateIntervalMerging.mergedDuration(of: [Self.hours(0, 8), Self.hours(0, 8)])
        XCTAssertEqual(merged, 8 * 3600)
    }

    func testOverlappingIntervalsCountTheUnion() {
        let merged = DateIntervalMerging.mergedDuration(of: [Self.hours(0, 5), Self.hours(3, 9)])
        XCTAssertEqual(merged, 9 * 3600)
    }

    func testNestedIntervalCountsOnlyTheOuter() {
        let merged = DateIntervalMerging.mergedDuration(of: [Self.hours(0, 10), Self.hours(2, 4)])
        XCTAssertEqual(merged, 10 * 3600)
    }

    func testTouchingIntervalsCoalesce() {
        let merged = DateIntervalMerging.mergedDuration(of: [Self.hours(0, 4), Self.hours(4, 6)])
        XCTAssertEqual(merged, 6 * 3600)
    }

    func testUnsortedInputIsHandled() {
        let merged = DateIntervalMerging.mergedDuration(of: [Self.hours(6, 9), Self.hours(0, 5), Self.hours(4, 7)])
        XCTAssertEqual(merged, 9 * 3600)
    }

    private static func hours(_ start: Double, _ end: Double) -> DateInterval {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        return DateInterval(
            start: base.addingTimeInterval(start * 3600),
            end: base.addingTimeInterval(end * 3600)
        )
    }
}
