import SwiftUI
import WidgetKit

@main
struct MoodWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextCheckInWidget()
    }
}

/// A lock screen widget counting down to the next reminder. Tapping it opens the app.
///
/// Everything it shows comes from the app group, never from Health: Health is unreadable
/// while the phone is locked, which is exactly when a lock screen widget renders.
struct NextCheckInWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextCheckIn", provider: NextCheckInProvider()) { entry in
            NextCheckInView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Next check-in")
        .description("Time to your next mood reminder, and the last mood you logged.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct NextCheckInEntry: TimelineEntry {
    var date: Date
    var nextPrompt: Date?
    var isPromptPending: Bool
    var lastLog: LoggedMood?
}

struct NextCheckInProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextCheckInEntry {
        NextCheckInEntry(
            date: .now,
            nextPrompt: .now.addingTimeInterval(2 * 3600),
            isPromptPending: false,
            lastLog: LoggedMood(date: .now.addingTimeInterval(-3600), valence: 0.4)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextCheckInEntry) -> Void) {
        completion(entry(at: .now))
    }

    /// An entry now, then one at every prompt and every window close over the next day, so
    /// "due" appears when a reminder fires and clears when it can no longer be answered.
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextCheckInEntry>) -> Void) {
        let now = Date.now
        let reminders = self.reminders
        var dates = [now]
        var cursor = now
        while let next = PromptSchedule.nextPrompt(after: cursor, reminders: reminders),
              next < now.addingTimeInterval(24 * 3600) {
            dates.append(next)
            dates.append(next.addingTimeInterval(PromptSchedule.completionWindow))
            cursor = next
        }
        let entries = dates.sorted().map(entry(at:))
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private var reminders: [Reminder] {
        UserDefaultsReminderStore().load() ?? Reminder.defaults
    }

    private func entry(at date: Date) -> NextCheckInEntry {
        let reminders = self.reminders
        let lastLog = LoggedMoodStore().load()
        return NextCheckInEntry(
            date: date,
            nextPrompt: PromptSchedule.nextPrompt(after: date, reminders: reminders),
            isPromptPending: PromptSchedule.pendingPrompt(
                now: date,
                reminders: reminders,
                lastLog: lastLog?.date
            ) != nil,
            lastLog: lastLog
        )
    }
}

struct NextCheckInView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NextCheckInEntry

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryInline: inline
        default: rectangular
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.isPromptPending ? "Check-in due" : "Next check-in")
                .font(.headline)
                .widgetAccentable()
            if entry.isPromptPending {
                Text("How are you?")
            } else if let next = entry.nextPrompt {
                Text(next, format: .dateTime.hour().minute()) + Text(" · in ") + Text(next, style: .relative)
            } else {
                Text("No reminders on")
            }
            if let last = entry.lastLog {
                Text(MoodChartClassification.classification(for: last.valence).rawValue)
                    + Text(" · ")
                    + Text(last.date, style: .relative)
                    + Text(" ago")
            }
        }
        .font(.caption)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: entry.isPromptPending ? "bell.badge" : "face.smiling")
                    .font(.body)
                if !entry.isPromptPending, let next = entry.nextPrompt {
                    Text(next, format: .dateTime.hour().minute())
                        .font(.system(size: 11, weight: .semibold))
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    @ViewBuilder
    private var inline: some View {
        if entry.isPromptPending {
            Text("Mood check-in due")
        } else if let next = entry.nextPrompt {
            Text("Check-in ") + Text(next, format: .dateTime.hour().minute())
        } else {
            Text("No mood reminders")
        }
    }
}
