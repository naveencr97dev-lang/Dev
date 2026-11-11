import Foundation

// Career › Club › Finances (season money) and Career › Development › Training (weekly session).

enum TicketPrice: String, Codable, CaseIterable, Identifiable {
    case low, normal, high
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    /// Change to attendance (fraction of capacity) and to money per fan.
    var fillDelta: Double { self == .low ? 0.15 : (self == .high ? -0.15 : 0) }
    var priceMult: Double { self == .low ? 0.75 : (self == .high ? 1.35 : 1) }
}

/// Where the user's money came from (and went) this season.
enum MoneyCategory: String, Codable, CaseIterable {
    case tickets, merchandise, sponsors, revenue, prizes, sales, purchases, wages, facilities, other

    var label: String {
        switch self {
        case .tickets: return "Ticket sales"
        case .merchandise: return "Merchandise"
        case .sponsors: return "Sponsor"
        case .revenue: return "Central revenue"
        case .prizes: return "Prize money"
        case .sales: return "Player sales"
        case .purchases: return "Transfer fees"
        case .wages: return "Wages"
        case .facilities: return "Facilities"
        case .other: return "Other"
        }
    }

    static func of(_ text: String, amount: Int) -> MoneyCategory {
        if text.hasPrefix("Tickets") || text.hasPrefix("Gate") { return .tickets }
        if text.hasPrefix("Sponsor:") { return .sponsors }
        if text.hasPrefix("Merchandise") || text.hasPrefix("Sponsors") { return .merchandise }
        if text.contains("central revenue") { return .revenue }
        if text.hasPrefix("Prize") { return .prizes }
        if text.hasPrefix("Sold") { return .sales }
        if text.hasPrefix("Signed") || text.hasPrefix("Released") { return .purchases }
        if text == "Wages" || text.hasPrefix("Scout") || text.hasPrefix("Hired") { return .wages }
        if text.contains("upgrade") || text.contains("upkeep") { return .facilities }
        return .other
    }
}

extension Career {
    /// Records the user's money by category for the season summary (called from `post`).
    mutating func trackMoney(_ text: String, _ amount: Int) {
        let k = MoneyCategory.of(text, amount: amount).rawValue
        seasonMoney[k, default: 0] += amount
    }

    func seasonTotal(_ c: MoneyCategory) -> Int { seasonMoney[c.rawValue] ?? 0 }

    /// Ticket money expected from the user's next home match (before form changes it).
    var expectedGate: (fans: Int, money: Int)? {
        guard let f = fixtures.first(where: { !$0.played && $0.home == userClubId }) else { return nil }
        let opp = f.away
        let wins = userForm().filter { $0 }.count
        var fill = 0.55 + 0.06 * Double(wins) + (position(of: opp) <= 4 ? 0.1 : 0) + settings.ticketPrice.fillDelta
        fill = max(0.3, min(1.0, fill))
        let money = Career.round5(Double(gate(for: userClubId)) * fill * 1.3 * difficulty.incomeMult * settings.ticketPrice.priceMult)
        return (Int(Double(stadiumCapacity) * fill / 100) * 100, money)
    }

    /// Runs this week's training now and reports who improved. Without it, training runs on its
    /// own after the next match.
    @discardableResult
    mutating func runTrainingSession() -> [String] {
        guard phase == .season, !trainingDoneThisWeek else { return [] }
        let ids = userClub.squad + academy
        let before = Dictionary(uniqueKeysWithValues: ids.compactMap { id in players[id].map { (id, $0.attr) } })
        trainingTick()
        trainingDoneThisWeek = true
        var lines: [String] = []
        for id in ids.sorted() {
            guard let old = before[id], let p = players[id] else { continue }
            let gains = Attributes.trainable.compactMap { t -> String? in
                let d = p.attr[keyPath: t.key] - old[keyPath: t.key]
                return d > 0 ? "\(t.label) +\(d)" : nil
            }
            if !gains.isEmpty { lines.append("\(p.name): \(gains.joined(separator: ", "))") }
        }
        addNews(.squad, lines.isEmpty ? "Training session done: no visible gains this week." : "Training session: \(lines.count) players improved.")
        return lines
    }
}
