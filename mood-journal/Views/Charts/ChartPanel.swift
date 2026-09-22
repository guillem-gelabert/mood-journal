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
