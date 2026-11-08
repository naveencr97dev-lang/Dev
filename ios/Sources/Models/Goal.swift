import Foundation

/// A larger objective the user attaches habits to.
struct Goal: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var emoji: String = "🎯"
    var colorHex: String = "#7C6CF0"
    var targetDate: Date? = nil
    var sortIndex: Int = 0
    var createdAt: Date = Date()
}
