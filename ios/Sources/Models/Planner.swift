import Foundation

/// An in-app calendar event.
struct CalEvent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var day: Date                 // start-of-day
    var startMinutes: Int? = nil  // minutes after midnight (optional)
    var endMinutes: Int? = nil
    var emoji: String = "📅"
    var colorHex: String = "#6D5EF6"
    var note: String = ""
}

/// A to-do item with an optional time, reminder and repeat.
struct TaskItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var dueDay: Date              // start-of-day
    var dueMinutes: Int? = nil    // optional time of day
    var remind: Bool = false
    var repeatRule: Frequency? = nil   // nil = one-off
    var done: Bool = false
    var createdAt: Date = Date()
}

/// Formats minutes-after-midnight as a short time string.
func timeLabel(_ minutes: Int) -> String {
    var comps = DateComponents()
    comps.hour = minutes / 60
    comps.minute = minutes % 60
    let date = Calendar.current.date(from: comps) ?? Date()
    return date.formatted(.dateTime.hour().minute())
}
