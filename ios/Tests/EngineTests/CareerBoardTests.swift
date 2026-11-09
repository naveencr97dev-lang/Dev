import XCTest
@testable import AuctionEngine

/// Career › Club › Board (objectives, monthly awards) and the panel-driven market changes.
extension CareerTests {
    func testObjectivesAreSetAndJudged() {
        var c = newCareer(seed: 301)
        XCTAssertEqual(c.board.year, c.year)
        XCTAssertEqual(c.board.objectives.map(\.kind), Objective.Kind.allCases)
        XCTAssertTrue(c.board.objectives.allSatisfy { $0.met == nil && $0.target > 0 })
        let (gold, confidence) = (c.gold, c.board.confidence)
        c.simToSeasonEnd()
        XCTAssertEqual(c.phase, .seasonEnd)
        XCTAssertTrue(c.board.objectives.allSatisfy { $0.met != nil }, "judged at the final")
        let met = c.board.objectives.filter { $0.met == true }
        XCTAssertGreaterThanOrEqual(c.gold, gold + met.map(\.gold).reduce(0, +))
        XCTAssertNotEqual(c.board.confidence, confidence)
        XCTAssertTrue(c.news.contains { $0.text.hasPrefix("Board review") })
        // Next season: new objectives.
        c.startNextSeason()
        XCTAssertEqual(c.board.year, c.year)
        XCTAssertTrue(c.board.objectives.allSatisfy { $0.met == nil })
    }

    func testMonthlyAwardsEveryLeagueMonth() {
        var c = newCareer(seed: 302)
        c.simToSeasonEnd()
        let leagueMonths = Set(c.leagueFixtures.map { CareerCalendar.monthDay(c.day(of: $0)).month })
        let awarded = Set(c.board.awards.filter { $0.year == c.year }.map(\.month))
        XCTAssertEqual(awarded, leagueMonths, "one award per month with league cricket")
        XCTAssertTrue(c.board.awards.allSatisfy { !$0.line.isEmpty && c.club($0.managerClub) != nil })
    }

    func testAITransfersSpendSurplusAndKeepSquadsLegal() {
        var c = newCareer(seed: 303)
        for ci in c.clubs.indices where c.clubs[ci].isCPU { c.finance[c.clubs[ci].id].bank = 8_000 }
        let before = c.clubs.filter(\.isCPU).map { c.bank($0.id) }.reduce(0, +)
        c.aiTransfers()
        let after = c.clubs.filter(\.isCPU).map { c.bank($0.id) }.reduce(0, +)
        // Fees move between AI clubs (the total is conserved), and some deals happen.
        XCTAssertEqual(before, after)
        XCTAssertTrue(c.news.contains { $0.text.hasPrefix("✍️") }, "rich AI clubs buy")
        XCTAssertTrue(c.squad(c.userClubId).allSatisfy { $0.clubId == c.userClubId }, "the user's players are never taken")
        for club in c.clubs { XCTAssertGreaterThanOrEqual(club.squad.count, c.tuning.minSquad) }
    }

    func testPitchCalibrationOnlyInCareer() {
        let c = newCareer(seed: 304)
        let id = c.userClub.xi[0]
        let flat = c.enginePlayer(id, pitch: .indianFlat)!.bat
        let seam = c.enginePlayer(id, pitch: .englishSeam)!.bat
        XCTAssertEqual(seam - flat, min(c.tuning.pitchBatBoost[1], 99 - flat))
    }

    func testScoutAdviceFlagsUpgrades() {
        let c = newCareer(seed: 305)
        let xi = c.userClub.xi.compactMap { c.players[$0] }
        let weakest = xi.min { $0.rating < $1.rating }!
        var star = weakest
        star.clubId = nil
        for k in [\Attributes.technique, \.power, \.vsPace, \.vsSpin, \.temperament,
                  \.accuracy, \.potency, \.variation, \.death, \.newBall] { star.attr[keyPath: k] = 99 }
        XCTAssertTrue(c.scoutAdvice(star).good, c.scoutAdvice(star).text)
    }

    func testMigrationFromSchema9() throws {
        let c = newCareer(seed: 306)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 9
        json["board"] = nil
        var t = json["tuning"] as! [String: Any]
        t["pitchBatBoost"] = nil; t["aiReserveBank"] = nil; t["aiDealsPerWindow"] = nil; t["aiUpgradeMargin"] = nil
        json["tuning"] = t
        let back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.board, BoardState())
        XCTAssertEqual(back.tuning.pitchBatBoost, CareerTuning.standard.pitchBatBoost)
    }
}
