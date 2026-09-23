import Foundation

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
