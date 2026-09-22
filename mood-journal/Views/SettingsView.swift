import HealthKit
import SwiftUI
import UIKit

struct SettingsView: View {
    var store: MoodDataStore
    var reminders: RemindersModel

    @State private var reportURL: URL?
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    ChartsDashboardView(store: store)
                        .task { await store.refresh() }
                } label: {
                    Label("Charts", systemImage: "chart.xyaxis.line")
                }

                NavigationLink {
                    RemindersView(model: reminders)
                } label: {
                    Label("Reminders", systemImage: "bell")
                }

                if let reportURL {
                    ShareLink(item: reportURL) {
                        Label("Export PDF", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        exportReport()
                    } label: {
                        Label(isExporting ? "Preparing report..." : "Export PDF", systemImage: "doc.richtext")
                    }
                    .disabled(isExporting || store.chartData.interval == nil)
                }

                if let exportError {
                    Text(exportError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Apple Health") {
                LabeledContent("Writing", value: shareStatusText)
                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Open Health Settings") { openSettings() }
            }
        }
        .onChange(of: store.range) { _, _ in reportURL = nil }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exportReport() {
        isExporting = true
        exportError = nil
        defer { isExporting = false }

        let generatedAt = Date()
        let request = ChartReportRequest(
            data: store.chartData,
            adherence: store.adherence,
            generatedAt: generatedAt
        )
        do {
            reportURL = try ChartReportPDFRenderer.render(
                request,
                to: ChartReportPDFRenderer.defaultURL(for: generatedAt)
            )
        } catch {
            exportError = error.localizedDescription
        }
    }

    /// HealthKit only reports share status; read access is deliberately unqueryable, so this
    /// says nothing about whether the charts will have data.
    private var shareStatusText: String {
        switch HKHealthStore().authorizationStatus(for: HKObjectType.stateOfMindType()) {
        case .sharingAuthorized: "Allowed"
        case .sharingDenied: "Denied"
        default: "Not set"
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
