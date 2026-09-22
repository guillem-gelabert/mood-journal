import SwiftUI

/// A fixed-size page for the PDF. Deliberately not a ScrollView: ImageRenderer captures only
/// a scroll view's visible viewport, so scrolled content would silently render as a slice.
struct ChartReportPage<Content: View>: View {
    var title: String
    var subtitle: String
    var pageNumber: Int
    var pageCount: Int
    var size: CGSize
    var margin: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 22, design: .serif).italic())
                    .foregroundStyle(.journalInk)
                Text(subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.journalInk.opacity(0.7))
            }

            content

            Spacer(minLength: 0)

            Text("Page \(pageNumber) of \(pageCount)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.journalInk.opacity(0.5))
        }
        .padding(margin)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(Color.journalBackground)
        .font(.system(.body, design: .monospaced))
    }
}
