import Foundation

/// A recurring staple the user restocks. Persists week to week.
struct GroceryItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var emoji: String = "🛒"
    var category: String = "Other"
    var sortIndex: Int = 0
    var createdAt: Date = Date()
}

enum StockStatus: String, Codable {
    case unchecked   // not reviewed this week yet
    case inStock     // have it at home
    case needOrder   // missing -> add to shopping list
}

/// One week's stock review for one item. Keyed by the item and the week start.
struct GroceryCheck: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var itemId: UUID
    var weekStart: Date
    var status: StockStatus
}

enum GroceryCategory {
    static let all = ["Produce", "Dairy", "Bakery", "Meat", "Pantry", "Frozen", "Household", "Other"]
    static func emoji(for category: String) -> String {
        switch category {
        case "Produce": return "🥦"
        case "Dairy": return "🥛"
        case "Bakery": return "🍞"
        case "Meat": return "🍗"
        case "Pantry": return "🥫"
        case "Frozen": return "🧊"
        case "Household": return "🧻"
        default: return "🛒"
        }
    }
}
