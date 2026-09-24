import HealthKit
import SwiftUI
import UIKit

struct SettingsView: View {
    var store: MoodDataStore
    var reminders: RemindersModel

    @State private var isExporting = false

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

                Button {
                    isExporting = true
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
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

            #if DEBUG
            Section {
                Button("Send test reminder in 5 s") {
                    Task { await NotificationReminderScheduler().sendTestReminder() }
                }
            } footer: {
                Text("Debug builds only. Long-press it to log from the notification.")
            }
            #endif
        }
        .sheet(isPresented: $isExporting) {
            ExportReportView(store: store)
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
