import Foundation

// MARK: - Players

enum Role: String, Codable, CaseIterable {
    case BAT, WK, AR, BOWL

    var label: String {
        switch self {
        case .BAT: return "Batter"
        case .WK: return "Wicket-keeper"
        case .AR: return "All-rounder"
        case .BOWL: return "Bowler"
        }
    }

    var short: String {
        switch self {
        case .BAT: return "BAT"
        case .WK: return "WK"
        case .AR: return "AR"
        case .BOWL: return "BOWL"
        }
    }
}

struct Player: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let role: Role
    let overseas: Bool
    let country: String
    /// Base price in lakhs (100 lakhs = 1 crore).
    let base: Int
    /// Auction pool: Marquee, Batters, All-rounders, Wicket-keepers, Bowlers, Uncapped.
    let pool: String
    let rating: Int
    let bat: Int
    let bowl: Int
    let line: String

    /// Can be trusted with 4 overs.
    var isBowlingOption: Bool { bowl >= 40 }
    var isTopOrderBat: Bool { bat >= 55 }
}

enum PlayerDB {
    static func decode(_ data: Data) throws -> [Player] {
        try JSONDecoder().decode([Player].self, from: data)
    }
}

// MARK: - Money (all amounts are in lakhs)

enum Money {
    static func format(_ lakhs: Int) -> String {
        if lakhs >= 100 {
            let cr = Double(lakhs) / 100
            var s = String(format: "%.2f", cr)
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
            return "₹\(s) Cr"
        }
        return "₹\(lakhs) L"
    }
}

// MARK: - Franchises

struct Franchise: Codable, Identifiable, Hashable {
    var id: Int
    var name: String
    var short: String
    var colorHex: String
    var isCPU: Bool
    var purse: Int = 0
    var squad: [String] = []
    /// Price paid per player id.
    var paid: [String: Int] = [:]
    /// Playing XI in batting order.
    var xi: [String] = []
    /// CPU bidding temperament (0.85 cautious ... 1.2 aggressive).
    var personality: Double = 1.0
}

struct FranchiseTemplate {
    let name: String
    let short: String
    let color: String

    /// Fictional franchise names — not affiliated with any real league.
    static let all: [FranchiseTemplate] = [
        .init(name: "Mumbai Monsoons", short: "MUM", color: "#2563EB"),
        .init(name: "Chennai Chargers", short: "CHE", color: "#EAB308"),
        .init(name: "Bengaluru Blazers", short: "BLR", color: "#DC2626"),
        .init(name: "Kolkata Kites", short: "KOL", color: "#7C3AED"),
        .init(name: "Delhi Defenders", short: "DEL", color: "#0EA5E9"),
        .init(name: "Hyderabad Hawks", short: "HYD", color: "#F97316"),
        .init(name: "Punjab Panthers", short: "PUN", color: "#E11D48"),
        .init(name: "Rajasthan Raiders", short: "RAJ", color: "#EC4899"),
        .init(name: "Lucknow Lions", short: "LKO", color: "#06B6D4"),
        .init(name: "Gujarat Gladiators", short: "GUJ", color: "#14B8A6"),
    ]
}

// MARK: - Rules

enum PoolSize: String, Codable, CaseIterable {
    case quick, full
    var label: String { self == .quick ? "Quick" : "Full (273 players)" }
}

struct Rules: Codable, Hashable {
    var purse: Int = 10_000          // ₹100 Cr
    var minSquad: Int = 11
    var maxSquad: Int = 18
    var maxOverseasSquad: Int = 8
    var maxOverseasXI: Int = 4
    var bidSeconds: Double = 8
    var poolSize: PoolSize = .quick
    var doubleRoundRobin: Bool = false
    /// Lowest base price in the pool; used to reserve purse for the minimum squad.
    var minBase: Int = 30
}
