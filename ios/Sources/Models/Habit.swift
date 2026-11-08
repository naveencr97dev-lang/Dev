import Foundation

enum HabitKind: String, Codable, CaseIterable, Identifiable {
    case build
    case quit
    var id: String { rawValue }
    var label: String { self == .build ? "Build" : "Quit" }
}

/// A habit the user is building or quitting.
struct Habit: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var emoji: String = "✅"
    var colorHex: String = "#4F8CFF"
    var kind: HabitKind = .build

    /// Optional measurable goal, e.g. 8 "glasses" or 30 "minutes".
    var goalTarget: Int? = nil
    var goalUnit: String? = nil

    /// Weekdays the habit is scheduled on. 1 = Sunday ... 7 = Saturday.
    /// Empty means every day.
    var weekdays: Set<Int> = []

    /// Optional daily reminder time, stored as minutes after midnight.
    var reminderMinutes: Int? = nil

    var archived: Bool = false
    var sortIndex: Int = 0
    var createdAt: Date = Date()

    var isDaily: Bool { weekdays.isEmpty || weekdays.count == 7 }

    /// The per-day target used to decide "done". Defaults to 1 for simple habits.
    var dailyTarget: Int { max(goalTarget ?? 1, 1) }

    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        if isDaily { return true }
        let wd = calendar.component(.weekday, from: date)
        return weekdays.contains(wd)
    }
}
