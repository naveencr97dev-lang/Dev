import Foundation

struct SaleRecord: Codable, Hashable, Identifiable {
    var id: String { playerId }
    let playerId: String
    let teamId: Int?      // nil = unsold
    let price: Int
}

struct AuctionState: Codable, Hashable {
    var queue: [String] = []
    var index: Int = 0
    /// 1 = main auction, 2 = accelerated round of unsold players.
    var round: Int = 1
    var unsold: [String] = []
    var currentBid: Int? = nil
    var leader: Int? = nil
    /// Hidden CPU price limits for the current lot (team id -> lakhs).
    var cpuLimits: [Int: Int] = [:]
    var history: [SaleRecord] = []
    var finished: Bool = false
    /// True once the hammer has fallen on the current lot (until the next lot is prepared).
    var lotClosed: Bool = false

    var currentPlayerId: String? { index < queue.count ? queue[index] : nil }
}

enum AuctionEngine {
    static let poolOrder = ["Marquee", "Batters", "All-rounders", "Wicket-keepers", "Bowlers", "Uncapped"]

    // MARK: Setup

    static func buildQueue(players: [Player], teamCount: Int, rules: Rules, rng: inout SeededRNG) -> [String] {
        var chosen = players
        if rules.poolSize == .quick {
            let target = min(players.count, teamCount * 17)
            chosen = Array(players.sorted { $0.rating > $1.rating }.prefix(target))
        }
        var queue: [String] = []
        for pool in poolOrder {
            queue += chosen.filter { $0.pool == pool }.shuffled(using: &rng).map(\.id)
        }
        // Anything in an unknown pool goes last.
        let known = Set(queue)
        queue += chosen.filter { !known.contains($0.id) }.map(\.id)
        return queue
    }

    // MARK: Bidding rules

    /// IPL-style increments: +5 L below 1 Cr, +10 L to 2 Cr, +20 L to 5 Cr, +25 L above.
    static func increment(after bid: Int) -> Int {
        switch bid {
        case ..<100: return 5
        case ..<200: return 10
        case ..<500: return 20
        default: return 25
        }
    }

    static func nextBid(_ state: AuctionState, base: Int) -> Int {
        guard let bid = state.currentBid else { return base }
        return bid + increment(after: bid)
    }

    /// The most a team can spend on one player while still affording a minimum squad.
    static func maxAffordable(_ team: Franchise, rules: Rules) -> Int {
        let stillNeeded = max(0, rules.minSquad - team.squad.count - 1)
        return team.purse - stillNeeded * rules.minBase
    }

    static func overseasCount(_ team: Franchise, players: [String: Player]) -> Int {
        team.squad.filter { players[$0]?.overseas == true }.count
    }

    /// Overseas slots still open, keeping room for enough Indian players to field a legal XI.
    static func overseasRoom(_ team: Franchise, rules: Rules, players: [String: Player]) -> Int {
        let os = overseasCount(team, players: players)
        let indian = team.squad.count - os
        let indianNeeded = max(0, (11 - rules.maxOverseasXI) - indian)
        let bySquad = rules.maxSquad - team.squad.count - indianNeeded
        return max(0, min(rules.maxOverseasSquad - os, bySquad))
    }

    static func canBid(_ team: Franchise, on player: Player, amount: Int, rules: Rules, players: [String: Player]) -> Bool {
        blockReason(team, on: player, amount: amount, rules: rules, players: players) == nil
    }

    /// Why a team can't bid, for the UI.
    static func blockReason(_ team: Franchise, on player: Player, amount: Int, rules: Rules, players: [String: Player]) -> String? {
        if team.squad.count >= rules.maxSquad { return "Squad full" }
        if player.overseas && overseasRoom(team, rules: rules, players: players) == 0 { return "Overseas full" }
        if amount > maxAffordable(team, rules: rules) { return "Can't afford" }
        return nil
    }

    // MARK: CPU valuation

    /// Rough fair price for a player in lakhs, scaled to the purse size.
    static func fairValue(_ p: Player, rules: Rules) -> Double {
        let r = Double(p.rating)
        let star = pow(max(0, r - 40) / 48, 2.2) * 1600
        return (Double(p.base) + star) * Double(rules.purse) / 10_000
    }

    static func cpuLimit(team: Franchise, player p: Player, rules: Rules, players: [String: Player], rng: inout SeededRNG) -> Int {
        let squad = team.squad.compactMap { players[$0] }
        var v = fairValue(p, rules: rules)

        let wks = squad.filter { $0.role == .WK }.count
        let bowlers = squad.filter(\.isBowlingOption).count
        let bats = squad.filter(\.isTopOrderBat).count
        var fillsNeed = false
        if p.role == .WK && wks == 0 { v *= 1.4; fillsNeed = true }
        if p.isBowlingOption && bowlers < 6 { v *= 1.25; fillsNeed = true }
        if p.isTopOrderBat && bats < 5 { v *= 1.2; fillsNeed = true }
        if team.squad.count >= rules.maxSquad - 2 { v *= 0.6 }
        if squad.count >= 15 && !fillsNeed { v *= 0.7 }
        if p.overseas && squad.filter(\.overseas).count >= 6 { v *= 0.6 }

        v *= team.personality * rng.range(0.8, 1.25)

        // Budget pacing: don't blow the purse on one player early on.
        let slotsLeft = Double(max(1, 16 - squad.count))
        v = min(v, Double(team.purse) / slotsLeft * 2.6)
        v = max(v, Double(p.base) * (p.rating >= 45 ? 1.0 : 0.0))
        return min(Int(v), maxAffordable(team, rules: rules))
    }

    static func prepareLot(_ state: inout AuctionState, teams: [Franchise], rules: Rules, players: [String: Player], rng: inout SeededRNG) {
        state.currentBid = nil
        state.leader = nil
        state.cpuLimits = [:]
        state.lotClosed = false
        guard let pid = state.currentPlayerId, let p = players[pid] else { return }
        for t in teams where t.isCPU {
            state.cpuLimits[t.id] = cpuLimit(team: t, player: p, rules: rules, players: players, rng: &rng)
        }
    }

    /// A CPU team willing to make the next bid, if any.
    static func cpuBidder(_ state: AuctionState, teams: [Franchise], rules: Rules, players: [String: Player], rng: inout SeededRNG) -> Int? {
        guard !state.lotClosed, let pid = state.currentPlayerId, let p = players[pid] else { return nil }
        let amount = nextBid(state, base: p.base)
        let keen = teams.filter { t in
            t.isCPU && t.id != state.leader
                && (state.cpuLimits[t.id] ?? 0) >= amount
                && canBid(t, on: p, amount: amount, rules: rules, players: players)
        }
        guard !keen.isEmpty else { return nil }
        // Teams with more headroom are a little more likely to jump in.
        let weights = keen.map { Double((state.cpuLimits[$0.id] ?? amount) - amount + 50) }
        return keen[rng.weighted(weights)].id
    }

    @discardableResult
    static func placeBid(_ state: inout AuctionState, teamId: Int, teams: [Franchise], rules: Rules, players: [String: Player]) -> Bool {
        guard !state.lotClosed, let pid = state.currentPlayerId, let p = players[pid],
              let team = teams.first(where: { $0.id == teamId }),
              state.leader != teamId else { return false }
        let amount = nextBid(state, base: p.base)
        guard canBid(team, on: p, amount: amount, rules: rules, players: players) else { return false }
        state.currentBid = amount
        state.leader = teamId
        return true
    }

    /// Close the current lot. Returns the sale record.
    @discardableResult
    static func hammer(_ state: inout AuctionState, teams: inout [Franchise]) -> SaleRecord? {
        guard !state.lotClosed, let pid = state.currentPlayerId else { return nil }
        state.lotClosed = true
        let record: SaleRecord
        if let leader = state.leader, let bid = state.currentBid, let i = teams.firstIndex(where: { $0.id == leader }) {
            teams[i].squad.append(pid)
            teams[i].paid[pid] = bid
            teams[i].purse -= bid
            record = SaleRecord(playerId: pid, teamId: leader, price: bid)
        } else {
            state.unsold.append(pid)
            record = SaleRecord(playerId: pid, teamId: nil, price: 0)
        }
        state.history.append(record)
        return record
    }

    /// Move to the next lot, starting the accelerated round or finishing as needed.
    static func advance(_ state: inout AuctionState, teams: [Franchise], rules: Rules, players: [String: Player], rng: inout SeededRNG) {
        state.index += 1
        if state.index >= state.queue.count {
            let anyRoom = teams.contains { $0.squad.count < rules.maxSquad }
            if state.round == 1 && !state.unsold.isEmpty && anyRoom {
                state.round = 2
                state.queue = state.unsold.shuffled(using: &rng)
                state.unsold = []
                state.index = 0
            } else {
                state.finished = true
                state.currentBid = nil
                state.leader = nil
                return
            }
        }
        if teams.allSatisfy({ $0.squad.count >= rules.maxSquad }) {
            state.finished = true
            return
        }
        prepareLot(&state, teams: teams, rules: rules, players: players, rng: &rng)
    }

    /// Resolve the current lot instantly with CPU teams only (used by "Sim rest").
    static func autoResolveLot(_ state: inout AuctionState, teams: inout [Franchise], rules: Rules, players: [String: Player], rng: inout SeededRNG) -> SaleRecord? {
        var guardCount = 0
        while let bidder = cpuBidder(state, teams: teams, rules: rules, players: players, rng: &rng), guardCount < 500 {
            placeBid(&state, teamId: bidder, teams: teams, rules: rules, players: players)
            guardCount += 1
        }
        return hammer(&state, teams: &teams)
    }

    /// After the auction, top up any squad below the minimum with unsold players at base price.
    static func autofill(teams: inout [Franchise], allPlayers: [Player], rules: Rules, players: [String: Player]) {
        var taken = Set(teams.flatMap(\.squad))
        let pool = allPlayers.sorted { $0.rating > $1.rating }
        let indianNeeded = 11 - rules.maxOverseasXI
        func indians(_ t: Franchise) -> Int { t.squad.count - overseasCount(t, players: players) }
        for i in teams.indices {
            for p in pool {
                let short = teams[i].squad.count < rules.minSquad
                let needIndian = indians(teams[i]) < indianNeeded
                guard short || needIndian, !taken.contains(p.id) else { continue }
                if p.overseas && (needIndian || overseasRoom(teams[i], rules: rules, players: players) == 0) { continue }
                let price = min(p.base, max(0, teams[i].purse))
                teams[i].squad.append(p.id)
                teams[i].paid[p.id] = price
                teams[i].purse -= price
                taken.insert(p.id)
            }
        }
    }
}
