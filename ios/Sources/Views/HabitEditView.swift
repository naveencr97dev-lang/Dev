import SwiftUI

struct HabitEditView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    /// nil = creating a new habit.
    let habit: Habit?
    /// Optional starter values for a new habit (from a template).
    var prefill: Habit? = nil
    /// Called after a successful save (used to also dismiss a parent picker).
    var onSaved: (() -> Void)? = nil

    @State private var name = ""
    @State private var emoji = "✅"
    @State private var colorHex = Palette.habitColors[0]
    @State private var kind: HabitKind = .build
    @State private var hasGoal = false
    @State private var goalTarget = 1
    @State private var goalUnit = "times"
    @State private var everyDay = true
    @State private var weekdays: Set<Int> = []
    @State private var hasReminder = false
    @State private var reminderTime = Date()
    @State private var timeOfDay: TimeOfDay = .anytime
    @State private var goalId: UUID? = nil
    @State private var frequency: Frequency = .daily
    @State private var periodTarget = 1

    private let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $kind) {
                        ForEach(HabitKind.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Icon") {
                    emojiGrid
                }

                Section("Color") {
                    colorGrid
                }

                Section("Goal") {
                    Toggle("Measurable goal", isOn: $hasGoal)
                    if hasGoal {
                        Stepper("Target: \(goalTarget)", value: $goalTarget, in: 1...100)
                        TextField("Unit (e.g. glasses, minutes)", text: $goalUnit)
                    }
                }

                Section("Goal") {
                    Picker("Goal", selection: $goalId) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.sortedGoals) { g in
                            Text("\(g.emoji) \(g.name)").tag(UUID?.some(g.id))
                        }
                    }
                }

                Section("Frequency") {
                    Picker("Repeats", selection: $frequency) {
                        ForEach(Frequency.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if frequency != .daily {
                        Stepper("Target: \(periodTarget) × per \(frequency.unit)", value: $periodTarget, in: 1...30)
                    }
                }

                Section("Time of day") {
                    Picker("When", selection: $timeOfDay) {
                        ForEach(TimeOfDay.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                    }
                }

                Section("Schedule") {
                    Toggle("Every day", isOn: $everyDay)
                    if !everyDay {
                        HStack {
                            ForEach(1...7, id: \.self) { wd in
                                let on = weekdays.contains(wd)
                                Button {
                                    if on { weekdays.remove(wd) } else { weekdays.insert(wd) }
                                } label: {
                                    Text(weekdaySymbols[wd - 1].prefix(1))
                                        .font(.footnote.weight(.semibold))
                                        .frame(width: 34, height: 34)
                                        .background(Circle().fill(on ? Color.accentColor : Color.secondary.opacity(0.15)))
                                        .foregroundStyle(on ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Reminder") {
                    Toggle("Daily reminder", isOn: $hasReminder)
                    if hasReminder {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                if habit != nil {
                    Section {
                        Button("Archive habit") { archive() }
                        Button("Delete habit", role: .destructive) { delete() }
                    }
                }
            }
            .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: hydrate)
        }
    }

    private var emojiGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
            ForEach(Palette.emojis, id: \.self) { e in
                Text(e)
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(emoji == e ? Color.accentColor.opacity(0.25) : .clear))
                    .onTapGesture { emoji = e }
            }
        }
    }

    private var colorGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(Palette.habitColors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(Color.primary, lineWidth: colorHex == hex ? 2 : 0)
                    )
                    .onTapGesture { colorHex = hex }
            }
        }
    }

    private func hydrate() {
        guard let h = habit ?? prefill else { return }
        name = h.name
        emoji = h.emoji
        colorHex = h.colorHex
        kind = h.kind
        hasGoal = h.goalTarget != nil
        goalTarget = h.goalTarget ?? 1
        goalUnit = h.goalUnit ?? "times"
        everyDay = h.isDaily
        weekdays = h.weekdays
        timeOfDay = h.timeOfDay
        goalId = h.goalId
        frequency = h.frequency
        periodTarget = h.periodTarget
        if let m = h.reminderMinutes {
            hasReminder = true
            reminderTime = Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
        }
    }

    private func save() {
        var h = habit ?? Habit(name: "")
        h.name = name.trimmingCharacters(in: .whitespaces)
        h.emoji = emoji
        h.colorHex = colorHex
        h.kind = kind
        h.goalTarget = hasGoal ? goalTarget : nil
        h.goalUnit = hasGoal ? goalUnit : nil
        h.weekdays = everyDay ? [] : weekdays
        h.timeOfDay = timeOfDay
        h.goalId = goalId
        h.frequency = frequency
        h.periodTarget = periodTarget
        if hasReminder {
            let c = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            h.reminderMinutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        } else {
            h.reminderMinutes = nil
        }

        if habit == nil { store.addHabit(h) } else { store.updateHabit(h) }
        Reminders.sync(store: store)
        dismiss()
        onSaved?()
    }

    private func archive() {
        if let h = habit { store.archiveHabit(h) }
        dismiss()
    }

    private func delete() {
        if let h = habit { store.deleteHabit(h) }
        dismiss()
    }
}
