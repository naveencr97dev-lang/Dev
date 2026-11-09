import XCTest
@testable import AuctionEngine

/// M4: facilities, finances, the manager and gold.
extension CareerTests {
    func testFacilitiesBuildAndPay() {
        var c = newCareer(seed: 41)
        let me = c.userClubId
        XCTAssertEqual(c.facility(.trainingGround), 2)
        XCTAssertEqual(c.trainingSlots, 3)
        let cost = c.upgradeCost(.trainingGround)
        let bank = c.bank(me)
        XCTAssertNil(c.upgrade(.trainingGround))
        XCTAssertEqual(c.bank(me), bank - cost)
        XCTAssertNotNil(c.upgrade(.stadium), "one build at a time")
        let weeks = c.facilities.weeksLeft
        XCTAssertEqual(weeks, 3)
        for _ in 0..<(weeks - 1) { c.facilityTick() }
        XCTAssertEqual(c.facility(.trainingGround), 2)
        c.facilityTick()
        XCTAssertEqual(c.facility(.trainingGround), 3)
        XCTAssertEqual(c.trainingSlots, 4, "+1 slot at level 3")
        // Gold finishes a build instantly.
        XCTAssertNil(c.upgrade(.stadium))
        c.buy(.tester)
        XCTAssertGreaterThanOrEqual(c.gold, 1_000_000)
        XCTAssertNil(c.spendGold(.finishBuild))
        XCTAssertEqual(c.facility(.stadium), 3)
        XCTAssertNil(c.facilities.building)
    }

    func testSeasonAccounts() {
        var c = newCareer(seed: 42)
        c.simToSeasonEnd()
        let before = c.bank(c.userClubId)
        let wages = c.payroll(c.userClubId)
        c.beginOffseason()
        let ledger = c.finance[c.userClubId].ledger
        XCTAssertTrue(ledger.contains { $0.text == "Wages" && $0.amount == -wages })
        XCTAssertTrue(ledger.contains { $0.text.hasPrefix("Gate money (1") || $0.text.hasPrefix("Gate money (2") }, "18 home league games plus any home playoffs")
        XCTAssertTrue(ledger.contains { $0.text == "Facility upkeep" })
        XCTAssertNotEqual(c.bank(c.userClubId), before)
        // Revenue roughly covers a full payroll: no club is wildly in debt after a season.
        for club in c.clubs { XCTAssertGreaterThan(c.bank(club.id), -3_000, club.short) }
    }

    func testManagerLevelsAndPerks() {
        var c = newCareer(seed: 43)
        XCTAssertEqual(c.manager.level, 1)
        let gold = c.gold
        c.gainXP(ManagerProfile.xpFor(level: 1) + ManagerProfile.xpFor(level: 2), reason: nil)
        XCTAssertGreaterThanOrEqual(c.manager.level, 3)
        XCTAssertEqual(c.manager.points, c.manager.level - 1)
        XCTAssertGreaterThan(c.gold, gold)
        // Tier rules.
        XCTAssertNotNil(c.canLearn(.veteranCare), "tier 2 needs 2 training perks first")
        XCTAssertNil(c.learn(.drillMaster))
        XCTAssertNil(c.learn(.extraSession))
        XCTAssertEqual(c.trainingSlots, 4, "Extra Session adds a slot")
        c.gainXP(100_000, reason: nil)
        XCTAssertNil(c.learn(.veteranCare))
        XCTAssertNotNil(c.learn(.veteranCare))
        // Negotiator lowers what players ask.
        let fa = c.freeAgents.first { !$0.overseas }!
        let full = c.wageDemand(fa)
        XCTAssertNil(c.learn(.negotiator))
        let cheaper = Career.round5(Double(full) * 0.9)
        guard case .accepted = c.makeOffer(playerId: fa.id, fee: 0, wage: cheaper) else { return XCTFail("negotiated wage") }
        // Captain's Call lifts the user's XI in the engine.
        let plain = c.side(c.userClubId).xi.map(\.bat)
        XCTAssertNil(c.learn(.captainsCall))
        let lifted = c.side(c.userClubId).xi.map(\.bat)
        XCTAssertEqual(zip(plain, lifted).filter { $1 == $0 + 1 || $0 >= 99 }.count, plain.count)
    }

    func testGoldItemsAndStore() {
        var c = newCareer(seed: 44)
        XCTAssertEqual(c.gold, c.tuning.startingGold)
        for _ in 0..<3 { c.buy(.tester) }
        XCTAssertEqual(c.gold, c.tuning.startingGold + 3_000_000, "tester pack is unlimited")
        let stranger = c.freeAgents.first { c.knowledge(of: $0.id) < 100 }!
        XCTAssertNil(c.spendGold(.scoutReport, playerId: stranger.id))
        XCTAssertEqual(c.potentialRange(stranger).count, 1)
        let mine = c.userClub.squad[0]
        XCTAssertNil(c.spendGold(.freshLegs, playerId: mine))
        XCTAssertGreaterThanOrEqual(c.players[mine]!.form, 3)
        XCTAssertNil(c.spendGold(.trainingBoost))
        XCTAssertEqual(c.trainingBoostWeeks, 4)
        XCTAssertNotNil(c.spendGold(.finishBuild), "nothing to finish")
    }

    func testMigrationFromSchema3() throws {
        let c = newCareer(seed: 45)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 3
        for k in ["facilities", "manager", "gold", "trainingBoostWeeks"] { json[k] = nil }
        let back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.facility(.stadium), 2)
        XCTAssertEqual(back.gold, back.tuning.startingGold)
        XCTAssertEqual(back.manager.level, 1)
    }
}
