import XCTest
@testable import AuctionEngine

/// Career › Squad › Squad planner.
extension CareerTests {
    func testAutoPlanGivesALegalXIAsGoodAsAutoPick() {
        for seed in [801, 802, 803, 804, 805] as [UInt64] {
            var c = newCareer(seed: seed, club: Int(seed % 10))
            c.autoPlan()
            for slot in PlanSlot.allCases {
                let list = c.planned(slot)
                // Backups must fit the job; a starter may be the best player left when nobody who fits is free.
                XCTAssertTrue(list.dropFirst(slot.starters).allSatisfy(slot.fits), "\(slot) backup can't do the job")
                XCTAssertLessThanOrEqual(list.count, SquadPlan.depth)
            }
            let (ids, issues) = c.xiFromPlan()
            XCTAssertNotNil(ids, "seed \(seed): \(issues)")
            var auto = c
            auto.autoPickXI(clubIndex: auto.userClubIndex)
            XCTAssertTrue(c.applyPlan().isEmpty)
            XCTAssertFalse(c.settings.assistantPicksXI, "using the plan is a manual pick")
            XCTAssertGreaterThanOrEqual(c.strength(c.userClubId), auto.strength(c.userClubId) - 3, "seed \(seed)")
            let xi = c.userClub.xi.compactMap { c.player($0) }
            XCTAssertFalse(xi.indices.contains { xi[$0].isExposed(atPosition: $0) }, "batting order from the plan")
        }
    }

    func testPlanEditing() {
        var c = newCareer(seed: 806)
        c.autoPlan()
        let slot = PlanSlot.seamers
        let first = c.planned(slot)[0].id, second = c.planned(slot)[1].id
        c.planMove(slot, second, by: -1)
        XCTAssertEqual(c.planned(slot).prefix(2).map(\.id), [second, first])
        c.planRemove(slot, first)
        XCTAssertFalse(c.planned(slot).contains { $0.id == first })
        let extra = c.planCandidates(slot).first!
        c.planAdd(slot, extra.id)
        XCTAssertEqual(c.planned(slot).last?.id, extra.id)
        c.planClear(slot)
        XCTAssertTrue(c.planned(slot).isEmpty)
        XCTAssertNotNil(c.xiFromPlan().issues.first, "a cleared job leaves the plan short of 11")
        // A player who leaves drops out of the plan.
        c.autoPlan()
        let gone = c.planned(.openers)[0].id
        c.clubs[c.userClubIndex].squad.removeAll { $0 == gone }
        c.players[gone]?.clubId = nil
        XCTAssertFalse(c.planned(.openers).contains { $0.id == gone })
    }

    func testPlanTargetWouldStart() {
        var c = newCareer(seed: 807)
        c.autoPlan()
        for slot in PlanSlot.allCases {
            guard let t = c.planTarget(slot) else { continue }
            let bar = c.planned(slot).prefix(slot.starters).map { slot.score($0) }.min() ?? 0
            XCTAssertGreaterThan(slot.score(t), bar)
            XCTAssertNotEqual(t.clubId, c.userClubId)
        }
    }

    func testSuccessionWarning() {
        var c = newCareer(seed: 808)
        c.autoPlan()
        // Keep only the starters, then age the first keeper.
        let keeper = c.planned(.keeper)[0]
        c.plan?.slots[PlanSlot.keeper.rawValue] = [keeper.id]
        let old = CareerPlayer(id: keeper.id, name: keeper.name, country: keeper.country, role: keeper.role,
                               bowlType: keeper.bowlType, slot: keeper.slot, traits: keeper.traits, born: c.year - 35,
                               attr: keeper.attr, potential: keeper.potential, legend: keeper.legend,
                               generated: keeper.generated, line: keeper.line, clubId: keeper.clubId)
        c.players[keeper.id] = old
        XCTAssertNotNil(c.planSummary(.keeper).successionWarning)
    }
}
