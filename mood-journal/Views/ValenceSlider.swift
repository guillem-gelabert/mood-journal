import SwiftUI

/// The -1...1 control, drawn rather than a system `Slider`.
///
/// A system slider is UIKit-backed, so its size can only be changed by scaling the whole
/// control, which overflows its container and distorts the thumb. Drawing it gives exact
/// control over the track and thumb, and lets the fill carry the classification colour.
struct ValenceSlider: View {
    @Binding var valence: Double

    private static let trackHeight: CGFloat = 16
    private static let thumbDiameter: CGFloat = 40

    private var classification: MoodChartClassification {
        MoodAnalytics.chartClassification(for: valence)
    }

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { geometry in
                let usable = max(1, geometry.size.width - Self.thumbDiameter)
                let fraction = (valence + 1) / 2
                let thumbX = Self.thumbDiameter / 2 + usable * fraction

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.journalInk.opacity(0.12))
                        .frame(height: Self.trackHeight)

                    Capsule()
                        .fill(classification.color)
                        .frame(width: thumbX, height: Self.trackHeight)

                    Circle()
                        .fill(Color.journalBackground)
                        .overlay(Circle().strokeBorder(classification.color, lineWidth: 4))
                        .shadow(color: Color.journalInk.opacity(0.18), radius: 3, y: 1)
                        .frame(width: Self.thumbDiameter, height: Self.thumbDiameter)
                        .offset(x: thumbX - Self.thumbDiameter / 2)
                }
                .frame(height: Self.thumbDiameter)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = value.location.x - Self.thumbDiameter / 2
                            valence = min(max((x / usable) * 2 - 1, -1), 1)
                        }
                )
            }
            .frame(height: Self.thumbDiameter)
            .accessibilityElement()
            .accessibilityLabel("Mood")
            .accessibilityValue(classification.rawValue)
            .accessibilityAdjustableAction { direction in
                let step = 0.1
                switch direction {
                case .increment: valence = min(valence + step, 1)
                case .decrement: valence = max(valence - step, -1)
                default: break
                }
            }

            HStack {
                ForEach(Self.tickValues, id: \.self) { tick in
                    Rectangle()
                        .fill(Color.journalInk.opacity(tick == 0 ? 0.32 : 0.16))
                        .frame(width: 1.5, height: tick == 0 ? 13 : 7)
                    if tick != Self.tickValues.last { Spacer(minLength: 0) }
                }
            }
            .padding(.horizontal, Self.thumbDiameter / 2)

            HStack {
                Text("Very Unpleasant")
                Spacer()
                Text("Very Pleasant")
            }
            .font(.caption)
            .foregroundStyle(.journalInk.opacity(0.6))
        }
    }

    private static let tickValues: [Double] = [-1, -0.6, -0.3, 0, 0.3, 0.6, 1]
}
