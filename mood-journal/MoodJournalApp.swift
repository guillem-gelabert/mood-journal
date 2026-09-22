import SwiftData
import SwiftUI

@main
struct MoodJournalApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: DiaryNote.self)
    }
}
