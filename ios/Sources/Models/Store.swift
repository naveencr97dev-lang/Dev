import Foundation
import SwiftUI

/// App-wide data store. Persists to a JSON file in Documents.
final class Store: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var checkins: [Checkin] = []
    @Published var moods: [MoodEntry] = []
    @Published var appearance: AppearanceMode = .system

    private let calendar = Calendar.current
    private let fileURL: URL

    init(filename: String = "streaklet.json") {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent(filename)
        load()
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var habits: [Habit]
        var checkins: [Checkin]
        var moods: [MoodEntry]
        var appearance: AppearanceMode
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            habits = []
            checkins = []
            moods = []
            return
        }
        habits = snap.habits
        checkins = snap.checkins
        moods = snap.moods
        appearance = snap.appearance
    }

    func save() {
        let snap = Snapshot(habits: habits, checkins: checkins, moods: moods, appearance: appearance)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - Helpers

    func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    var activeHabits: [Habit] {
        habits.filter { !$0.archived }.sorted { $0.sortIndex < $1.sortIndex }
    }

    func habitsScheduled(on date: Date) -> [Habit] {
        activeHabits.filter { $0.isScheduled(on: date, calendar: calendar) }
    }

    func checkin(for habit: Habit, on date: Date) -> Checkin? {
        let day = startOfDay(date)
        return checkins.first { $0.habitId == habit.id && calendar.isDate($0.day, inSameDayAs: day) }
    }

    func value(for habit: Habit, on date: Date) -> Int {
        checkin(for: habit, on: date)?.value ?? 0
    }

    func isDone(_ habit: Habit, on date: Date) -> Bool {
        value(for: habit, on: date) >= habit.dailyTarget
    }

    // MARK: - Mutations

    func addHabit(_ habit: Habit) {
        var h = habit
        h.sortIndex = (habits.map { $0.sortIndex }.max() ?? 0) + 1
        habits.append(h)
        save()
    }

    func updateHabit(_ habit: Habit) {
        guard let idx = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[idx] = habit
        save()
    }

    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        checkins.removeAll { $0.habitId == habit.id }
        save()
    }

    func archiveHabit(_ habit: Habit) {
        guard let idx = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[idx].archived = true
        save()
    }

    /// Toggle a simple habit done/undone, or increment toward a goal.
    func toggle(_ habit: Habit, on date: Date) {
        let day = startOfDay(date)
        if let idx = checkins.firstIndex(where: { $0.habitId == habit.id && calendar.isDate($0.day, inSameDayAs: day) }) {
            if habit.goalTarget == nil {
                checkins.remove(at: idx)           // simple habit: tap again to undo
            } else {
                var c = checkins[idx]
                c.value += 1                        // goal habit: tap adds one
                if c.value > habit.dailyTarget { c.value = 0 } // wrap to reset
                if c.value == 0 { checkins.remove(at: idx) } else { checkins[idx] = c }
            }
        } else {
            let v = habit.goalTarget == nil ? 1 : 1
            checkins.append(Checkin(habitId: habit.id, day: day, value: v))
        }
        save()
    }

    func setMood(_ mood: Int, note: String, on date: Date) {
        let day = startOfDay(date)
        if let idx = moods.firstIndex(where: { calendar.isDate($0.day, inSameDayAs: day) }) {
            moods[idx].mood = mood
            moods[idx].note = note
        } else {
            moods.append(MoodEntry(day: day, mood: mood, note: note))
        }
        save()
    }

    func mood(on date: Date) -> MoodEntry? {
        moods.first { calendar.isDate($0.day, inSameDayAs: startOfDay(date)) }
    }

    func resetAll() {
        habits = []; checkins = []; moods = []
        save()
    }

    // MARK: - Demo seed

    func seedDemoIfEmpty() {
        guard habits.isEmpty else { return }
        let samples = [
            Habit(name: "Drink water", emoji: "💧", colorHex: "#38BDF8", goalTarget: 8, goalUnit: "glasses"),
            Habit(name: "Read", emoji: "📖", colorHex: "#A78BFA", goalTarget: 20, goalUnit: "minutes"),
            Habit(name: "Meditate", emoji: "🧘", colorHex: "#34D399"),
            Habit(name: "No late snacks", emoji: "🍫", colorHex: "#FB7185", kind: .quit)
        ]
        for s in samples { addHabit(s) }
    }
}

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
