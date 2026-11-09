import Foundation

// Career › Settings: difficulty and test switches (schema 8).

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy, normal, hard, legend
    var id: String { rawValue }
    private var i: Int { Difficulty.allCases.firstIndex(of: self)! }

    var label: String { rawValue.capitalized }
    var blurb: String {
        switch self {
        case .easy: return "Your players +3, cheaper transfers, richer club, calmer rivals"
        case .normal: return "The standard game"
        case .hard: return "Your players −2, pricier transfers, less money, sharper rivals"
        case .legend: return "Your players −4, steep prices, tight money, ruthless rivals"
        }
    }
    /// Rating points added to the user's players in matches.
    var userBoost: Int { [3, 0, -2, -4][i] }
    /// Asking prices and wage demands when the user buys.
    var priceMult: Double { [0.8, 1, 1.2, 1.4][i] }
    /// How hard AI clubs bid at auctions.
    var aiBidMult: Double { [0.9, 1, 1.1, 1.2][i] }
    /// The user's club income (revenue, prizes, tickets, merchandise).
    var incomeMult: Double { [1.25, 1, 0.85, 0.7][i] }
}

struct CareerSettings: Codable, Hashable {
    var difficulty: Difficulty = .normal
    /// Testing: the transfer market never closes.
    var marketAlwaysOpen = true
    /// Schema 9.
    var ticketPrice: TicketPrice = .normal
    /// Schema 11: the assistant picks the best XI before each match (panel round 3: CONTINUE-only
    /// players fielded a clearly weaker side in 45% of matches). Picking the XI by hand turns it off.
    var assistantPicksXI = true
}

extension Career {
    var difficulty: Difficulty { settings.difficulty }

    /// What a player asks the user to pay per season (difficulty and the Negotiator perk applied).
    func userWageDemand(_ p: CareerPlayer) -> Int {
        Career.round5(Double(wageDemand(p)) * difficulty.priceMult * (manager.has(.negotiator) ? 0.9 : 1))
    }

    // MARK: Weekly income (Career › Club › Finances)

    /// Stadium capacity by Stadium level.
    var stadiumCapacity: Int { 10_000 + 5_000 * facility(.stadium) }

    /// Ticket sales and merchandise after each of the user's matches.
    mutating func weeklyIncome(after r: MatchResult) {
        let opp = r.teamA == userClubId ? r.teamB : r.teamA
        if r.teamA == userClubId, club(opp) != nil {
            let wins = userForm().filter { $0 }.count
            let topOpponent = position(of: opp) <= 4
            var fill = 0.55 + 0.06 * Double(wins) + (topOpponent ? 0.1 : 0) + (r.stage != .league ? 0.2 : 0)
                + settings.ticketPrice.fillDelta
            fill = max(0.3, min(1.0, fill))
            let fans = Int(Double(stadiumCapacity) * fill / 100) * 100
            let money = Career.round5(Double(gate(for: userClubId)) * fill * 1.3 * difficulty.incomeMult * settings.ticketPrice.priceMult)
            post(userClubId, "Tickets: \(fans.formatted()) fans vs \(club(opp)?.short ?? "")", money)
        }
        let merch = Career.round5(Double(commercialIncome(for: userClubId)) / 36 * difficulty.incomeMult)
        if merch > 0 { post(userClubId, "Merchandise sales", merch) }
    }

    // MARK: Gold → cash (testing and shortcuts)

    /// 1 gold = ₹1 lakh into the bank.
    @discardableResult
    mutating func exchangeGold(_ amount: Int) -> String? {
        guard amount > 0 else { return nil }
        if gold < amount { return "You need \(amount) gold." }
        gold -= amount
        post(userClubId, "Cash from gold", amount)
        return nil
    }
}
