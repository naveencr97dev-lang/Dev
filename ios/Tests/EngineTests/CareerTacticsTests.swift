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
        XCTAssertLessThan(block.wkts, neutral.wkts)
        let defend = runs(bat: nil, bowl: Tactics(field: [.defend, .defend, .defend]))
        XCTAssertLessThan(defend.boundaries, neutral.boundaries)
        // Neutral tactics are exactly the old engine (quick game unchanged).
        let explicitNeutral = runs(bat: Tactics(), bowl: Tactics())
        XCTAssertEqual(explicitNeutral.runs, neutral.runs, accuracy: 0.001)
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
