import SwiftUI

/// The -1...1 control. Continuous, matching HealthKit's valence scale; the seven tick marks
/// are the classification boundaries, shown for orientation rather than as snap points.
struct ValenceSlider: View {
    @Binding var valence: Double

    var body: some View {
        VStack(spacing: 10) {
            Slider(value: $valence, in: -1...1)
                .tint(MoodAnalytics.chartClassification(for: valence).color)

            HStack {
                ForEach(Self.tickValues, id: \.self) { tick in
                    Rectangle()
                        .fill(Color.journalInk.opacity(tick == 0 ? 0.32 : 0.16))
                        .frame(width: 1, height: tick == 0 ? 9 : 5)
                    if tick != Self.tickValues.last { Spacer(minLength: 0) }
                }
            }
            .padding(.horizontal, 10)

            HStack {
                Text("Very Unpleasant")
                Spacer()
                Text("Very Pleasant")
            }
            .font(.caption2)
            .foregroundStyle(.journalInk.opacity(0.6))
        }
    }

    private static let tickValues: [Double] = [-1, -0.6, -0.3, 0, 0.3, 0.6, 1]
}
