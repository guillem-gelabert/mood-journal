import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = MoodDataStore()
    @State private var logEntry = LogEntryModel()
    @State private var reminders = RemindersModel()

    var body: some View {
        LogView(model: logEntry, store: store, reminders: reminders)
            .task {
                await reminders.start()
                await store.updateAdherence(reminders: reminders.reminders)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await store.refreshOnForeground() }
                    Task {
                        await reminders.refreshAuthorization()
                        await store.updateAdherence(reminders: reminders.reminders)
                    }
                }
            }
    }
}
