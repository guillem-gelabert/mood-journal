import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = MoodDataStore()
    @State private var logEntry = LogEntryModel()

    var body: some View {
        LogView(model: logEntry, store: store)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await store.refreshOnForeground() }
                }
            }
    }
}
