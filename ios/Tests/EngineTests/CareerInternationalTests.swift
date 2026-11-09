import XCTest
@testable import AuctionEngine

/// M5: international cricket.
extension CareerTests {
    func testNationsAndRankings() {
        let c = newCareer(seed: 51)
        XCTAssertEqual(c.intl.nations.count, 20)
        for n in c.intl.nations { XCTAssertGreaterThanOrEqual(c.nationPlayers(n.code).count, 16, n.code) }
        let top5 = c.rankings.prefix(5).map(\.code)
        XCTAssertTrue(top5.contains("IND"), "India is a top side: \(top5)")
        XCTAssertTrue(c.intl.nations.filter { !$0.fullMember }.allSatisfy { c.rank(of: $0.code) > 8 }, "associates rank low")
        let team = c.team(c.nationTeamId("AUS"))!
        XCTAssertEqual(team.short, "AUS")
        XCTAssertEqual(team.squad.count, 15)
        XCTAssertEqual(team.xi.count, 11)
        XCTAssertFalse(c.intl.offers.isEmpty, "a newcomer gets an offer from a smaller nation")
    }

    func testSeriesWindowsDuringSeason() {
        var c = newCareer(seed: 52)
        c.simToSeasonEnd()
        XCTAssertEqual(c.phase, .seasonEnd)
        XCTAssertTrue(c.intl.done.contains("2027-A"))
        XCTAssertTrue(c.intl.done.contains("2027-B"))
        XCTAssertEqual(c.intl.history.count, 2)
        XCTAssertEqual(c.results.count, 184, "club season unaffected")
        XCTAssertEqual(c.intl.results.filter { $0.stage == .series }.count, 30, "10 series of 3")
    }

    func testWorldCup() {
        var c = newCareer(seed: 53)
        c.simToSeasonEnd()
        c.startNextSeason()   // 2028: World Cup in April
        while c.pendingWindow == nil, let f = c.nextFixture { c.play(fixtureId: f.id) }
        XCTAssertEqual(c.pendingWindow, "2028-A")
        c.simWindow(stopAtUser: false)
        let e = c.intl.event!
        XCTAssertEqual(e.kind, .worldCup)
        XCTAssertTrue(e.finished)
        XCTAssertNotNil(e.winner)
        XCTAssertEqual(e.groups.map(\.count), [5, 5, 5, 5])
        XCTAssertEqual(e.superEight.map(\.count), [4, 4])
        let stages = c.intl.results.map(\.stage)
        XCTAssertEqual(stages.filter { $0 == .group }.count, 40)
        XCTAssertEqual(stages.filter { $0 == .superEight }.count, 12)
        XCTAssertEqual(stages.filter { $0 == .semiFinal }.count, 2)
        XCTAssertEqual(stages.filter { $0 == .final }.count, 1)
        XCTAssertNil(c.pendingWindow, "league resumes")
        XCTAssertTrue(c.intl.history[0].title.contains("World Cup"))
    }

    func testNationalJob() {
        var c = newCareer(seed: 54)
        let code = c.intl.offers[0]
        XCTAssertTrue(c.acceptJob(code))
        XCTAssertEqual(c.intl.job, code)
        XCTAssertEqual(c.intl.squad.count, 15)
        // Pick a custom squad of the 15 youngest.
        let youngest = c.nationPlayers(code).sorted { $0.born > $1.born }.prefix(15).map(\.id)
        c.setNationalSquad(Array(youngest))
        XCTAssertEqual(Set(c.nationSquad(code)), Set(youngest))
        // Reach the April window: sims stop before your nation plays.
        while c.pendingWindow == nil { c.simUntilUserMatch(); if let f = c.nextFixture, c.pendingWindow == nil { c.play(fixtureId: f.id) } }
        c.simUntilUserMatch()
        let f = c.nextIntlFixture!
        XCTAssertTrue(c.isUserNationFixture(f))
        XCTAssertFalse(c.intl.target.isEmpty)
        XCTAssertNotNil(c.play(fixtureId: f.id), "internationals play through the same entry point")
        XCTAssertNotNil(c.playedResult(fixtureId: f.id))
        c.simWindow(stopAtUser: false)
        XCTAssertTrue(c.intl.history[0].userResult != nil)
        XCTAssertTrue(c.news.contains { $0.text.contains("Board verdict") })
    }

    func testMigrationFromSchema4() throws {
        let c = newCareer(seed: 55)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 4
        json["intl"] = nil
        var back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(back.intl.nations.isEmpty)
        back.simToSeasonEnd()
        XCTAssertEqual(back.intl.nations.count, 20, "set up on first use")
        XCTAssertEqual(back.intl.history.count, 2)
    }
}
