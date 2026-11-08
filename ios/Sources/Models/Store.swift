import Foundation
import SwiftUI

/// App-wide data store. Persists to a JSON file in Documents.
final class Store: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var checkins: [Checkin] = []
    @Published var moods: [MoodEntry] = []
    @Published var goals: [Goal] = []
    @Published var feedback: [FeedbackNote] = []
    @Published var groceryItems: [GroceryItem] = []
    @Published var groceryChecks: [GroceryCheck] = []
    @Published var appearance: AppearanceMode = .system
    @Published var textSize: TextSizePref = .default_

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
        var goals: [Goal]?
        var feedback: [FeedbackNote]?
        var groceryItems: [GroceryItem]?
        var groceryChecks: [GroceryCheck]?
        var appearance: AppearanceMode
        var textSize: TextSizePref?
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
        goals = snap.goals ?? []
        feedback = snap.feedback ?? []
        groceryItems = snap.groceryItems ?? []
        groceryChecks = snap.groceryChecks ?? []
        appearance = snap.appearance
        textSize = snap.textSize ?? .default_
    }

    func save() {
        let snap = Snapshot(habits: habits, checkins: checkins, moods: moods,
                            goals: goals, feedback: feedback,
                            groceryItems: groceryItems, groceryChecks: groceryChecks,
                            appearance: appearance, textSize: textSize)
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

    /// The period (day / week / month) that `date` falls in for this habit.
    func periodInterval(for habit: Habit, on date: Date) -> DateInterval {
        switch habit.frequency {
        case .daily:
            let s = startOfDay(date)
            return DateInterval(start: s, end: calendar.date(byAdding: .day, value: 1, to: s)!)
        case .weekly:
            let s = weekStart(date)
            return DateInterval(start: s, end: calendar.date(byAdding: .day, value: 7, to: s)!)
        case .monthly:
            let comps = calendar.dateComponents([.year, .month], from: date)
            let s = calendar.date(from: comps)!
            return DateInterval(start: s, end: calendar.date(byAdding: .month, value: 1, to: s)!)
        }
    }

    /// Distinct days with a check-in inside the habit's current period.
    func completions(_ habit: Habit, inPeriodOf date: Date) -> Int {
        let interval = periodInterval(for: habit, on: date)
        let days = Set(checkins
            .filter { $0.habitId == habit.id && $0.day >= interval.start && $0.day < interval.end }
            .map { startOfDay($0.day) })
        return days.count
    }

    /// Target completions for the habit's period.
    func periodTargetCount(_ habit: Habit) -> Int {
        habit.frequency == .daily ? habit.dailyTarget : max(habit.periodTarget, 1)
    }

    func isDone(_ habit: Habit, on date: Date) -> Bool {
        switch habit.frequency {
        case .daily:
            return value(for: habit, on: date) >= habit.dailyTarget
        case .weekly, .monthly:
            return completions(habit, inPeriodOf: date) >= max(habit.periodTarget, 1)
        }
    }

    /// Progress toward the current period's target (0...1).
    func periodProgress(_ habit: Habit, on date: Date) -> Double {
        let target = periodTargetCount(habit)
        guard target > 0 else { return 0 }
        let value = habit.frequency == .daily
            ? self.value(for: habit, on: date)
            : completions(habit, inPeriodOf: date)
        return min(Double(value) / Double(target), 1)
    }

    /// Daily habits only — used for the day-oriented summary metrics.
    func dailyHabitsScheduled(on date: Date) -> [Habit] {
        habitsScheduled(on: date).filter { $0.frequency == .daily }
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

    /// Toggle a habit for a day. Daily simple habits toggle; daily goal habits
    /// increment; weekly/monthly habits add or remove one completion for the day.
    func toggle(_ habit: Habit, on date: Date) {
        let day = startOfDay(date)
        let existing = checkins.firstIndex { $0.habitId == habit.id && calendar.isDate($0.day, inSameDayAs: day) }

        if habit.frequency != .daily {
            if let idx = existing { checkins.remove(at: idx) }
            else { checkins.append(Checkin(habitId: habit.id, day: day, value: 1)) }
            save()
            return
        }

        if let idx = existing {
            if habit.goalTarget == nil {
                checkins.remove(at: idx)            // simple habit: tap again to undo
            } else {
                var c = checkins[idx]
                c.value += 1                         // goal habit: tap adds one
                if c.value > habit.dailyTarget { c.value = 0 }  // wrap to reset
                if c.value == 0 { checkins.remove(at: idx) } else { checkins[idx] = c }
            }
        } else {
            checkins.append(Checkin(habitId: habit.id, day: day, value: 1))
        }
        save()
    }

    // MARK: - Goals

    var sortedGoals: [Goal] { goals.sorted { $0.sortIndex < $1.sortIndex } }

    func habits(for goal: Goal) -> [Habit] {
        activeHabits.filter { $0.goalId == goal.id }
    }

    /// Share of a goal's habits that are done in their current period (0...1).
    func goalProgress(_ goal: Goal) -> Double {
        let hs = habits(for: goal)
        guard !hs.isEmpty else { return 0 }
        let done = hs.filter { isDone($0, on: Date()) }.count
        return Double(done) / Double(hs.count)
    }

    func addGoal(_ goal: Goal) {
        var g = goal
        g.sortIndex = (goals.map { $0.sortIndex }.max() ?? 0) + 1
        goals.append(g)
        save()
    }

    func updateGoal(_ goal: Goal) {
        guard let idx = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[idx] = goal
        save()
    }

    func deleteGoal(_ goal: Goal) {
        goals.removeAll { $0.id == goal.id }
        for i in habits.indices where habits[i].goalId == goal.id {
            habits[i].goalId = nil           // detach habits, keep them
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

    // MARK: - Groceries

    /// Monday-start of the week containing `date`.
    func weekStart(_ date: Date = Date()) -> Date {
        let d = startOfDay(date)
        let weekday = calendar.component(.weekday, from: d) // 1=Sun...7=Sat
        let delta = (weekday + 5) % 7                       // days since Monday
        return calendar.date(byAdding: .day, value: -delta, to: d)!
    }

    var sortedGroceryItems: [GroceryItem] {
        groceryItems.sorted { ($0.category, $0.sortIndex) < ($1.category, $1.sortIndex) }
    }

    func status(for item: GroceryItem, week: Date? = nil) -> StockStatus {
        let w = week ?? weekStart()
        return groceryChecks.first {
            $0.itemId == item.id && calendar.isDate($0.weekStart, inSameDayAs: w)
        }?.status ?? .unchecked
    }

    /// Cycle a staple's status for the current week: unchecked -> inStock -> needOrder -> unchecked.
    func cycleStatus(for item: GroceryItem) {
        let w = weekStart()
        let next: StockStatus
        switch status(for: item, week: w) {
        case .unchecked: next = .inStock
        case .inStock: next = .needOrder
        case .needOrder: next = .unchecked
        }
        if let idx = groceryChecks.firstIndex(where: {
            $0.itemId == item.id && calendar.isDate($0.weekStart, inSameDayAs: w) }) {
            if next == .unchecked { groceryChecks.remove(at: idx) }
            else { groceryChecks[idx].status = next }
        } else if next != .unchecked {
            groceryChecks.append(GroceryCheck(itemId: item.id, weekStart: w, status: next))
        }
        save()
    }

    func setStatus(_ status: StockStatus, for item: GroceryItem) {
        let w = weekStart()
        if let idx = groceryChecks.firstIndex(where: {
            $0.itemId == item.id && calendar.isDate($0.weekStart, inSameDayAs: w) }) {
            if status == .unchecked { groceryChecks.remove(at: idx) }
            else { groceryChecks[idx].status = status }
        } else if status != .unchecked {
            groceryChecks.append(GroceryCheck(itemId: item.id, weekStart: w, status: status))
        }
        save()
    }

    /// Items marked "need to order" this week.
    var shoppingList: [GroceryItem] {
        sortedGroceryItems.filter { status(for: $0) == .needOrder }
    }

    /// Items not yet reviewed this week.
    var uncheckedCount: Int {
        groceryItems.filter { status(for: $0) == .unchecked }.count
    }

    func addGroceryItem(_ item: GroceryItem) {
        var it = item
        it.sortIndex = (groceryItems.map { $0.sortIndex }.max() ?? 0) + 1
        groceryItems.append(it)
        save()
    }

    func deleteGroceryItem(_ item: GroceryItem) {
        groceryItems.removeAll { $0.id == item.id }
        groceryChecks.removeAll { $0.itemId == item.id }
        save()
    }

    func seedGroceriesIfEmpty() {
        guard groceryItems.isEmpty else { return }
        let samples: [(String, String)] = [
            ("Milk", "Dairy"), ("Eggs", "Dairy"), ("Bread", "Bakery"),
            ("Bananas", "Produce"), ("Tomatoes", "Produce"), ("Chicken", "Meat"),
            ("Rice", "Pantry"), ("Toilet paper", "Household")
        ]
        for (n, c) in samples {
            addGroceryItem(GroceryItem(name: n, emoji: GroceryCategory.emoji(for: c), category: c))
        }
    }

    // MARK: - Feedback (ideas & issues)

    var sortedFeedback: [FeedbackNote] {
        feedback.sorted { a, b in
            if a.done != b.done { return !a.done }   // open notes first
            return a.createdAt > b.createdAt          // newest first
        }
    }

    func addFeedback(_ text: String, kind: FeedbackKind) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        feedback.append(FeedbackNote(text: t, kind: kind))
        save()
    }

    func toggleFeedbackDone(_ note: FeedbackNote) {
        guard let idx = feedback.firstIndex(where: { $0.id == note.id }) else { return }
        feedback[idx].done.toggle()
        save()
    }

    func deleteFeedback(_ note: FeedbackNote) {
        feedback.removeAll { $0.id == note.id }
        save()
    }

    /// Plain-text export of all notes (for sharing).
    func feedbackExport() -> String {
        sortedFeedback.map { n in
            let box = n.done ? "[x]" : "[ ]"
            return "\(box) \(n.kind.label.uppercased()): \(n.text)"
        }.joined(separator: "\n")
    }

    func resetAll() {
        habits = []; checkins = []; moods = []
        goals = []; feedback = []
        groceryItems = []; groceryChecks = []
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

/// App-wide text size, mapped to Dynamic Type.
enum TextSizePref: String, Codable, CaseIterable, Identifiable {
    case small, default_, large, xlarge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .small: return "Small"
        case .default_: return "Default"
        case .large: return "Large"
        case .xlarge: return "Extra Large"
        }
    }
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: return .small
        case .default_: return .large      // iOS system default
        case .large: return .xLarge
        case .xlarge: return .xxxLarge
        }
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
