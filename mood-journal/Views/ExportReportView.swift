import SwiftUI

struct ExportReportView: View {
    var store: MoodDataStore

    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date
    @State private var reportURL: URL?
    @State private var isGenerating = false
    @State private var errorMessage: String?

    init(store: MoodDataStore) {
        self.store = store
        let interval = store.chartData.interval
        _start = State(initialValue: interval?.start ?? Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date())
        _end = State(initialValue: (interval?.end ?? Date()).addingTimeInterval(-1))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Range") {
                    DatePicker("From", selection: $start, in: ...end, displayedComponents: .date)
                    DatePicker("To", selection: $end, in: start..., displayedComponents: .date)
                }

                Section {
                    if let reportURL {
                        ShareLink(item: reportURL) {
                            Label("Share report", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            Task { await generate() }
                        } label: {
                            Label(isGenerating ? "Preparing report..." : "Generate report", systemImage: "doc.richtext")
                        }
                        .disabled(isGenerating)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Two A4 pages: mood over time and by weekday, then active energy and sleep.")
                }
            }
            .navigationTitle("Export PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // A report already generated describes the old range, so drop it on any edit.
            .onChange(of: start) { _, _ in reportURL = nil }
            .onChange(of: end) { _, _ in reportURL = nil }
        }
    }

    private func generate() async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        let calendar = Calendar.current
        guard
            let intervalEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)),
            case let intervalStart = calendar.startOfDay(for: start),
            intervalStart < intervalEnd
        else {
            errorMessage = "That range is empty."
            return
        }

        guard let data = await store.chartData(for: DateInterval(start: intervalStart, end: intervalEnd)) else {
            errorMessage = "Could not read Health data for that range."
            return
        }

        let generatedAt = Date()
        do {
            reportURL = try ChartReportPDFRenderer.render(
                ChartReportRequest(data: data, adherence: store.adherence, generatedAt: generatedAt),
                to: ChartReportPDFRenderer.defaultURL(for: generatedAt)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
