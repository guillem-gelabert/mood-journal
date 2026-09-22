import Foundation

enum DateIntervalMerging {
    /// Total time covered by `intervals`, counting overlaps once.
    ///
    /// Sleep samples from two sources (a watch and a phone, or a third-party tracker)
    /// overlap, and summing their durations naively inflates the night.
    static func mergedDuration(of intervals: [DateInterval]) -> TimeInterval {
        guard !intervals.isEmpty else { return 0 }

        let sorted = intervals.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var current = sorted[0]

        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                total += current.duration
                current = interval
            }
        }

        return total + current.duration
    }
}
