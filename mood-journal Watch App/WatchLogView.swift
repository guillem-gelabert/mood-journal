import SwiftUI

struct WatchLogView: View {
    @State private var model = LogEntryModel()
    /// The Crown reports its own value; the model owns the committed one.
    @State private var crownValue: Double = 0
    @FocusState private var isCrownFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(model.classification.rawValue)
                .font(.headline)
                .foregroundStyle(model.classification.color)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            ValenceDial(valence: model.valence, color: model.classification.color)

            Button(action: { Task { await model.save() } }) {
                switch model.phase {
                case .saved: Label("Logged", systemImage: "checkmark")
                case .saving: ProgressView()
                default: Text("Log")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(model.classification.color)
            .disabled(model.phase == .saving || model.phase == .saved)

            if case .failed(let message) = model.phase {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 4)
        // The Crown is the control: precise, one-handed, and it leaves the small screen
        // unobscured by a finger.
        .focusable()
        .focused($isCrownFocused)
        .digitalCrownRotation(
            $crownValue,
            from: -1,
            through: 1,
            by: 0.05,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in model.valence = newValue }
        .onChange(of: model.valence) { _, newValue in
            // Keeps the Crown in step when the model resets itself after a save.
            if abs(newValue - crownValue) > 0.001 { crownValue = newValue }
        }
        .sensoryFeedback(.success, trigger: model.phase == .saved)
        .task {
            isCrownFocused = true
            await model.prepare()
        }
    }
}

/// A compact arc showing where the valence sits, in place of a slider: a 40pt thumb would
/// take most of a 45mm screen.
private struct ValenceDial: View {
    var valence: Double
    var color: Color

    private var fraction: Double { (valence + 1) / 2 }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.gray.opacity(0.25))
                Capsule()
                    .fill(color)
                    .frame(width: max(4, width * fraction))
            }
        }
        .frame(height: 10)
        .overlay(alignment: .bottom) {
            Text(String(format: "%+.2f", valence))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .offset(y: 16)
        }
        .padding(.bottom, 16)
    }
}
