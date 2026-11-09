import Foundation

/// One player's numbers in one finished season (kept on the player for the profile).
struct SeasonLine: Codable, Hashable {
    let year: Int
    let club: String
    var matches = 0
    var runs = 0
    var balls = 0
    var highScore = 0
    var sixes = 0
    var wickets = 0
    var ballsBowled = 0
    var runsConceded = 0
}

/// Batting and bowling numbers over a period (this season or all-time).
struct StatLine: Hashable {
    var matches = 0
    var runs = 0
    var balls = 0
    var fours = 0
    var sixes = 0
    var highScore = 0
    var fifties = 0
    var hundreds = 0
    var wickets = 0
    var ballsBowled = 0
    var runsConceded = 0
    var potm = 0

    var strikeRate: Double { balls == 0 ? 0 : Double(runs) * 100 / Double(balls) }
    var economy: Double { ballsBowled == 0 ? 0 : Double(runsConceded) * 6 / Double(ballsBowled) }
    var runsPerMatch: Double { matches == 0 ? 0 : Double(runs) / Double(matches) }
    var isEmpty: Bool { matches == 0 }

    init() {}
    init(_ s: CareerStats) {
        matches = s.matches; runs = s.runs; balls = s.ballsFaced; fours = s.fours; sixes = s.sixes
        highScore = s.highScore; fifties = s.fifties; hundreds = s.hundreds; wickets = s.wickets
        ballsBowled = s.ballsBowled; runsConceded = s.runsConceded; potm = s.potm
    }
    init(_ s: PlayerSeason) {
        matches = s.matches; runs = s.runs; balls = s.ballsFaced; fours = s.fours; sixes = s.sixes
        highScore = s.highScore; wickets = s.wickets; ballsBowled = s.ballsBowled
        runsConceded = s.runsConceded; potm = s.potm
    }
}

enum StatScope: String, CaseIterable { case season, allTime }

enum MarketSort: String, CaseIterable, Identifiable {
    case rating, potential, value, runs, wickets, strikeRate, economy, sixes, age
    var id: String { rawValue }
    var label: String {
        switch self {
        case .rating: return "Rating"
        case .potential: return "Potential"
        case .value: return "Value"
        case .runs: return "Runs"
        case .wickets: return "Wickets"
        case .strikeRate: return "Strike rate"
        case .economy: return "Economy"
        case .sixes: return "Sixes"
        case .age: return "Youngest"
        }
    }
}

extension Career {
    /// This season's numbers for every player who has played (club league and playoffs).
    var seasonStatLines: [String: StatLine] {
        SeasonEngine.playerStats(results: results).mapValues { StatLine($0) }
    }

    func statLine(_ id: String, scope: StatScope, season: [String: StatLine]? = nil) -> StatLine {
        switch scope {
        case .season: return (season ?? seasonStatLines)[id] ?? StatLine()
        case .allTime: return players[id].map { StatLine($0.stats) } ?? StatLine()
        }
    }

    /// Minimum balls before strike rate / economy rankings count (smaller early in a season).
    func minBalls(_ scope: StatScope) -> Int { scope == .allTime ? 120 : max(12, leaguePlayed / 10 * 2) }

    /// Sorted list of players to buy (or to rank), best first by `sort`.
    /// - slot: preferred batting slot (opener, top order…); bowlType: pace or spin bowlers only.
    func marketPlayers(role: Role? = nil, slot: BatSlot? = nil, bowlType: BowlType? = nil, freeAgentsOnly: Bool = false,
                       sort: MarketSort = .rating, scope: StatScope = .season, limit: Int = 600) -> [CareerPlayer] {
        let season = seasonStatLines
        let pool = players.values.filter {
            !$0.retired && $0.clubId != userClubId && $0.academyOf == nil
                && (role == nil || $0.role == role) && (!freeAgentsOnly || $0.clubId == nil)
                && (slot == nil || $0.slot == slot)
                && (bowlType == nil || ($0.bowlType == bowlType && $0.bowl >= 40))
        }
        return ranked(pool, sort: sort, scope: scope, season: season).prefix(limit).map { $0 }
    }

    func ranked(_ pool: [CareerPlayer], sort: MarketSort, scope: StatScope, season: [String: StatLine]) -> [CareerPlayer] {
        let minB = minBalls(scope)
        func key(_ p: CareerPlayer) -> Double {
            let s = statLine(p.id, scope: scope, season: season)
            switch sort {
            case .rating: return Double(p.rating)
            case .potential: return Double(potentialRange(p).upperBound)
            case .value: return Double(p.value(in: year))
            case .runs: return Double(s.runs)
            case .wickets: return Double(s.wickets) - s.economy / 100
            case .strikeRate: return s.balls >= minB ? s.strikeRate : -1
            case .economy: return s.ballsBowled >= minB ? -s.economy : -100
            case .sixes: return Double(s.sixes)
            case .age: return -Double(p.age(in: year))
            }
        }
        return pool.map { ($0, key($0)) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.id < $1.0.id }
            .map(\.0)
    }

    /// Everyone (any club, free agents, notable retirees) for the stats centre.
    func leaders(_ sort: MarketSort, scope: StatScope, limit: Int = 10) -> [CareerPlayer] {
        let season = seasonStatLines
        let pool = players.values.filter { !statLine($0.id, scope: scope, season: season).isEmpty }
        return Array(ranked(pool, sort: sort, scope: scope, season: season).prefix(limit))
    }

    /// Writes each player's finished season into their season log (called at season end).
    mutating func archiveSeasonStats() {
        let season = SeasonEngine.playerStats(results: results)
        for (id, s) in season.sorted(by: { $0.key < $1.key }) {
            guard players[id] != nil else { continue }
            let line = SeasonLine(year: year, club: club(s.teamId)?.short ?? "", matches: s.matches, runs: s.runs,
                                  balls: s.ballsFaced, highScore: s.highScore, sixes: s.sixes, wickets: s.wickets,
                                  ballsBowled: s.ballsBowled, runsConceded: s.runsConceded)
            var log = players[id]?.seasonLog ?? []
            log.append(line)
            if log.count > 12 { log.removeFirst(log.count - 12) }
            players[id]?.seasonLog = log
        }
    }
}

// MARK: - Match ratings (Career › Stats). Every player who played gets a 3.0-10.0 rating per match,
// worked out from the scorecard: runs and strike rate, wickets and economy, a duck, the result and
// player of the match. Computed from results, so nothing new is saved.

extension Career {
    static func matchRating(_ id: String, in r: MatchResult) -> Double? {
        let inns = Array(r.innings.prefix(2))
        guard let batInn = inns.first(where: { $0.batters.contains { $0.id == id } }),
              let card = batInn.batters.first(where: { $0.id == id }) else { return nil }
        var x = 6.0
        if card.batted {
            x += Double(card.runs - 18) / 20
            if card.balls >= 8 { x += (card.strikeRate - 135) / 110 }
            if card.runs == 0 && card.dismissal != nil { x -= 0.8 }
            if card.runs >= 50 { x += 0.3 }
            if card.runs >= 100 { x += 0.4 }
        }
        if let bowl = inns.first(where: { $0.teamId != batInn.teamId })?.bowlers.first(where: { $0.id == id }), bowl.balls > 0 {
            x += Double(bowl.wickets) * 0.5
            if bowl.balls >= 12 { x += (8.5 - bowl.economy) / 3.5 }
        }
        if r.winnerId == batInn.teamId { x += 0.3 }
        if r.potmId == id { x += 0.3 }
        // Soft edges: big days still stand out, but a 9 or 10 is rare and a 3 rarer.
        if x > 8 { x = 8 + (x - 8) * 0.45 }
        if x < 5 { x = 5 - (5 - x) * 0.6 }
        return (max(3, min(10, x)) * 10).rounded() / 10
    }

    /// This season's match ratings for a player, oldest first.
    func matchRatings(_ id: String) -> [Double] {
        results.compactMap { Career.matchRating(id, in: $0) }
    }

    /// Average match rating this season (nil before the first match).
    func averageRating(_ id: String) -> Double? {
        let xs = matchRatings(id)
        return xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count)
    }

    /// The last five ratings, newest last (the "form" line on the profile).
    func recentRatings(_ id: String, last n: Int = 5) -> [Double] { Array(matchRatings(id).suffix(n)) }

    /// Rating change this season (training and growth), for the development report.
    func seasonProgress(_ p: CareerPlayer) -> Int? { p.seasonStartRating.map { p.rating - $0 } }

    /// The user's young players (23 and under) and academy prospects, youngest first.
    var developmentWatch: [CareerPlayer] {
        (squad(userClubId).filter { $0.age(in: year) <= 23 } + academy.compactMap { players[$0] })
            .sorted { $0.age(in: year) != $1.age(in: year) ? $0.age(in: year) < $1.age(in: year) : $0.id < $1.id }
    }
}
