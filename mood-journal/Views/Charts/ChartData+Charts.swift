import Charts

extension ChartData {
    /// Catmull-rom invents confident curves through multi-week gaps, which at a year's range
    /// reads as data that is not there.
    var interpolation: InterpolationMethod {
        dayCount > 90 ? .linear : .catmullRom
    }
}
