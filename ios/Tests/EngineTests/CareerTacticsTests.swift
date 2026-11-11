import XCTest
@testable import AuctionEngine

/// M6: match-day tactics.
extension CareerTests {
    func testTacticsChangeOutcomes() {
        let c = newCareer(seed: 61)
        let a = c.side(c.clubs[1].id), b = c.side(c.clubs[2].id)
        func runs(bat: Tactics?, bowl: Tactics?) -> (runs: Double, wkts: Double, boundaries: Double) {
            var engine = MatchEngine(rng: SeededRNG(seed: 9))
            var total = 0, wk = 0, bnd = 0
            for _ in 0..<300 {
                var log: [BallEvent] = []
                var batting = a; batting.tactics = bat
                var bowling = b; bowling.tactics = bowl
                let inn = engine.innings(batting: batting, bowling: bowling, target: nil, maxOvers: 20, index: 0, pitch: .indianFlat, log: &log)
                total += inn.runs; wk += inn.wickets
                bnd += inn.batters.reduce(0) { $0 + $1.fours + $1.sixes }
            }
            return (Double(total) / 300, Double(wk) / 300, Double(bnd) / 300)
        }
        let neutral = runs(bat: nil, bowl: nil)
        let attack = runs(bat: Tactics(intent: [.attack, .attack, .attack]), bowl: nil)
        let block = runs(bat: Tactics(intent: [.block, .block, .block]), bowl: nil)
        XCTAssertGreaterThan(attack.runs, neutral.runs + 5)
        XCTAssertGreaterThan(attack.wkts, neutral.wkts)
        XCTAssertLessThan(block.runs, neutral.runs - 5)
        XCTAssertLessThan(block.wkts, neutral.wkts * 0.6, "Block has to be felt: about half the wickets")
        let defend = runs(bat: nil, bowl: Tactics(field: [.defend, .defend, .defend]))
        XCTAssertLessThan(defend.boundaries, neutral.boundaries)
        // Neutral tactics are exactly the old engine (quick game unchanged).
        let explicitNeutral = runs(bat: Tactics(), bowl: Tactics())
        XCTAssertEqual(explicitNeutral.runs, neutral.runs, accuracy: 0.001)
    }

    /// Owner's device test: chasing 227 and set to Block, batters still swung and got out. Told
    /// to block, they block: the chase pressure doesn't override it.
    func testBlockHoldsInABigChase() {
        let c = newCareer(seed: 63)
        let a = c.side(c.clubs[1].id), b = c.side(c.clubs[2].id)
        func chase(_ intent: BatIntent) -> (wkts: Double, sixes: Double) {
            var engine = MatchEngine(rng: SeededRNG(seed: 11))
            engine.realisticChase = true
            var wk = 0, six = 0
            for _ in 0..<300 {
                var log: [BallEvent] = []
                var batting = a; batting.tactics = Tactics(intent: [intent, intent, intent])
                let inn = engine.innings(batting: batting, bowling: b, target: 227, maxOvers: 20, index: 1, pitch: .aussieBounce, log: &log)
                wk += inn.wickets; six += inn.batters.reduce(0) { $0 + $1.sixes }
            }
            return (Double(wk) / 300, Double(six) / 300)
        }
        let rotate = chase(.rotate), block = chase(.block)
        XCTAssertLessThan(block.wkts, rotate.wkts * 0.6, "block \(block.wkts) v rotate \(rotate.wkts)")
        XCTAssertLessThan(block.sixes, rotate.sixes * 0.6)
    }

    func testMigrationFromSchema5() throws {
        let c = newCareer(seed: 62)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 5
        json["tactics"] = nil
        let back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.tactics, Tactics())
    }
}

/// Game plans, toss call, captain and batting roles (SM26 tactics recon, cricket version).
extension CareerTests {
    func testGamePlansSetAllSixAndKeepTheRest() {
        var t = Tactics()
        t.captain = "x"; t.toss = .bowlFirst; t.roles = ["x": .anchor]
        let applied = GamePlan.seeItOff.apply(to: t)
        XCTAssertEqual(applied.intent, GamePlan.seeItOff.tactics.intent)
        XCTAssertEqual(applied.field, GamePlan.seeItOff.tactics.field)
        XCTAssertEqual(applied.captain, "x"); XCTAssertEqual(applied.toss, .bowlFirst); XCTAssertEqual(applied.roles?["x"], .anchor)
        XCTAssertEqual(applied.matchingPlan, .seeItOff)
        XCTAssertEqual(GamePlan.balanced.aggression, 50)
        XCTAssertEqual(GamePlan.allOut.aggression, 100)
        XCTAssertTrue(Pitch.allCases.allSatisfy { GamePlan.suggestions[$0] != nil })
    }

    func testTossCallIsObeyed() {
        var c = newCareer(seed: 901)
        for call in TossCall.allCases {
            c.tactics.toss = call
            var obeyed = 0, won = 0
            for f in c.leagueFixtures.filter({ c.isUserFixture($0) }).prefix(30) {
                let (r, _, _) = c.simulate(f, changes: [])
                guard r.tossWinner == c.userClubId else { continue }
                won += 1
                let battedFirst = r.innings[0].teamId == c.userClubId
                if battedFirst == (call == .batFirst) { obeyed += 1 }
            }
            XCTAssertGreaterThan(won, 0)
            XCTAssertEqual(obeyed, won, "\(call)")
        }
    }

    func testHittersHitMoreSixesThanAnchors() {
        var c = newCareer(seed: 902)
        func sixes(_ role: BatRole) -> Int {
            var cc = c
            cc.tactics.roles = Dictionary(uniqueKeysWithValues: cc.userClub.xi.map { ($0, role) })
            var n = 0
            for (k, f) in cc.leagueFixtures.filter({ cc.isUserFixture($0) }).prefix(36).enumerated() {
                cc.rng = SeededRNG(seed: UInt64(77 + k))
                let (r, _, _) = cc.simulate(f, changes: [])
                n += r.innings.prefix(2).filter { $0.teamId == cc.userClubId }.flatMap(\.batters).map(\.sixes).reduce(0, +)
            }
            return n
        }
        XCTAssertGreaterThan(sixes(.hitter), sixes(.anchor))
        c.tactics.captain = c.userClub.xi[0]
        let p = c.player(c.userClub.xi[0])!
        XCTAssertEqual(c.userBoost(for: p, position: 0, attackSlot: nil, fixture: nil).bat,
                       newCareer(seed: 902).userBoost(for: p, position: 0, attackSlot: nil, fixture: nil).bat + 1, "captain +1")
    }
}
