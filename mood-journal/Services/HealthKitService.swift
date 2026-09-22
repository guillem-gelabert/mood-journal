import Foundation
import HealthKit

enum HealthKitServiceError: LocalizedError {
    case healthDataUnavailable
    case missingType(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            "Health data is not available on this device."
        case .missingType(let type):
            "HealthKit type is unavailable: \(type)."
        case .queryFailed(let message):
            message
        }
    }
}

struct HealthSnapshot {
    var moodCheckIns: [MoodCheckIn]
    var dailyEnergy: [DailyEnergy]
    var sleepNights: [SleepNight]
}

final class HealthKitService {
    let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.healthDataUnavailable
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.stateOfMindType(),
            try quantityType(.activeEnergyBurned),
            try categoryType(.sleepAnalysis)
        ]

        let shareTypes: Set<HKSampleType> = [HKObjectType.stateOfMindType()]
        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    func earliestPermittedSampleDate() -> Date {
        healthStore.earliestPermittedSampleDate()
    }

    func loadSnapshot(from startDate: Date, to endDate: Date, calendar: Calendar = .current) async throws -> HealthSnapshot {
        async let mood = queryStateOfMind(from: startDate, to: endDate)
        async let energy = queryDailyEnergy(from: startDate, to: endDate, calendar: calendar)
        async let sleep = querySleep(from: startDate, to: endDate, calendar: calendar)
        return try await HealthSnapshot(moodCheckIns: mood, dailyEnergy: energy, sleepNights: sleep)
    }

    private func queryStateOfMind(from startDate: Date, to endDate: Date) async throws -> [MoodCheckIn] {
        let type = HKObjectType.stateOfMindType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(error.localizedDescription))
                    return
                }

                let checkIns = (samples as? [HKStateOfMind] ?? [])
                    .filter { $0.kind == .momentaryEmotion }
                    .map {
                        MoodCheckIn(
                            id: $0.uuid,
                            date: $0.startDate,
                            valence: $0.valence,
                            labels: $0.labels.map { Self.humanReadableEnumName(String(describing: $0)) },
                            associations: $0.associations.map { Self.humanReadableEnumName(String(describing: $0)) }
                        )
                    }
                continuation.resume(returning: checkIns)
            }
            healthStore.execute(query)
        }
    }

    private func queryDailyEnergy(from startDate: Date, to endDate: Date, calendar: Calendar) async throws -> [DailyEnergy] {
        let type = try quantityType(.activeEnergyBurned)
        let anchorDate = calendar.startOfDay(for: startDate)
        var interval = DateComponents()
        interval.day = 1

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: []),
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(error.localizedDescription))
                    return
                }

                guard let collection else {
                    continuation.resume(returning: [])
                    return
                }

                let unit = HKUnit.jouleUnit(with: .kilo)
                var result: [DailyEnergy] = []
                collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    if let quantity = statistics.sumQuantity() {
                        result.append(DailyEnergy(date: calendar.startOfDay(for: statistics.startDate), kilojoules: quantity.doubleValue(for: unit)))
                    }
                }
                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }

    private func querySleep(from startDate: Date, to endDate: Date, calendar: Calendar) async throws -> [SleepNight] {
        let type = try categoryType(.sleepAnalysis)
        let queryStart = calendar.date(byAdding: .day, value: -1, to: startDate) ?? startDate
        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: endDate, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(error.localizedDescription))
                    return
                }

                // Collected as intervals rather than summed durations: two sources writing
                // sleep produce overlapping samples, which naive summing counts twice.
                var intervalsByDay: [Date: [DateInterval]] = [:]
                for sample in samples as? [HKCategorySample] ?? [] {
                    guard
                        let value = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                        HKCategoryValueSleepAnalysis.allAsleepValues.contains(value)
                    else {
                        continue
                    }

                    let assignedDay = calendar.startOfDay(for: sample.endDate)
                    guard assignedDay >= calendar.startOfDay(for: startDate) else { continue }
                    guard sample.endDate > sample.startDate else { continue }
                    intervalsByDay[assignedDay, default: []]
                        .append(DateInterval(start: sample.startDate, end: sample.endDate))
                }

                let result = intervalsByDay.keys.sorted().map { day in
                    let seconds = DateIntervalMerging.mergedDuration(of: intervalsByDay[day] ?? [])
                    return SleepNight(date: day, hours: seconds / 3600)
                }
                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }

    private func quantityType(_ identifier: HKQuantityTypeIdentifier) throws -> HKQuantityType {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.missingType(identifier.rawValue)
        }
        return type
    }

    private func categoryType(_ identifier: HKCategoryTypeIdentifier) throws -> HKCategoryType {
        guard let type = HKObjectType.categoryType(forIdentifier: identifier) else {
            throw HealthKitServiceError.missingType(identifier.rawValue)
        }
        return type
    }

    private static func humanReadableEnumName(_ raw: String) -> String {
        let stripped = raw
            .replacingOccurrences(of: "HKStateOfMindAssociation", with: "")
            .replacingOccurrences(of: "HKStateOfMindLabel", with: "")
            .replacingOccurrences(of: "association", with: "")
            .replacingOccurrences(of: "label", with: "")

        let spaced = stripped.reduce(into: "") { result, character in
            if character.isUppercase, !result.isEmpty {
                result.append(" ")
            }
            result.append(character)
        }

        return spaced
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
    }
}
