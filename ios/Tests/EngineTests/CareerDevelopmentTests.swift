import XCTest
@testable import AuctionEngine

/// M3: training, scouting and the youth academy.
extension CareerTests {
    func testTrainingImprovesYoungPlayersWithinPotential() {
        var c = newCareer(seed: 31)
        let me = c.userClubId
        let young = c.squad(me).filter { $0.age(in: c.year) <= 24 && $0.potential > max($0.bat, $0.bowl) + 3 }
        XCTAssertFalse(young.isEmpty)
        let target = young[0]
        var plan = TrainingPlan(drills: [.powerHitting, .rotation, .deathBowling], intensity: .hard)
        plan.focus[target.id] = "power"
        c.setTraining(plan)
        let before = target.attr
        for _ in 0..<36 { c.trainingTick() }
        let after = c.players[target.id]!
        XCTAssertGreaterThan(after.attr.power, before.power, "focused attribute grows")
        for p in c.squad(me) { XCTAssertLessThanOrEqual(max(p.bat, p.bowl), max(p.potential, max(c.players[p.id]!.bat, c.players[p.id]!.bowl))) }
        for p in c.players.values where !p.retired {
            XCTAssertLessThanOrEqual(max(p.bat, p.bowl), max(p.potential, 99))
        }
        // Slots are capped.
        c.setTraining(TrainingPlan(drills: Drill.allCases))
        XCTAssertEqual(c.training.drills.count, c.trainingSlots)
    }

    func testScoutingNarrowsPotential() {
        var c = newCareer(seed: 32)
        let mine = c.squad(c.userClubId)[0]
        XCTAssertEqual(c.potentialRange(mine).count, 1, "own players are fully known")
        let stranger = c.freeAgents.first { c.knowledge(of: $0.id) == 0 }!
        let wide = c.potentialRange(stranger)
        XCTAssertGreaterThan(wide.count, 10)
        XCTAssertTrue(wide.contains(stranger.potential) || wide.lowerBound == max(stranger.bat, stranger.bowl))
        // Send every scout after that player's nation for a while.
        for s in c.scouting.scouts { c.assignScout(s.id, region: stranger.country, role: stranger.role, youthOnly: false) }
        for _ in 0..<60 { c.scoutTick() }
        XCTAssertGreaterThan(c.knowledge(of: stranger.id), 0)
        XCTAssertLessThan(c.potentialRange(stranger).count, wide.count)
        XCTAssertFalse(c.scouting.reports.isEmpty)
        // Hiring costs money and is capped.
        let bank = c.bank(c.userClubId)
        let cand = c.scouting.candidates[0]
        XCTAssertNil(c.hireScout(cand.id))
        XCTAssertEqual(c.bank(c.userClubId), bank - cand.wage)
        XCTAssertNotNil(c.hireScout(c.scouting.candidates[0].id), "cap of \(c.scoutCap)")
    }

    func testAcademy() {
        var c = newCareer(seed: 33)
        XCTAssertTrue((2...4).contains(c.academy.count))
        let kid = c.academyPlayers[0]
        XCTAssertEqual(kid.academyOf, c.userClubId)
        XCTAssertFalse(c.freeAgents.contains { $0.id == kid.id }, "academy kids aren't free agents")
        XCTAssertLessThanOrEqual(kid.age(in: c.year), 18)
        XCTAssertNil(c.promote(kid.id))
        XCTAssertEqual(c.players[kid.id]?.clubId, c.userClubId)
        XCTAssertEqual(c.players[kid.id]?.contract?.wage, c.tuning.minWage)
        XCTAssertFalse(c.academy.contains(kid.id))
        // Season rollover keeps academy kids and adds more.
        c.simToSeasonEnd()
        let before = c.academy
        c.startNextSeason()
        XCTAssertTrue(before.allSatisfy { c.academy.contains($0) })
        XCTAssertGreaterThan(c.academy.count, before.count)
        XCTAssertLessThanOrEqual(c.academy.count, c.tuning.academyMax)
        assertLegalSquads(c)
    }

    func testMigrationFromSchema2() throws {
        let c = newCareer(seed: 34)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 2
        json["training"] = nil
        json["scouting"] = nil
        json["academy"] = nil
        let back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.training, TrainingPlan())
        XCTAssertTrue(back.academy.isEmpty)
        XCTAssertEqual(back.schemaVersion, Career.currentSchema)
    }
}
