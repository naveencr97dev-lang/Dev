import Foundation

/// All players, loaded once from players.json.
struct PlayerBook {
    let all: [Player]
    let byId: [String: Player]

    init(_ players: [Player]) {
        all = players
        byId = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    subscript(_ id: String) -> Player? { byId[id] }
}

enum Phase: String, Codable {
    case setup, auction, squads, season, champion
}

/// The whole saved game. Pure value type: every rule lives here or in the engines,
/// so the full flow can be unit-tested without the UI.
struct GameState: Codable {
    var phase: Phase = .setup
    var rules = Rules()
    var teams: [Franchise] = []
    var auction = AuctionState()
    var fixtures: [Fixture] = []
    var results: [MatchResult] = []
    var championId: Int? = nil
    var rng: SeededRNG

    // MARK: Setup

    static func newSetup(seed: UInt64) -> GameState {
        var g = GameState(rng: SeededRNG(seed: seed))
        g.teams = (0..<4).map { i in
            let t = FranchiseTemplate.all[i]
            return Franchise(id: i, name: t.name, short: t.short, colorHex: t.color, isCPU: i >= 3)
        }
        return g
    }

    func team(_ id: Int) -> Franchise? { teams.first { $0.id == id } }

    mutating func startAuction(book: PlayerBook) {
        let temperaments = [0.9, 1.0, 1.1, 1.2, 0.95, 1.05, 1.15, 0.85, 1.0, 1.1]
        for i in teams.indices {
            teams[i].purse = rules.purse
            teams[i].squad = []
            teams[i].paid = [:]
            teams[i].xi = []
            teams[i].personality = temperaments[i % temperaments.count]
        }
        auction = AuctionState()
        auction.queue = AuctionEngine.buildQueue(players: book.all, teamCount: teams.count, rules: rules, rng: &rng)
        AuctionEngine.prepareLot(&auction, teams: teams, rules: rules, players: book.byId, rng: &rng)
        phase = .auction
    }

    // MARK: Auction

    func nextBidAmount(book: PlayerBook) -> Int? {
        guard let pid = auction.currentPlayerId, let p = book[pid] else { return nil }
        return AuctionEngine.nextBid(auction, base: p.base, step: rules.bidStep)
    }

    @discardableResult
    mutating func bid(teamId: Int, book: PlayerBook) -> Bool {
        AuctionEngine.placeBid(&auction, teamId: teamId, teams: teams, rules: rules, players: book.byId)
    }

    /// Lets one interested CPU team bid. Returns its id.
    mutating func cpuBid(book: PlayerBook) -> Int? {
        guard let id = AuctionEngine.cpuBidder(auction, teams: teams, rules: rules, players: book.byId, rng: &rng) else { return nil }
        return bid(teamId: id, book: book) ? id : nil
    }

    mutating func hammer() -> SaleRecord? {
        AuctionEngine.hammer(&auction, teams: &teams)
    }

    /// Skip watching a lot: CPU teams settle it instantly (humans stop bidding), then hammer.
    mutating func skipLot(book: PlayerBook) -> SaleRecord? {
        AuctionEngine.autoResolveLot(&auction, teams: &teams, rules: rules, players: book.byId, rng: &rng)
    }

    func needs(_ teamId: Int, book: PlayerBook) -> AuctionEngine.Needs {
        guard let t = team(teamId) else { return .init() }
        return AuctionEngine.needs(t, players: book.byId)
    }

    mutating func nextLot(book: PlayerBook) {
        AuctionEngine.advance(&auction, teams: teams, rules: rules, players: book.byId, rng: &rng)
        if auction.finished { finishAuction(book: book) }
    }

    /// Resolves every remaining lot with CPU bidding only.
    mutating func simRestOfAuction(book: PlayerBook) {
        // Close the lot in progress as it stands.
        if auction.currentPlayerId != nil && !auction.finished {
            _ = hammer()
            AuctionEngine.advance(&auction, teams: teams, rules: rules, players: book.byId, rng: &rng)
        }
        var guardCount = 0
        while !auction.finished && guardCount < 2000 {
            _ = AuctionEngine.autoResolveLot(&auction, teams: &teams, rules: rules, players: book.byId, rng: &rng)
            AuctionEngine.advance(&auction, teams: teams, rules: rules, players: book.byId, rng: &rng)
            guardCount += 1
        }
        finishAuction(book: book)
    }

    mutating func finishAuction(book: PlayerBook) {
        auction.finished = true
        AuctionEngine.autofill(teams: &teams, allPlayers: book.all, rules: rules, players: book.byId)
        for i in teams.indices {
            teams[i].xi = TeamSelector.battingOrder(teams[i].squad.compactMap { book[$0] }).map(\.id)
        }
        phase = .squads
    }

    mutating func setXI(teamId: Int, ids: [String]) {
        guard let i = teams.firstIndex(where: { $0.id == teamId }) else { return }
        teams[i].xi = ids
    }

    // MARK: Season

    mutating func startSeason() {
        fixtures = SeasonEngine.leagueFixtures(teamIds: teams.map(\.id), double: rules.doubleRoundRobin, rng: &rng)
        for i in fixtures.indices { fixtures[i].pitch = drawPitch() }
        results = []
        championId = nil
        phase = .season
    }

    mutating func drawPitch() -> Pitch {
        switch rules.pitchMode {
        case .fixed(let p): return p
        case .mixed: return Pitch.allCases.randomElement(using: &rng) ?? .indianFlat
        }
    }

    var nextFixture: Fixture? { fixtures.first { !$0.played } }
    var leagueFixtureCount: Int { fixtures.filter { $0.stage == .league }.count }
    var leagueResults: [MatchResult] { results.filter { $0.stage == .league } }
    var table: [TableRow] { SeasonEngine.table(teamIds: teams.map(\.id), results: results) }

    func result(_ id: UUID?) -> MatchResult? {
        guard let id else { return nil }
        return results.first { $0.id == id }
    }

    func isHumanFixture(_ f: Fixture) -> Bool {
        (team(f.home).map { !$0.isCPU } ?? false) || (team(f.away).map { !$0.isCPU } ?? false)
    }

    func side(_ teamId: Int, book: PlayerBook) -> MatchEngine.Side {
        let t = team(teamId)!
        var xi = t.xi.compactMap { book[$0] }
        if xi.count != 11 {
            xi = TeamSelector.autoXI(squad: t.squad.compactMap { book[$0] }, rules: rules).compactMap { book[$0] }
        }
        return MatchEngine.Side(teamId: teamId, xi: xi)
    }

    /// Plays a fixture, records the result and schedules playoffs / crowns the champion.
    mutating func play(fixtureId: Int, book: PlayerBook) -> (MatchResult, [BallEvent])? {
        guard let fi = fixtures.firstIndex(where: { $0.id == fixtureId }), !fixtures[fi].played else { return nil }
        let f = fixtures[fi]
        var engine = MatchEngine(rng: rng)
        var log: [BallEvent] = []
        let r = engine.play(side(f.home, book: book), side(f.away, book: book), stage: f.stage, pitch: f.pitch, log: &log)
        rng = engine.rng
        results.append(r)
        fixtures[fi].resultId = r.id

        if f.stage == .final {
            // The UI moves to the trophy ceremony when the player is ready (see finishSeason).
            championId = r.winnerId
        } else if nextFixture == nil {
            let playoffResults = results.filter { $0.stage != .league }
            if var next = SeasonEngine.nextPlayoff(table: table, playoffResults: playoffResults, nextId: fixtures.count + 1) {
                next.pitch = drawPitch()
                fixtures.append(next)
            }
        }
        return (r, log)
    }

    mutating func finishSeason() {
        if championId != nil { phase = .champion }
    }

    /// Back from the trophy ceremony to browse results, table and stats.
    mutating func reopenSeason() {
        if championId != nil { phase = .season }
    }

    // MARK: Awards

    struct Awards {
        var orangeCap: PlayerSeason?
        var purpleCap: PlayerSeason?
        var mvp: PlayerSeason?
        var bestBuy: (PlayerSeason, Int)?
        var mostSixes: PlayerSeason?
    }

    func awards() -> Awards {
        let stats = SeasonEngine.playerStats(results: results)
        let vals = Array(stats.values)
        var a = Awards()
        a.orangeCap = vals.max { ($0.runs, $1.ballsFaced) < ($1.runs, $0.ballsFaced) }
        a.purpleCap = vals.max { ($0.wickets, $1.economy) < ($1.wickets, $0.economy) }
        a.mvp = vals.max { $0.mvpPoints < $1.mvpPoints }
        a.mostSixes = vals.max { $0.sixes < $1.sixes }
        var best: (PlayerSeason, Int)? = nil
        var bestValue = 0.0
        for s in vals {
            guard let t = team(s.teamId), let price = t.paid[s.id], price > 0 else { continue }
            let value = s.mvpPoints / (Double(price) / 100)
            if s.mvpPoints >= 60 && value > bestValue { bestValue = value; best = (s, price) }
        }
        a.bestBuy = best
        return a
    }
}
