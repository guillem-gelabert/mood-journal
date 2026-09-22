import Foundation
import SwiftUI

enum TimeOfDaySlot: String, CaseIterable, Identifiable, Codable {
    case morning = "Morning"
    case midday = "Midday"
    case evening = "Evening"

    var id: String { rawValue }
}

struct DiaryTimeBoundaries: Equatable {
    var morningEndHour = 13
    var middayEndHour = 18

    static let standard = DiaryTimeBoundaries()
}

enum DiaryMoodBucket: String, CaseIterable, Codable {
    case veryGood = "very good"
    case good
    case normal
    case bad
    case veryBad = "very bad"

    var color: Color {
        switch self {
        case .veryGood: Color(hex: "7ecfa0")
        case .good: Color(hex: "5b9e76")
        case .normal: Color(hex: "7a7568")
        case .bad: Color(hex: "c45d4e")
        case .veryBad: Color(hex: "a33038")
        }
    }
}

enum ActivityBucket: String, CaseIterable, Codable {
    case high
    case normal
    case low
}

enum MoodChartClassification: String, CaseIterable, Codable {
    case veryPleasant = "Very Pleasant"
    case pleasant = "Pleasant"
    case slightlyPleasant = "Slightly Pleasant"
    case neutral = "Neutral"
    case slightlyUnpleasant = "Slightly Unpleasant"
    case unpleasant = "Unpleasant"
    case veryUnpleasant = "Very Unpleasant"

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

struct MoodCheckIn: Identifiable, Equatable {
    var id: UUID
    var date: Date
    var valence: Double
    var labels: [String]
    var associations: [String]

    init(id: UUID = UUID(), date: Date, valence: Double, labels: [String] = [], associations: [String] = []) {
        self.id = id
        self.date = date
        self.valence = valence
        self.labels = labels
        self.associations = associations
    }
}

struct DailyEnergy: Identifiable, Equatable {
    var date: Date
    var kilojoules: Double

    var id: Date { date }
}

struct SleepNight: Identifiable, Equatable {
    var date: Date
    var hours: Double

    var id: Date { date }
}

struct DiaryTimeEntry: Identifiable, Equatable {
    var slot: TimeOfDaySlot
    var meanValence: Double?
    var mood: DiaryMoodBucket?

    var id: TimeOfDaySlot { slot }
}

struct DiaryDay: Identifiable, Equatable {
    var date: Date
    var entries: [DiaryTimeEntry]
    var sleepHours: Double?
    var activity: ActivityBucket?
    var autoNotes: String

    var id: Date { date }
}

struct RollingMoodPoint: Identifiable, Equatable {
    var date: Date
    var mean: Double

    var id: Date { date }
}

struct RollingMoodBand: Identifiable, Equatable {
    var date: Date
    var mean: Double
    var standardDeviation: Double

    var id: Date { date }
    var lower: Double { mean - standardDeviation }
    var upper: Double { mean + standardDeviation }
}

struct WeekdayMoodSample: Identifiable, Equatable {
    var id: UUID
    var weekdayIndex: Int
    var jitteredX: Double
    var valence: Double
}

struct WeekdayMoodStat: Identifiable, Equatable {
    var weekdayIndex: Int
    var overallMean: Double
    var recentMean: Double?

    var id: Int { weekdayIndex }
}
