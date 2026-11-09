import XCTest
@testable import AuctionEngine

/// Settings, weekly income, scouting cadence, open market, filters.
extension CareerTests {
    func testWeeklyIncomeAndScoutCadence() {
        var c = newCareer(seed: 81)
        c.simUntilUserMatch()
        let bank = c.bank(c.userClubId)
        var userMatches = 0, homeMatches = 0
        while userMatches < 4, let f = c.nextUserFixture {
            c.simUntilUserMatch()
            if f.home == c.userClubId { homeMatches += 1 }
            c.play(fixtureId: f.id)
            userMatches += 1
        }
        let ledger = c.finance[c.userClubId].ledger
        XCTAssertEqual(ledger.filter { $0.text == "Merchandise sales" }.count, 4, "merchandise every week")
        XCTAssertEqual(ledger.filter { $0.text.hasPrefix("Tickets:") }.count, homeMatches, "tickets at home")
        XCTAssertGreaterThan(c.bank(c.userClubId), bank)
        // A report from each scout every 2 weeks.
        XCTAssertEqual(c.scouting.reports.count, 2 * c.scouting.scouts.count)
        XCTAssertTrue(c.news.contains { $0.text.hasPrefix("📋") })
    }

    func testOpenMarketDifficultyAndFilters() {
        var c = newCareer(seed: 82)
        // Always open by default, even mid-season.
        for _ in 0..<60 { if let f = c.nextFixture, c.pendingWindow == nil { c.play(fixtureId: f.id) } }
        XCTAssertTrue(c.windowOpen)
        c.settings.marketAlwaysOpen = false
        XCTAssertFalse(c.windowOpen)
        c.settings.marketAlwaysOpen = true
        // Pay the asking price: the player joins at once.
        XCTAssertNil(c.exchangeGold(c.gold))
        c.buy(.tester)
        XCTAssertNil(c.exchangeGold(20_000))
        let target = c.marketPlayers(sort: .rating).first { $0.clubId != nil && !$0.overseas }!
        guard case .accepted = c.makeOffer(playerId: target.id, fee: c.askingPrice(target), wage: c.userWageDemand(target)) else {
            return XCTFail("asking price should buy him")
        }
        XCTAssertEqual(c.players[target.id]?.clubId, c.userClubId)
        // Difficulty moves prices and the user's ratings.
        let p = c.marketPlayers(sort: .value).first { $0.clubId != nil }!
        let normalAsk = c.askingPrice(p), normalWage = c.userWageDemand(p)
        let normalBat = c.side(c.userClubId).xi.map(\.bat)
        c.settings.difficulty = .hard
        XCTAssertGreaterThan(c.askingPrice(p), normalAsk)
        XCTAssertGreaterThan(c.userWageDemand(p), normalWage)
        XCTAssertEqual(c.side(c.userClubId).xi.map(\.bat), normalBat.map { max(1, $0 - 2) })
        c.settings.difficulty = .easy
        XCTAssertLessThan(c.askingPrice(p), normalAsk)
        // Filters: openers only, spinners only; all players listed.
        XCTAssertTrue(c.marketPlayers(slot: .open).allSatisfy { $0.slot == .open })
        XCTAssertTrue(c.marketPlayers(bowlType: .spin).allSatisfy { $0.bowlType == .spin && $0.bowl >= 40 })
        let everyone = c.players.values.filter { !$0.retired && $0.clubId != c.userClubId && $0.academyOf == nil }.count
        XCTAssertEqual(c.marketPlayers().count, min(everyone, 600))
    }

    func testMigrationFromSchema7() throws {
        let c = newCareer(seed: 83)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 7
        json["settings"] = nil
        let back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.settings, CareerSettings())
    }
}
