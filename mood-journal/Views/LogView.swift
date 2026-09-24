import SwiftUI

struct LogView: View {
    @Bindable var model: LogEntryModel
    var today: TodayModel
    var store: MoodDataStore
    var reminders: RemindersModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.journalBackground.ignoresSafeArea()
                if today.screen != .deciding {
                    TodaySummary(today: today) { today.startLogging() }
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(store: store, reminders: reminders)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .tint(.journalInk)
        .font(.system(.body, design: .monospaced))
        .sheet(isPresented: isLogging) {
            LogSheet(model: model) {
                Task { await today.didLog(reminders: reminders.reminders) }
            }
        }
        .task { await model.prepare() }
    }

    /// Swiping the sheet away or tapping close backs out without logging.
    private var isLogging: Binding<Bool> {
        Binding(
            get: { today.screen == .log },
            set: { if !$0 { today.cancelLogging() } }
        )
    }
}

/// "How are you?" as a modal over Today, so Log now can be backed out of.
private struct LogSheet: View {
    @Bindable var model: LogEntryModel
    var onLogged: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.journalBackground.ignoresSafeArea()
                LogControls(model: model, onLogged: onLogged)
            }
            .navigationTitle("How are you?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .tint(.journalInk)
        .font(.system(.body, design: .monospaced))
        // A half-finished drag should not be lost to an accidental swipe.
        .interactiveDismissDisabled(model.phase == .saving)
    }
}

/// The log screen's content, separate from its navigation shell so it can be rendered on its
/// own — NavigationStack is UIKit-backed and rasterises as a placeholder.
struct LogControls: View {
    @Bindable var model: LogEntryModel
    /// Runs once the confirmation has shown after a successful save.
    var onLogged: () -> Void = {}

    var body: some View {
        // Weighted to the bottom of the screen: the slider is the one control you drag with
        // a thumb, so it sits inside easy reach rather than mid-screen.
        VStack(spacing: 28) {
            Spacer()

            ValenceSlider(valence: $model.valence, horizontalHitSlop: Self.sideMargin)

            logButton

            if case .failed(let message) = model.phase {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.journalInk.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .onTapGesture { model.dismissFailure() }
            }
        }
        .padding(.horizontal, Self.sideMargin)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    private static let sideMargin: CGFloat = 28

    private var logButton: some View {
        Button {
            Task {
                if await model.save() { onLogged() }
            }
        } label: {
            Group {
                switch model.phase {
                case .saved:
                    Label("Logged", systemImage: "checkmark")
                case .saving:
                    ProgressView()
                default:
                    Text("Log")
                }
            }
            .font(.system(.title3, design: .monospaced).weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.journalInk)
        .disabled(model.phase == .saving || model.phase == .saved)
        .sensoryFeedback(.success, trigger: model.phase == .saved)
    }
}
