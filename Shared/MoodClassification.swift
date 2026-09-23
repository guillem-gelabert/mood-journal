import SwiftUI

/// How HealthKit buckets a valence, mirrored here so the pure layer stays free of HealthKit.
///
/// The cutoffs are pinned against `HKStateOfMind.ValenceClassification` by a parity test.
/// Shared between the phone and the watch so there is only ever one copy of them.
enum MoodChartClassification: String, CaseIterable, Codable {
    case veryPleasant = "Very Pleasant"
    case pleasant = "Pleasant"
    case slightlyPleasant = "Slightly Pleasant"
    case neutral = "Neutral"
    case slightlyUnpleasant = "Slightly Unpleasant"
    case unpleasant = "Unpleasant"
    case veryUnpleasant = "Very Unpleasant"

    static func classification(for valence: Double) -> MoodChartClassification {
        if valence > 0.6 { return .veryPleasant }
        if valence >= 0.3 { return .pleasant }
        if valence >= 0.1 { return .slightlyPleasant }
        if valence >= -0.1 { return .neutral }
        if valence >= -0.3 { return .slightlyUnpleasant }
        if valence >= -0.6 { return .unpleasant }
        return .veryUnpleasant
    }

    var color: Color {
        switch self {
        case .veryPleasant: Color(hex: "7ecfa0")
        case .pleasant: Color(hex: "5b9e76")
        case .slightlyPleasant: Color(hex: "8a9a72")
        case .neutral: Color(hex: "7a7568")
        case .slightlyUnpleasant: Color(hex: "b8865a")
        case .unpleasant: Color(hex: "c45d4e")
        case .veryUnpleasant: Color(hex: "a33038")
        }
    }
}
