import Foundation

enum FeedbackKind: String, Codable, CaseIterable, Identifiable {
    case idea, issue
    var id: String { rawValue }
    var label: String { self == .idea ? "Idea" : "Issue" }
    var symbol: String { self == .idea ? "lightbulb.fill" : "exclamationmark.bubble.fill" }
}

/// A note the user captures about the app so they don't forget it.
struct FeedbackNote: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var kind: FeedbackKind = .idea
    var done: Bool = false
    var createdAt: Date = Date()
}
