import SwiftUI

struct RemindersView: View {
    @Bindable var model: RemindersModel
    @State private var editing: Reminder?
    @State private var isAdding = false

    var body: some View {
        List {
            Section {
                ForEach(model.reminders) { reminder in
                    HStack {
                        Button(Self.timeFormatter.string(from: Self.date(for: reminder))) {
                            editing = reminder
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { reminder.isEnabled },
                            set: { model.update(Reminder(id: reminder.id, hour: reminder.hour, minute: reminder.minute, isEnabled: $0)) }
                        ))
                        .labelsHidden()
                    }
                }
                .onDelete { model.delete(at: $0) }
            } footer: {
                if !model.authorization.isAuthorized {
                    Text("Notifications are off for Mood Journal. Reminders will not appear until you allow them in Settings.")
                } else if !model.authorization.isTimeSensitiveEnabled {
                    Text("Reminders deliver at normal priority. Time Sensitive delivery, which breaks through Focus and Notification Summary, needs the capability enabled for this app.")
                }
            }

            if model.canAddMore {
                Button("Add reminder") { isAdding = true }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAdding) {
            ReminderEditorSheet(title: "New reminder", hour: 12, minute: 0) { hour, minute in
                model.add(hour: hour, minute: minute)
            }
        }
        .sheet(item: $editing) { reminder in
            ReminderEditorSheet(title: "Edit reminder", hour: reminder.hour, minute: reminder.minute) { hour, minute in
                model.update(Reminder(id: reminder.id, hour: hour, minute: minute, isEnabled: reminder.isEnabled))
            }
        }
        .task { await model.refreshAuthorization() }
    }

    private static func date(for reminder: Reminder) -> Date {
        Calendar.current.date(from: DateComponents(hour: reminder.hour, minute: reminder.minute)) ?? Date()
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
