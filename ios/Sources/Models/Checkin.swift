import Foundation

/// A single day's progress for a habit. One per habit per day.
struct Checkin: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var habitId: UUID
    /// Start-of-day date the check-in belongs to.
    var day: Date
    /// Accumulated value for the day (e.g. glasses of water). 1 for simple habits.
    var value: Int = 1
}

/// A mood / diary entry for a day.
struct MoodEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var day: Date
    /// 1 (low) ... 5 (great)
    var mood: Int
    var note: String = ""
}
