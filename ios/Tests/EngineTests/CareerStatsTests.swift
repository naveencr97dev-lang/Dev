import XCTest
@testable import AuctionEngine

/// Season and all-time stats, and the market sorted by them.
extension CareerTests {
    func testSeasonAndAllTimeStats() {
        var c = newCareer(seed: 71)
        for _ in 0..<40 { if let f = c.nextFixture, c.pendingWindow == nil { c.play(fixtureId: f.id) } }
        let season = c.seasonStatLines
        XCTAssertFalse(season.isEmpty)
        // Mid-season: season and all-time agree (first season).
        let (id, line) = season.max { $0.value.runs < $1.value.runs }!
        XCTAssertEqual(c.statLine(id, scope: .allTime).runs, line.runs)
        // Market sorted by runs, best first.
        let byRuns = c.marketPlayers(sort: .runs, scope: .season, limit: 20)
        let runs = byRuns.map { c.statLine($0.id, scope: .season, season: season).runs }
        XCTAssertEqual(runs, runs.sorted(by: >))
        let byEcon = c.leaders(.economy, scope: .season)
        let econ = byEcon.map { c.statLine($0.id, scope: .season, season: season) }.filter { $0.ballsBowled >= c.minBalls(.season) }.map(\.economy)
        XCTAssertEqual(econ, econ.sorted())
        // Season end archives a line per player; next season starts fresh but all-time keeps counting.
        c.simToSeasonEnd()
        let p = c.players[id]!
        XCTAssertEqual(p.seasonLog?.last?.year, 2027)
        XCTAssertEqual(p.seasonLog?.last?.runs, c.seasonStatLines[id]?.runs)
        c.startNextSeason()
        XCTAssertTrue(c.seasonStatLines.isEmpty)
        XCTAssertEqual(c.statLine(id, scope: .allTime).runs, c.players[id]!.stats.runs)
        XCTAssertGreaterThan(c.statLine(id, scope: .allTime).runs, 0)
    }

    func testMigrationFromSchema6() throws {
        let c = newCareer(seed: 72)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 6
        var players = json["players"] as! [String: Any]
        for (k, v) in players { var p = v as! [String: Any]; p["seasonLog"] = nil; players[k] = p }
        json["players"] = players
        let back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(back.players.values.allSatisfy { $0.seasonLog == nil })
    }
}
