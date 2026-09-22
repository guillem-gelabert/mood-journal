import SwiftData
import SwiftUI

struct DiaryTableView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DiaryNote.dayKey, order: .reverse) private var notes: [DiaryNote]

    var days: [DiaryDay]

    var body: some View {
        NavigationStack {
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(days) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Self.dayFormatter.string(from: day.date))
                                .font(.system(.headline, design: .serif).italic())
                                .foregroundStyle(.journalInk)

                            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                                headerRow
                                ForEach(day.entries) { entry in
                                    GridRow {
                                        Text(entry.slot.rawValue)
                                            .frame(width: 86, alignment: .leading)

                                        moodCell(entry.mood)
                                            .frame(width: 100, alignment: .leading)

                                        Text(entry.slot == .morning ? sleepText(day.sleepHours) : "")
                                            .frame(width: 70, alignment: .leading)

                                        Text(entry.slot == .morning ? (day.activity?.rawValue.capitalized ?? "") : "")
                                            .frame(width: 86, alignment: .leading)

                                        if entry.slot == .morning {
                                            DiaryNoteEditor(text: noteBinding(for: day))
                                        } else {
                                            Color.clear
                                                .frame(width: 320, height: 1)
                                        }
                                    }
                                }
                            }
                            .font(.system(.subheadline, design: .monospaced))
                        }
                        .padding(.bottom, 8)
                    }
                }
                .padding()
            }
            .background(Color.journalBackground)
            .navigationTitle("Diary")
        }
    }

    private var headerRow: some View {
        GridRow {
            Text("Time")
            Text("Mood")
            Text("Sleep")
            Text("Activity")
            Text("Notes")
        }
        .font(.caption.bold())
        .foregroundStyle(Color.journalInk.opacity(0.66))
    }

    private func moodCell(_ mood: DiaryMoodBucket?) -> some View {
        Group {
            if let mood {
                Text(mood.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(mood.color, in: Capsule())
            } else {
                Text("")
            }
        }
    }

    private func sleepText(_ hours: Double?) -> String {
        guard let hours else { return "" }
        return String(format: "%.1f h", hours)
    }

    private func noteBinding(for day: DiaryDay) -> Binding<String> {
        let key = MoodAnalytics.dayKey(for: day.date)
        return Binding(
            get: {
                MoodAnalytics.mergedNoteText(autoText: day.autoNotes, userText: notes.first { $0.dayKey == key }?.text)
            },
            set: { newValue in
                if let note = notes.first(where: { $0.dayKey == key }) {
                    note.text = newValue
                    note.updatedAt = Date()
                } else {
                    modelContext.insert(DiaryNote(dayKey: key, text: newValue))
                }
                try? modelContext.save()
            }
        )
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct DiaryNoteEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .scrollContentBackground(.hidden)
            .background(Color.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
            .frame(width: 320)
            .frame(minHeight: 82)
    }
}
