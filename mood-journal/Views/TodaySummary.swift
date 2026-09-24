import SwiftUI

/// What an unprompted open shows: the day's moods so far, or the last one if today is empty,
/// and how long until the next reminder.
struct TodaySummary: View {
    var today: TodayModel
    var onLogNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()

            if today.todaysLogs.isEmpty {
                lastLogSection
            } else {
                todaySection
            }

            nextPromptSection

            Button("Log now", action: onLogNow)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .buttonStyle(.bordered)
                .tint(.journalInk)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Today")
            ForEach(today.todaysLogs) { log in
                HStack(spacing: 14) {
                    Text(log.date, format: .dateTime.hour().minute())
                        .monospacedDigit()
                        .foregroundStyle(.journalInk.opacity(0.6))
                    moodName(for: log)
                }
            }
        }
    }

    @ViewBuilder
    private var lastLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Nothing logged today")
            if let last = today.lastLog {
                moodName(for: last)
                Text(last.date, format: .dateTime.weekday(.wide).day().month().hour().minute())
                    .foregroundStyle(.journalInk.opacity(0.6))
            } else {
                Text("No moods logged yet.")
                    .foregroundStyle(.journalInk.opacity(0.6))
            }
        }
    }

    private var nextPromptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Next check-in")
            if let next = today.nextPrompt {
                // A timer-style date re-renders on its own, so the countdown stays live.
                (Text("in ") + Text(next, style: .relative))
                    .font(.system(.title3, design: .serif).italic())
                    .foregroundStyle(.journalInk)
                Text(next, format: .dateTime.hour().minute())
                    .foregroundStyle(.journalInk.opacity(0.6))
            } else {
                Text("No reminders are on.")
                    .foregroundStyle(.journalInk.opacity(0.6))
            }
        }
    }

    private func moodName(for log: MoodCheckIn) -> some View {
        let classification = MoodChartClassification.classification(for: log.valence)
        return Text(classification.rawValue)
            .font(.system(.title3, design: .serif).italic())
            .foregroundStyle(classification.color)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .textCase(.uppercase)
            .foregroundStyle(.journalInk.opacity(0.6))
    }
}
