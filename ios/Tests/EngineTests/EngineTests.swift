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
        XCTAssertEqual(players.count, 172)
        XCTAssertGreaterThan(players.filter(\.legend).count, 40)
        XCTAssertTrue(players.allSatisfy { $0.rating >= 70 }, "no weak players")
        XCTAssertEqual(Set(players.map(\.id)).count, players.count)
    }

    func testIncrementsAndMoney() {
        XCTAssertEqual(AuctionEngine.increment(after: 30), 5)
        XCTAssertEqual(AuctionEngine.increment(after: 150), 10)
        XCTAssertEqual(AuctionEngine.increment(after: 300), 20)
        XCTAssertEqual(AuctionEngine.increment(after: 1200), 25)
        XCTAssertEqual(AuctionEngine.increment(after: 30, step: 100), 100, "fixed ₹1 Cr raise")
        XCTAssertEqual(AuctionEngine.increment(after: 1200, step: 100), 100)
        // Older saves without bidStep still decode.
        let old = #"{"purse":10000,"minSquad":11,"maxSquad":11,"maxOverseasSquad":4,"maxOverseasXI":4,"bidSeconds":8,"doubleRoundRobin":false,"pitchMode":{"mixed":{}},"minBase":30}"#
        XCTAssertEqual(try JSONDecoder().decode(Rules.self, from: Data(old.utf8)).bidStep, 0)
        XCTAssertEqual(Money.format(75), "₹75 L")
        XCTAssertEqual(Money.format(200), "₹2 Cr")
        XCTAssertEqual(Money.format(1225), "₹12.25 Cr")
    }

    func testAuctionProducesValidSquads() {
        for (n, seed) in [(3, 1), (4, 5), (8, 2), (10, 3)] as [(Int, UInt64)] {
            let rules = Rules()
            var rng = SeededRNG(seed: seed)
            let queue = AuctionEngine.buildQueue(players: players, teamCount: n, rules: rules, rng: &rng)
            XCTAssertEqual(queue.count, 11 * n + 12, "pool = one XI per team + 12 extras")
            XCTAssertEqual(Set(queue).count, queue.count)
            do {
                let teams = runAuction(teams: n, rules: rules, seed: seed)
                for t in teams {
                    XCTAssertEqual(t.squad.count, 11, "\(t.name) n=\(n)")
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
            let needs = teams.map { AuctionEngine.needs($0, players: byId).summary }
            print("auction n=\(n): spent \(spent.map(Money.format)) needs \(needs)")
            if n == 4 {
                let top = teams.flatMap { t in t.paid.map { ($0.key, $0.value) } }.sorted { $0.1 > $1.1 }.prefix(5)
                print("  top buys:", top.map { "\(byId[$0.0]!.name) \(Money.format($0.1))" })
            }
        }
    }

    func testHumanBidRules() {
        let rules = Rules()
        var teams = makeTeams(3, rules: rules)
        teams[0].isCPU = false
        XCTAssertEqual(Pitch.allCases.count, 5)
        var rng = SeededRNG(seed: 9)
        var state = AuctionState()
        state.queue = AuctionEngine.buildQueue(players: players, teamCount: 3, rules: rules, rng: &rng)
        AuctionEngine.prepareLot(&state, teams: teams, rules: rules, players: byId, rng: &rng)
        let p = byId[state.currentPlayerId!]!
        XCTAssertTrue(AuctionEngine.placeBid(&state, teamId: 0, teams: teams, rules: rules, players: byId))
        XCTAssertEqual(state.currentBid, p.base)
        var crore = rules
        crore.bidStep = 100
        XCTAssertTrue(AuctionEngine.placeBid(&state, teamId: 1, teams: teams, rules: crore, players: byId))
        XCTAssertEqual(state.currentBid, p.base + 100, "next bid jumps by ₹1 Cr")
        XCTAssertFalse(AuctionEngine.placeBid(&state, teamId: 1, teams: teams, rules: rules, players: byId), "can't outbid yourself")
        // Reserve: a team with 1 Cr and an empty squad can't bid more than 1 Cr - 10 * 50 L.
        teams[1].purse = 100
        XCTAssertEqual(AuctionEngine.maxAffordable(teams[1], rules: rules), -400)
        XCTAssertFalse(AuctionEngine.canBid(teams[1], on: p, amount: p.base, rules: rules, players: byId))
        // Overseas: max 4 in an 11-man squad.
        var t = teams[2]
        t.squad = players.filter(\.overseas).prefix(4).map(\.id)
        let os = players.first { $0.overseas && !t.squad.contains($0.id) }!
        XCTAssertEqual(AuctionEngine.blockReason(t, on: os, amount: os.base, rules: rules, players: byId), "Overseas full")
    }

    func sides(_ teams: [Franchise]) -> [MatchEngine.Side] {
        teams.map { t in
            MatchEngine.Side(teamId: t.id, xi: TeamSelector.autoXI(squad: t.squad.compactMap { byId[$0] }, rules: Rules()).compactMap { byId[$0] })
        }
    }

    func testMatchCalibration() {
        let teams = runAuction(teams: 8, rules: Rules(), seed: 42)
        let sides = sides(teams)
        var averages: [Pitch: Double] = [:]
        for pitch in Pitch.allCases {
            var engine = MatchEngine(rng: SeededRNG(seed: 7))
            var firstInn: [Int] = [], wkts: [Int] = [], sixes = 0, balls = 0, chaseWins = 0, ties = 0
            var spinWkts = 0, paceWkts = 0
            let n = 600
            for i in 0..<n {
                let a = sides[i % 8], b = sides[(i + 1 + i / 8) % 8 == i % 8 ? (i + 1) % 8 : (i + 1 + i / 8) % 8]
                var log: [BallEvent] = []
                let r = engine.play(a, b, stage: .league, pitch: pitch, log: &log)
                firstInn.append(r.innings[0].runs)
                wkts.append(r.innings[0].wickets)
                sixes += r.innings.reduce(0) { $0 + $1.batters.reduce(0) { $0 + $1.sixes } }
                balls += r.innings.reduce(0) { $0 + $1.balls }
                if r.winnerId == r.innings[1].teamId { chaseWins += 1 }
                if r.superOver { ties += 1 }
                for inn in r.innings { for bw in inn.bowlers {
                    if byId[bw.id]?.bowlType == .spin { spinWkts += bw.wickets } else { paceWkts += bw.wickets }
                } }
                XCTAssertLessThanOrEqual(r.innings[0].balls, 120)
                XCTAssertLessThanOrEqual(r.innings[0].wickets, 10)
                XCTAssertTrue(r.innings.allSatisfy { inn in inn.bowlers.allSatisfy { $0.balls <= 24 } })
                XCTAssertEqual(r.innings[0].runs, r.innings[0].batters.reduce(0) { $0 + $1.runs } + r.innings[0].extras)
                XCTAssertEqual(r.pitch, pitch)
                // Highlights: some, capped, in match order, ending with how it was won.
                let h = r.highlights ?? []
                XCTAssertFalse(h.isEmpty)
                XCTAssertLessThanOrEqual(h.count, MatchEngine.maxHighlights)
                XCTAssertEqual(h.map(\.seq), h.map(\.seq).sorted())
                XCTAssertTrue([.winningRuns, .defended, .superOver].contains(h.last!.kind), "\(h.last!.kind)")
                // Live snapshots: two batters (one on strike) until all out, bowler figures add up.
                for e in log where e.label != "W" {
                    XCTAssertEqual(e.batters.count, 2)
                    XCTAssertEqual(e.batters.filter(\.onStrike).count, 1)
                }
                if let last = log.last(where: { $0.innings == 0 }) {
                    XCTAssertEqual(last.score, r.innings[0].runs)
                }
            }
            let avg = Double(firstInn.reduce(0, +)) / Double(n)
            averages[pitch] = avg
            let sorted = firstInn.sorted()
            let avgW = Double(wkts.reduce(0, +)) / Double(n)
            let ballsPerSix = Double(balls) / Double(max(sixes, 1))
            print(String(format: "%@: 1st inns avg %.1f (p10 %d, p90 %d), wkts %.1f, balls/six %.1f, chase win %.0f%%, ties %d, spin share of wkts %.0f%%",
                         pitch.label, avg, sorted[n / 10], sorted[n * 9 / 10], avgW, ballsPerSix,
                         Double(chaseWins) * 100 / Double(n), ties, Double(spinWkts) * 100 / Double(max(1, spinWkts + paceWkts))))
            XCTAssertTrue((130...215).contains(avg), "\(pitch) avg \(avg)")
            XCTAssertTrue((4...9).contains(avgW), "\(pitch) wickets \(avgW)")
        }
        XCTAssertGreaterThan(averages[.indianFlat]!, averages[.englishSeam]! + 15, "India should score well above England")
        XCTAssertGreaterThan(averages[.indianFlat]!, averages[.dustyTurner]! + 15)
    }

    /// Traits must actually change outcomes in their match-ups.
    func testTraitsMatter() {
        func make(_ name: String, bat: Int, bowl: Int, type: BowlType = .pace, traits: [Trait] = []) -> Player {
            Player(id: name, name: name, role: .BAT, overseas: false, country: "", base: 30, pool: "", rating: 70,
                   bat: bat, bowl: bowl, line: "", bowlType: type, traits: traits, slot: .middle, legend: false)
        }
        func sixRate(_ batter: Player, _ bowler: Player, over: Int, pitch: Pitch = .indianFlat) -> (Double, Double) {
            var engine = MatchEngine(rng: SeededRNG(seed: 3))
            var sixes = 0, wkts = 0
            let card = InningsCard(teamId: 0)
            for _ in 0..<40_000 {
                let (o, _, _) = engine.ball(batter: batter, bowler: bowler, over: over, maxOvers: 20, card: card,
                                            target: nil, maxWickets: 10, pitch: pitch)
                if o == 6 { sixes += 1 }
                if o == -1 { wkts += 1 }
            }
            return (Double(sixes) / 400, Double(wkts) / 400)   // per 100 balls
        }
        let plain = make("plain", bat: 70, bowl: 10)
        let spinner = make("spinner", bat: 10, bowl: 70, type: .spin)
        let pacer = make("pacer", bat: 10, bowl: 70)
        let basher = make("basher", bat: 70, bowl: 10, traits: [.spinBasher])
        XCTAssertGreaterThan(sixRate(basher, spinner, over: 10).0, sixRate(plain, spinner, over: 10).0 * 1.2)
        XCTAssertEqual(sixRate(basher, pacer, over: 10).0, sixRate(plain, pacer, over: 10).0, accuracy: 0.01)

        let finisher = make("fin", bat: 70, bowl: 10, traits: [.finisher])
        XCTAssertGreaterThan(sixRate(finisher, pacer, over: 18).0, sixRate(plain, pacer, over: 18).0 * 1.2)

        let swing = make("swing", bat: 10, bowl: 70, traits: [.newBallSwing])
        let ppEng = sixRate(plain, swing, over: 1, pitch: .englishSeam).1
        let ppInd = sixRate(plain, swing, over: 1, pitch: .indianFlat).1
        XCTAssertGreaterThan(ppEng, ppInd * 1.3, "swing is deadlier in England")
        XCTAssertGreaterThan(sixRate(plain, swing, over: 1).1, sixRate(plain, pacer, over: 1).1 * 1.2)

        let mystery = make("mystery", bat: 10, bowl: 70, type: .spin, traits: [.mysterySpin])
        XCTAssertGreaterThan(sixRate(plain, mystery, over: 10).1, sixRate(plain, spinner, over: 10).1 * 1.15)
        XCTAssertLessThan(sixRate(basher, mystery, over: 10).1, sixRate(plain, mystery, over: 10).1, "spin bashers read mystery spin")
        // Condition traits.
        let bully = make("bully", bat: 70, bowl: 10, traits: [.flatTrackBully])
        XCTAssertGreaterThan(sixRate(bully, pacer, over: 10, pitch: .indianFlat).0, sixRate(plain, pacer, over: 10, pitch: .indianFlat).0 * 1.1)
        XCTAssertGreaterThan(sixRate(bully, pacer, over: 10, pitch: .englishSeam).1, sixRate(plain, pacer, over: 10, pitch: .englishSeam).1)
        let terror = make("terror", bat: 10, bowl: 70, type: .spin, traits: [.turnerTerror])
        XCTAssertGreaterThan(sixRate(plain, terror, over: 10, pitch: .dustyTurner).1, sixRate(plain, spinner, over: 10, pitch: .dustyTurner).1 * 1.2)
        let tech = make("tech", bat: 70, bowl: 10, traits: [.technician])
        XCTAssertLessThan(sixRate(tech, swing, over: 1, pitch: .englishSeam).1, sixRate(plain, swing, over: 1, pitch: .englishSeam).1 * 0.85)
    }

    func testBattingOrderAndBowlingPlanMatter() {
        let teams = runAuction(teams: 4, rules: Rules(), seed: 11)
        let squad = teams[0].squad.compactMap { byId[$0] }
        let best = TeamSelector.battingOrder(squad)
        XCTAssertGreaterThan(TeamSelector.orderScore(best), TeamSelector.orderScore(Array(best.reversed())))
        XCTAssertNotEqual(best.first?.slot, .lower, "a tail-ender shouldn't open")

        // Same XI, best order vs reversed order, many games against the same opponent.
        let opp = MatchEngine.Side(teamId: 1, xi: TeamSelector.battingOrder(teams[1].squad.compactMap { byId[$0] }))
        func runs(_ order: [Player]) -> Double {
            var engine = MatchEngine(rng: SeededRNG(seed: 99))
            var total = 0
            for _ in 0..<400 {
                var log: [BallEvent] = []
                let r = engine.play(MatchEngine.Side(teamId: 0, xi: order), opp, stage: .league, pitch: .indianFlat, log: &log)
                total += r.innings.first { $0.teamId == 0 }!.runs
            }
            return Double(total) / 400
        }
        let good = runs(best), bad = runs(Array(best.reversed()))
        print(String(format: "batting order: best %.1f vs reversed %.1f", good, bad))
        XCTAssertGreaterThan(good, bad + 5)

        // Phase fit: a death specialist gains at the death, a spinner loses there.
        let bumrah = byId["jasprit-bumrah"]!, chahal = byId["yuzvendra-chahal"]!
        XCTAssertGreaterThan(MatchEngine.phaseFit(bumrah, .death, pitch: .indianFlat), MatchEngine.phaseFit(chahal, .death, pitch: .indianFlat))
        // Auto plan gives the new-ball/death slots to pace or swing, not the best middle-overs spinner.
        let plan = MatchEngine.autoAttack(squad, pitch: .englishSeam)
        XCTAssertEqual(plan.count, 5)
        XCTAssertEqual(MatchEngine.overs(forSlot: 0), [1, 3, 17, 19])
        // Home conditions.
        XCTAssertEqual(Pitch.englishSeam.homeBonus(byId["jos-buttler"]!), 5)
        XCTAssertEqual(Pitch.englishSeam.homeBonus(byId["virat-kohli"]!), 0)
        print("legends in data:", players.filter(\.legend).count)
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
                results.append(engine.play(sides[f.home]!, sides[f.away]!, stage: .league, pitch: .indianFlat, log: &log))
            }
            let table = SeasonEngine.table(teamIds: teams.map(\.id), results: results)
            XCTAssertEqual(table.reduce(0) { $0 + $1.played }, fixtures.count * 2)
            XCTAssertEqual(table.reduce(0) { $0 + $1.points }, fixtures.count * 2)
            XCTAssertEqual(table.reduce(0.0) { $0 + $1.nrr * 0 }, 0)

            var playoff: [MatchResult] = []
            var stages: [Stage] = []
            while let f = SeasonEngine.nextPlayoff(table: table, playoffResults: playoff, nextId: 100 + playoff.count) {
                var log: [BallEvent] = []
                playoff.append(engine.play(sides[f.home]!, sides[f.away]!, stage: f.stage, pitch: .aussieBounce, log: &log))
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
        // Results saved before highlights existed still decode.
        var engine = MatchEngine(rng: SeededRNG(seed: 1))
        let teams = runAuction(teams: 3, rules: Rules(), seed: 1)
        let sd = sides(teams)
        var log: [BallEvent] = []
        let r = engine.play(sd[0], sd[1], stage: .league, pitch: .indianFlat, log: &log)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(r)) as! [String: Any]
        json.removeValue(forKey: "highlights")
        let old = try JSONDecoder().decode(MatchResult.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.highlights)
        print("sample highlights:", (r.highlights ?? []).map { "\($0.over) \($0.kind.rawValue): \($0.text)" })

        var state = AuctionState()
        state.queue = ["a", "b"]; state.cpuLimits = [1: 300]; state.leader = 1; state.currentBid = 250
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(AuctionState.self, from: data), state)
    }
}

final class GameFlowTests: XCTestCase {
    func testFullGameWithHumansAndCPUs() throws {
        let book = PlayerBook(EngineTests.players)
        for humans in [3, 4] {
            var g = GameState.newSetup(seed: UInt64(humans))
            if humans == 4 { g.teams = Array(g.teams.prefix(4)) }   // 4 humans, no CPU
            for i in g.teams.indices { g.teams[i].isCPU = i >= humans }
            g.startAuction(book: book)
            XCTAssertEqual(g.phase, .auction)

            XCTAssertEqual(g.auction.queue.count, 11 * g.teams.count + 12)
            // Skip one lot: CPUs settle it instantly.
            let skipped = g.skipLot(book: book)
            XCTAssertNotNil(skipped)
            XCTAssertNil(g.hammer())
            g.nextLot(book: book)
            // Humans bid on the next few lots, then everyone else is simulated.
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
                XCTAssertEqual(t.squad.count, 11)
                XCTAssertEqual(Set(t.xi), Set(t.squad))
                XCTAssertGreaterThanOrEqual(t.purse, 0)
            }

            // A custom bowling plan is used when valid.
            let t0 = g.teams[0]
            let planIds = Array(MatchEngine.autoAttack(t0.squad.compactMap { book[$0] }, pitch: nil).map(\.id).reversed())
            g.setBowlingOrder(teamId: t0.id, ids: planIds)
            XCTAssertEqual(g.side(t0.id, book: book).attack?.map(\.id), planIds)
            g.setBowlingOrder(teamId: t0.id, ids: [])
            XCTAssertNil(g.side(t0.id, book: book).attack)
            g.setBowlingOrder(teamId: t0.id, ids: planIds)
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
            g.reopenSeason()
            XCTAssertEqual(g.phase, .season)
            XCTAssertNil(g.nextFixture)
            g.finishSeason()
            XCTAssertTrue(Set(g.fixtures.map(\.pitch)).count > 1, "mixed venues")
            XCTAssertEqual(g.results.last?.stage, .final)
            let a = g.awards()
            XCTAssertNotNil(a.orangeCap); XCTAssertNotNil(a.purpleCap); XCTAssertNotNil(a.mvp)
            let size = try JSONEncoder().encode(g).count
            print("game humans=\(humans): \(g.results.count) matches, champion \(g.team(g.championId!)!.short), save \(size / 1024) KB")
        }
    }
}
