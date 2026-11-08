import XCTest
@testable import AuctionEngine

final class EngineTests: XCTestCase {
    static let players: [Player] = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/players.json")
        return try! PlayerDB.decode(Data(contentsOf: url))
    }()
    var players: [Player] { Self.players }
    var byId: [String: Player] { Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) }) }

    func makeTeams(_ n: Int, rules: Rules) -> [Franchise] {
        (0..<n).map { i in
            let t = FranchiseTemplate.all[i]
            return Franchise(id: i, name: t.name, short: t.short, colorHex: t.color, isCPU: true,
                             purse: rules.purse, personality: [0.9, 1.0, 1.1, 1.2][i % 4])
        }
    }

    /// Runs a whole auction with CPU teams only.
    func runAuction(teams n: Int, rules: Rules, seed: UInt64) -> [Franchise] {
        var rng = SeededRNG(seed: seed)
        var teams = makeTeams(n, rules: rules)
        var state = AuctionState()
        state.queue = AuctionEngine.buildQueue(players: players, teamCount: n, rules: rules, rng: &rng)
        AuctionEngine.prepareLot(&state, teams: teams, rules: rules, players: byId, rng: &rng)
        while !state.finished {
            _ = AuctionEngine.autoResolveLot(&state, teams: &teams, rules: rules, players: byId, rng: &rng)
            AuctionEngine.advance(&state, teams: teams, rules: rules, players: byId, rng: &rng)
        }
        AuctionEngine.autofill(teams: &teams, allPlayers: players, rules: rules, players: byId)
        return teams
    }

    func testPlayerData() {
        XCTAssertEqual(players.count, 273)
        XCTAssertEqual(Set(players.map(\.id)).count, players.count)
    }

    func testIncrementsAndMoney() {
        XCTAssertEqual(AuctionEngine.increment(after: 30), 5)
        XCTAssertEqual(AuctionEngine.increment(after: 150), 10)
        XCTAssertEqual(AuctionEngine.increment(after: 300), 20)
        XCTAssertEqual(AuctionEngine.increment(after: 1200), 25)
        XCTAssertEqual(Money.format(75), "₹75 L")
        XCTAssertEqual(Money.format(200), "₹2 Cr")
        XCTAssertEqual(Money.format(1225), "₹12.25 Cr")
    }

    func testAuctionProducesValidSquads() {
        for (n, seed) in [(3, 1), (8, 2), (10, 3)] as [(Int, UInt64)] {
            var rules = Rules()
            for pool in PoolSize.allCases {
                rules.poolSize = pool
                let teams = runAuction(teams: n, rules: rules, seed: seed)
                for t in teams {
                    XCTAssertGreaterThanOrEqual(t.squad.count, rules.minSquad, "\(t.name) n=\(n)")
                    XCTAssertLessThanOrEqual(t.squad.count, rules.maxSquad)
                    XCTAssertGreaterThanOrEqual(t.purse, 0)
                    XCTAssertLessThanOrEqual(AuctionEngine.overseasCount(t, players: byId), rules.maxOverseasSquad)
                    let xi = TeamSelector.autoXI(squad: t.squad.compactMap { byId[$0] }, rules: rules)
                    XCTAssertEqual(Set(xi).count, 11)
                    XCTAssertTrue(TeamSelector.blockingIssues(xi.compactMap { byId[$0] }, rules: rules).isEmpty)
                }
                let all = teams.flatMap(\.squad)
                XCTAssertEqual(Set(all).count, all.count, "player sold twice")
            }
            let teams = runAuction(teams: n, rules: Rules(), seed: seed)
            let spent = teams.map { Rules().purse - $0.purse }
            print("auction n=\(n): squads \(teams.map(\.squad.count)) spent \(spent.map(Money.format))")
            if n == 8 {
                let top = teams.flatMap { t in t.paid.map { ($0.key, $0.value) } }.sorted { $0.1 > $1.1 }.prefix(5)
                print("  top buys:", top.map { "\(byId[$0.0]!.name) \(Money.format($0.1))" })
            }
        }
    }

    func testHumanBidRules() {
        let rules = Rules()
        var teams = makeTeams(3, rules: rules)
        teams[0].isCPU = false
        var rng = SeededRNG(seed: 9)
        var state = AuctionState()
        state.queue = AuctionEngine.buildQueue(players: players, teamCount: 3, rules: rules, rng: &rng)
        AuctionEngine.prepareLot(&state, teams: teams, rules: rules, players: byId, rng: &rng)
        let p = byId[state.currentPlayerId!]!
        XCTAssertTrue(AuctionEngine.placeBid(&state, teamId: 0, teams: teams, rules: rules, players: byId))
        XCTAssertEqual(state.currentBid, p.base)
        XCTAssertFalse(AuctionEngine.placeBid(&state, teamId: 0, teams: teams, rules: rules, players: byId), "can't outbid yourself")
        // Reserve: a team with 1 Cr and an empty squad can't bid more than 1 Cr - 10 * 30 L.
        teams[1].purse = 100
        XCTAssertEqual(AuctionEngine.maxAffordable(teams[1], rules: rules), -200)
        XCTAssertFalse(AuctionEngine.canBid(teams[1], on: p, amount: p.base, rules: rules, players: byId))
    }

    func testMatchCalibration() {
        let rules = Rules()
        let teams = runAuction(teams: 8, rules: rules, seed: 42)
        let sides = teams.map { t in
            MatchEngine.Side(teamId: t.id, xi: TeamSelector.autoXI(squad: t.squad.compactMap { byId[$0] }, rules: rules).compactMap { byId[$0] })
        }
        var engine = MatchEngine(rng: SeededRNG(seed: 7))
        var firstInn: [Int] = [], wkts: [Int] = [], sixes = 0, balls = 0, chaseWins = 0, ties = 0
        var wins = [Int: Int]()
        let n = 1000
        for i in 0..<n {
            let a = sides[i % 8], b = sides[(i / 8 + i + 1) % 8 == i % 8 ? (i + 1) % 8 : (i / 8 + i + 1) % 8]
            var log: [BallEvent] = []
            let r = engine.play(a, b, stage: .league, log: &log)
            firstInn.append(r.innings[0].runs)
            wkts.append(r.innings[0].wickets)
            sixes += r.innings.reduce(0) { $0 + $1.batters.reduce(0) { $0 + $1.sixes } }
            balls += r.innings.reduce(0) { $0 + $1.balls }
            if r.winnerId == r.innings[1].teamId { chaseWins += 1 }
            if r.superOver { ties += 1 }
            wins[r.winnerId, default: 0] += 1
            XCTAssertLessThanOrEqual(r.innings[0].balls, 120)
            XCTAssertLessThanOrEqual(r.innings[0].wickets, 10)
            XCTAssertTrue(r.innings.allSatisfy { inn in inn.bowlers.allSatisfy { $0.balls <= 24 } })
            XCTAssertEqual(r.innings[0].runs, r.innings[0].batters.reduce(0) { $0 + $1.runs } + r.innings[0].extras)
            XCTAssertFalse(log.isEmpty)
        }
        let avg = Double(firstInn.reduce(0, +)) / Double(n)
        let sorted = firstInn.sorted()
        let avgW = Double(wkts.reduce(0, +)) / Double(n)
        let ballsPerSix = Double(balls) / Double(max(sixes, 1))
        print(String(format: "calibration: 1st inns avg %.1f (p10 %d, p90 %d), wkts %.1f, balls/six %.1f, chase win %.0f%%, super overs %d",
                     avg, sorted[n / 10], sorted[n * 9 / 10], avgW, ballsPerSix, Double(chaseWins) * 100 / Double(n), ties))
        print("  wins by team:", wins.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" })
        XCTAssertTrue((150...195).contains(avg), "avg first innings \(avg)")
        XCTAssertTrue((4.5...8.5).contains(avgW), "avg wickets \(avgW)")
        XCTAssertTrue((10...22).contains(ballsPerSix), "balls per six \(ballsPerSix)")
    }

    func testSeasonAndPlayoffs() {
        let rules = Rules()
        for n in [3, 4, 8, 10] {
            var rng = SeededRNG(seed: UInt64(n))
            let teams = runAuction(teams: n, rules: rules, seed: UInt64(n))
            let sides = Dictionary(uniqueKeysWithValues: teams.map { t in
                (t.id, MatchEngine.Side(teamId: t.id, xi: TeamSelector.autoXI(squad: t.squad.compactMap { byId[$0] }, rules: rules).compactMap { byId[$0] }))
            })
            let fixtures = SeasonEngine.leagueFixtures(teamIds: teams.map(\.id), double: n == 3, rng: &rng)
            let expected = n * (n - 1) / 2 * (n == 3 ? 2 : 1)
            XCTAssertEqual(fixtures.count, expected)
            var pairs = Set<String>()
            for f in fixtures { pairs.insert("\(min(f.home, f.away))-\(max(f.home, f.away))-\(pairs.count >= n * (n - 1) / 2 ? 1 : 0)") }
            var engine = MatchEngine(rng: rng)
            var results: [MatchResult] = []
            for f in fixtures {
                var log: [BallEvent] = []
                results.append(engine.play(sides[f.home]!, sides[f.away]!, stage: .league, log: &log))
            }
            let table = SeasonEngine.table(teamIds: teams.map(\.id), results: results)
            XCTAssertEqual(table.reduce(0) { $0 + $1.played }, fixtures.count * 2)
            XCTAssertEqual(table.reduce(0) { $0 + $1.points }, fixtures.count * 2)
            XCTAssertEqual(table.reduce(0.0) { $0 + $1.nrr * 0 }, 0)

            var playoff: [MatchResult] = []
            var stages: [Stage] = []
            while let f = SeasonEngine.nextPlayoff(table: table, playoffResults: playoff, nextId: 100 + playoff.count) {
                var log: [BallEvent] = []
                playoff.append(engine.play(sides[f.home]!, sides[f.away]!, stage: f.stage, log: &log))
                stages.append(f.stage)
                XCTAssertLessThan(stages.count, 6)
            }
            XCTAssertEqual(stages, n < 4 ? [.final] : [.qualifier1, .eliminator, .qualifier2, .final])
            let stats = SeasonEngine.playerStats(results: results + playoff)
            let orange = stats.values.max { $0.runs < $1.runs }!
            let purple = stats.values.max { $0.wickets < $1.wickets }!
            print("season n=\(n): champion \(teams[playoff.last!.winnerId].short), orange \(byId[orange.id]!.name) \(orange.runs), purple \(byId[purple.id]!.name) \(purple.wickets)")
        }
    }

    func testCodableRoundTrip() throws {
        var state = AuctionState()
        state.queue = ["a", "b"]; state.cpuLimits = [1: 300]; state.leader = 1; state.currentBid = 250
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(AuctionState.self, from: data), state)
    }
}

final class GameFlowTests: XCTestCase {
    func testFullGameWithHumansAndCPUs() throws {
        let book = PlayerBook(EngineTests.players)
        for humans in [3, 5] {
            var g = GameState.newSetup(seed: UInt64(humans))
            for i in g.teams.indices { g.teams[i].isCPU = i >= humans }
            g.startAuction(book: book)
            XCTAssertEqual(g.phase, .auction)

            // Humans bid on the first few lots, then everyone else is simulated.
            for lot in 0..<6 {
                let human = lot % humans
                XCTAssertTrue(g.bid(teamId: human, book: book))
                while g.cpuBid(book: book) != nil {}
                let sale = g.hammer()
                XCTAssertNotNil(sale?.teamId)
                XCTAssertNil(g.hammer(), "a lot can only be hammered once")
                XCTAssertFalse(g.bid(teamId: human, book: book), "no bids after the hammer")
                g.nextLot(book: book)
            }
            g.simRestOfAuction(book: book)
            XCTAssertEqual(g.phase, .squads)
            for t in g.teams {
                XCTAssertGreaterThanOrEqual(t.squad.count, g.rules.minSquad)
                XCTAssertEqual(t.xi.count, 11)
                XCTAssertGreaterThanOrEqual(t.purse, 0)
            }

            // Round-trip the save file mid-game.
            g = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(g))

            g.startSeason()
            var safety = 0
            while let f = g.nextFixture, safety < 200 {
                XCTAssertNotNil(g.play(fixtureId: f.id, book: book))
                safety += 1
            }
            XCTAssertEqual(g.phase, .season)
            XCTAssertNotNil(g.championId)
            g.finishSeason()
            XCTAssertEqual(g.phase, .champion)
            XCTAssertEqual(g.results.last?.stage, .final)
            let a = g.awards()
            XCTAssertNotNil(a.orangeCap); XCTAssertNotNil(a.purpleCap); XCTAssertNotNil(a.mvp)
            let size = try JSONEncoder().encode(g).count
            print("game humans=\(humans): \(g.results.count) matches, champion \(g.team(g.championId!)!.short), save \(size / 1024) KB")
        }
    }
}
