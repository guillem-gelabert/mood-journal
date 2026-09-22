import SwiftUI

struct LogView: View {
    @Bindable var model: LogEntryModel
    var store: MoodDataStore
    var reminders: RemindersModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.journalBackground.ignoresSafeArea()
                LogControls(model: model)
            }
            .navigationTitle("How are you?")
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
        .task { await model.prepare() }
    }
}

/// The log screen's content, separate from its navigation shell so it can be rendered on its
/// own — NavigationStack is UIKit-backed and rasterises as a placeholder.
struct LogControls: View {
    @Bindable var model: LogEntryModel

    var body: some View {
        // Weighted to the bottom of the screen: the slider is the one control you drag with
        // a thumb, so it sits inside easy reach rather than mid-screen.
        VStack(spacing: 28) {
            Spacer()

            Text(model.classification.rawValue)
                .font(.system(.title, design: .serif).italic())
                .foregroundStyle(model.classification.color)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.15), value: model.classification)

            ValenceSlider(valence: $model.valence)

            logButton

            if case .failed(let message) = model.phase {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.journalInk.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .onTapGesture { model.dismissFailure() }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    private var logButton: some View {
        Button {
            Task { await model.save() }
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
