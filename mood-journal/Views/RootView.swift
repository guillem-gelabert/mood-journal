import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = MoodDataStore()
    @State private var logEntry = LogEntryModel()
    @State private var reminders = RemindersModel()
    @State private var today = TodayModel()
    private let router = NotificationRouter.shared

    var body: some View {
        LogView(model: logEntry, today: today, store: store, reminders: reminders)
            .task {
                await reminders.start()
                await today.refresh(reminders: reminders.reminders)
                await store.updateAdherence(reminders: reminders.reminders)
            }
            .onChange(of: router.hasPendingTap, initial: true) {
                if router.consumeTap() { today.openFromReminder() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    Task { await store.refreshOnForeground() }
                    Task {
                        await reminders.refreshAuthorization()
                        await today.refresh(reminders: reminders.reminders)
                        await store.updateAdherence(reminders: reminders.reminders)
                    }
                case .background:
                    today.reset()
                default:
                    break
                }
            }
    }
}
