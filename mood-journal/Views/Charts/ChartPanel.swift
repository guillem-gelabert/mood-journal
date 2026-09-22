import SwiftUI

struct ChartPanel<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.title2, design: .serif).italic())
                .foregroundStyle(.journalInk)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Color.journalInk.opacity(0.72))

            content
                .padding(.top, 8)
        }
        .padding(.vertical, 8)
    }
}

struct MoodPointPopover: View {
    var sample: MoodCheckIn

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.dateFormatter.string(from: sample.date))
            Text(MoodAnalytics.chartClassification(for: sample.valence).rawValue)
            Text(String(format: "%.2f", sample.valence))
        }
        .font(.caption2)
        .padding(6)
        .background(Color.journalBackground, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.journalInk.opacity(0.18), lineWidth: 1)
        )
        .foregroundStyle(.journalInk)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
