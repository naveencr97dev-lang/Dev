import XCTest
@testable import AuctionEngine

extension EngineTests {
    /// Tied matches keep their super overs: cards, ball log (innings 2+), margin and the
    /// helpers the live view uses.
    func testSuperOverIsRecordedAndReplayable() {
        let teams = runAuction(teams: 4, rules: Rules(), seed: 11)
        let sides = teams.map { t in MatchEngine.Side(teamId: t.id, xi: t.xi.isEmpty ? TeamSelector.autoXI(squad: t.squad.compactMap { byId[$0] }, rules: Rules()).compactMap { byId[$0] } : t.xi.compactMap { byId[$0] }) }
        var engine = MatchEngine(rng: SeededRNG(seed: 5))
        var found = 0
        for i in 0..<3000 where found < 3 {
            var log: [BallEvent] = []
            let r = engine.play(sides[i % 4], sides[(i + 1) % 4], stage: .league, pitch: .englishSeam, log: &log)
            guard r.superOver else { continue }
            found += 1
            XCTAssertEqual(r.innings[0].runs, r.innings[1].runs, "a super over needs a tie")
            let so = r.superOvers ?? []
            XCTAssertGreaterThanOrEqual(so.count, 2)
            XCTAssertEqual(so.count % 2, 0)
            XCTAssertTrue(so.allSatisfy { $0.balls <= 6 && $0.maxBalls == 6 })
            // The side that batted second bats first in the super over.
            XCTAssertEqual(so[0].teamId, r.innings[1].teamId)
            let last = so.count - 2
            if so[last].runs != so[last + 1].runs {
                let winner = so[last].runs > so[last + 1].runs ? so[last].teamId : so[last + 1].teamId
                XCTAssertEqual(r.winnerId, winner)
            }
            XCTAssertTrue(r.margin.contains("Super Over"))
            // The live log includes the super-over balls, scores matching the cards.
            for (k, card) in so.enumerated() {
                let balls = log.filter { $0.innings == 2 + k }
                XCTAssertFalse(balls.isEmpty || card.runs < 0)
                XCTAssertEqual(balls.last?.score, card.runs)
                XCTAssertEqual(r.card(2 + k).teamId, card.teamId)
                XCTAssertNotEqual(r.fieldingTeam(2 + k), card.teamId)
            }
            XCTAssertEqual(r.target(forInnings: 3), so[0].runs + 1)
            XCTAssertNil(r.target(forInnings: 2))
            XCTAssertEqual(r.maxBalls(3), 6)
            // Old saves (no superOvers key) still decode.
            var json = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(r)) as! [String: Any]
            json["superOvers"] = nil
            XCTAssertNoThrow(try JSONDecoder().decode(MatchResult.self, from: JSONSerialization.data(withJSONObject: json)))
        }
        XCTAssertGreaterThan(found, 0, "no tie in 3000 matches")
    }
}
