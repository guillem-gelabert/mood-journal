import Foundation

protocol PromptLogPersisting {
    func load() -> PromptLedgerState?
    func save(_ state: PromptLedgerState)
}

/// A JSON file in Application Support rather than UserDefaults: the ledger grows without
/// bound (three prompts a day is roughly 1100 records a year) and a log is not a preference.
struct FilePromptLogStore: PromptLogPersisting {
    var url: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("prompt-ledger.json")
    }()

    func load() -> PromptLedgerState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PromptLedgerState.self, from: data)
    }

    func save(_ state: PromptLedgerState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
