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
    /// Sorts by a season/all-time stat (the market shows that stat as a column).
    var isStat: Bool { [.runs, .wickets, .strikeRate, .economy, .sixes].contains(self) }
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
        LiveReport.rating(id, cards: r.innings, winnerId: r.winnerId, potmId: r.potmId)
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

// MARK: - Recent matches (the player card's "Last 5")

/// One match for one player: who against, when, what he did with bat and ball, and his rating.
struct PlayerMatchLine: Hashable {
    let resultId: UUID
    let opponent: Int
    let day: Int?
    let won: Bool
    /// nil = didn't bat.
    let runs: Int?
    let balls: Int
    let notOut: Bool
    /// nil = didn't bowl.
    let wickets: Int?
    let conceded: Int
    let overs: String
    let rating: Double
}

extension Career {
    /// The player's last `n` matches this season, newest first.
    func recentMatches(_ id: String, last n: Int = 5) -> [PlayerMatchLine] {
        var out: [PlayerMatchLine] = []
        for r in results.reversed() {
            let inns = Array(r.innings.prefix(2))
            guard let batInn = inns.first(where: { $0.batters.contains { $0.id == id } }),
                  let rating = Career.matchRating(id, in: r) else { continue }
            let bat = batInn.batters.first { $0.id == id }
            let bowl = inns.first { $0.teamId != batInn.teamId }?.bowlers.first { $0.id == id && $0.balls > 0 }
            let opponent = r.teamA == batInn.teamId ? r.teamB : r.teamA
            let day = fixtures.first { $0.resultId == r.id }.map { self.day(of: $0) }
            out.append(PlayerMatchLine(resultId: r.id, opponent: opponent, day: day, won: r.winnerId == batInn.teamId,
                                       runs: bat?.batted == true ? bat?.runs : nil, balls: bat?.balls ?? 0,
                                       notOut: bat?.batted == true && bat?.dismissal == nil,
                                       wickets: bowl?.wickets, conceded: bowl?.runs ?? 0, overs: bowl?.overs ?? "",
                                       rating: rating))
            if out.count == n { break }
        }
        return out
    }
}
