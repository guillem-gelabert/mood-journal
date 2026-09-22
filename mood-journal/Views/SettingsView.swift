import HealthKit
import SwiftUI
import UIKit

struct SettingsView: View {
    var store: MoodDataStore

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    ChartsDashboardView(data: store.chartData)
                        .task { await store.refresh() }
                } label: {
                    Label("Charts", systemImage: "chart.xyaxis.line")
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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
