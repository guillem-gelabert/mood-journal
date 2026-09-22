import SwiftUI

struct ReminderEditorSheet: View {
    var title: String
    var onSave: (Int, Int) -> Void

    @State private var time: Date
    @Environment(\.dismiss) private var dismiss

    init(title: String, hour: Int, minute: Int, onSave: @escaping (Int, Int) -> Void) {
        self.title = title
        self.onSave = onSave
        _time = State(initialValue: Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date())
    }

    var body: some View {
        NavigationStack {
            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                            onSave(parts.hour ?? 0, parts.minute ?? 0)
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium])
    }
}
