import SwiftUI

struct LogView: View {
    @Bindable var model: LogEntryModel
    var store: MoodDataStore

    var body: some View {
        NavigationStack {
            ZStack {
                Color.journalBackground.ignoresSafeArea()

                VStack(spacing: 32) {
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

                    Spacer()
                    Spacer()
                }
                .padding(28)
            }
            .navigationTitle("How are you?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(store: store)
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
            .frame(maxWidth: .infinity, minHeight: 26)
        }
        .buttonStyle(.borderedProminent)
        .tint(.journalInk)
        .disabled(model.phase == .saving || model.phase == .saved)
        .sensoryFeedback(.success, trigger: model.phase == .saved)
    }
}
