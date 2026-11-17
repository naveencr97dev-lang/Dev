import SwiftUI

struct EventEditView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let day: Date

    @State private var title = ""
    @State private var date = Date()
    @State private var hasTime = false
    @State private var start = Date()
    @State private var note = ""
    @State private var colorHex = "#6D5EF6"

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Title", text: $title)
                    DatePicker("Day", selection: $date, displayedComponents: .date)
                    Toggle("Set a time", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute)
                    }
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Palette.habitColors, id: \.self) { hex in
                            Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.primary, lineWidth: colorHex == hex ? 2 : 0))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical).lineLimit(1...4)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { date = day }
        }
    }

    private func save() {
        let cal = Calendar.current
        var e = CalEvent(title: title.trimmingCharacters(in: .whitespaces),
                         day: cal.startOfDay(for: date))
        if hasTime {
            let c = cal.dateComponents([.hour, .minute], from: start)
            e.startMinutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
        e.note = note
        e.colorHex = colorHex
        store.addEvent(e)
        dismiss()
    }
}

struct TaskEditView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let day: Date

    @State private var title = ""
    @State private var date = Date()
    @State private var hasTime = false
    @State private var time = Date()
    @State private var remind = false
    @State private var repeats = false
    @State private var rule: Frequency = .daily

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs doing?", text: $title)
                    DatePicker("Due", selection: $date, displayedComponents: .date)
                    Toggle("Set a time", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        Toggle("Remind me", isOn: $remind)
                    }
                }
                Section("Repeat") {
                    Toggle("Repeats", isOn: $repeats)
                    if repeats {
                        Picker("Every", selection: $rule) {
                            ForEach(Frequency.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { date = day }
        }
    }

    private func save() {
        let cal = Calendar.current
        var t = TaskItem(title: title.trimmingCharacters(in: .whitespaces),
                         dueDay: cal.startOfDay(for: date))
        if hasTime {
            let c = cal.dateComponents([.hour, .minute], from: time)
            t.dueMinutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            t.remind = remind
        }
        t.repeatRule = repeats ? rule : nil
        store.addTask(t)
        dismiss()
    }
}
