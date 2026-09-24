import SwiftUI

/// The -1...1 control, drawn rather than a system `Slider`.
///
/// A system slider is UIKit-backed, so its size can only be changed by scaling the whole
/// control, which overflows its container and distorts the thumb. Drawing it gives exact
/// control over the track and thumb, and lets the fill carry the classification colour.
///
/// The whole block, from the mood name down to the end labels, drags the thumb, and so do
/// the screen margins either side of it.
struct ValenceSlider: View {
    @Binding var valence: Double
    /// How far the touch target reaches past the slider's sides, out to the screen edge.
    var horizontalHitSlop: CGFloat = 0

    @State private var width: CGFloat = 0

    private static let trackHeight: CGFloat = 28
    private static let thumbDiameter: CGFloat = 54
    private static let coordinateSpace = "ValenceSlider"

    private var classification: MoodChartClassification {
        MoodChartClassification.classification(for: valence)
    }

    private var usableWidth: CGFloat { max(1, width - Self.thumbDiameter) }

    var body: some View {
        VStack(spacing: 28) {
            Text(classification.rawValue)
                .font(.system(.title, design: .serif).italic())
                .foregroundStyle(classification.color)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.15), value: classification)

            control
        }
        .coordinateSpace(.named(Self.coordinateSpace))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        // An overlay with negative padding grows beyond the slider's bounds without
        // displacing anything around it.
        .overlay {
            Color.clear
                .padding(.horizontal, -horizontalHitSlop)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace))
                        .onChanged { value in
                            let x = value.location.x - Self.thumbDiameter / 2
                            valence = min(max((x / usableWidth) * 2 - 1, -1), 1)
                        }
                )
        }
    }

    private var control: some View {
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
                        .overlay(Circle().strokeBorder(classification.color, lineWidth: 6))
                        .shadow(color: Color.journalInk.opacity(0.2), radius: 4, y: 2)
                        .frame(width: Self.thumbDiameter, height: Self.thumbDiameter)
                        .offset(x: thumbX - Self.thumbDiameter / 2)
                }
                .frame(height: Self.thumbDiameter)
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
                        .frame(width: 2, height: tick == 0 ? 15 : 8)
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
