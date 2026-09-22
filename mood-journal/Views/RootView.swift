import SwiftUI
import UIKit

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = MoodDataStore()

    var body: some View {
        ZStack {
            Color.journalBackground.ignoresSafeArea()

            if let error = store.errorMessage {
                HealthKitErrorView(message: error) {
                    openSettings()
                } retry: {
                    Task { await store.refresh() }
                }
            } else {
                ChartsDashboardView(data: store.chartData)
            }

            if store.isLoading {
                ProgressView()
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .font(.system(.body, design: .monospaced))
        .task {
            await store.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await store.refreshOnForeground() }
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct HealthKitErrorView: View {
    var message: String
    var openSettings: () -> Void
    var retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Health data unavailable")
                .font(.system(.title2, design: .serif).italic())
                .foregroundStyle(.journalInk)

            Text(message)
                .foregroundStyle(.journalInk.opacity(0.82))

            HStack {
                Button(action: retry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button(action: openSettings) {
                    Label("Open Settings", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: 520, alignment: .leading)
    }
}
