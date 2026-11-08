import SwiftUI

struct MoodView: View {
    @EnvironmentObject var store: Store
    @State private var mood = 3
    @State private var note = ""
    private let calendar = Calendar.current
    private let faces = ["😞", "🙁", "😐", "🙂", "😄"]

    private var today: Date { calendar.startOfDay(for: Date()) }

    var body: some View {
        NavigationStack {
            List {
                Section("How was today?") {
                    HStack {
                        ForEach(1...5, id: \.self) { m in
                            Text(faces[m - 1])
                                .font(.system(size: 32))
                                .opacity(mood == m ? 1 : 0.4)
                                .scaleEffect(mood == m ? 1.15 : 1)
                                .onTapGesture { withAnimation { mood = m } }
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 4)
                    TextField("Add a note (optional)", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                    Button("Save entry") {
                        store.setMood(mood, note: note, on: today)
                        note = ""
                    }
                    .fontWeight(.semibold)
                }

                Section("Recent") {
                    if pastEntries.isEmpty {
                        Text("No entries yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(pastEntries) { e in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(faces[max(0, min(4, e.mood - 1))])
                                    Text(e.day.formatted(.dateTime.weekday().month().day()))
                                        .font(.subheadline.weight(.medium))
                                }
                                if !e.note.isEmpty {
                                    Text(e.note).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Journal")
            .onAppear {
                if let m = store.mood(on: today) { mood = m.mood; note = m.note }
            }
        }
    }

    private var pastEntries: [MoodEntry] {
        store.moods.sorted { $0.day > $1.day }
    }
}
