import XCTest
@testable import AuctionEngine

/// Career › Squad › Form (which replaced morale and squad roles) and the squad report.
extension CareerTests {
    func testFormLabelsAndTrend() {
        XCTAssertEqual(Career.formLabel(8), "Red hot")
        XCTAssertEqual(Career.formLabel(0), "Steady")
        XCTAssertEqual(Career.formLabel(-8), "Out of form")
        var c = newCareer(seed: 701)
        let star = c.userClub.xi[0]
        XCTAssertEqual(c.formTrend(star), 0, "no matches yet")
        c.simToSeasonEnd()
        XCTAssertTrue([-1, 0, 1].contains(c.formTrend(star)))
    }

    func testOfferMoodFollowsTheWage() {
        let c = newCareer(seed: 702)
        let p = c.freeAgents.first { c.userWageDemand($0) > c.tuning.minWage * 2 }!
        let demand = c.userWageDemand(p)
        XCTAssertEqual(c.offerMood(p, wage: demand), 1, "meeting the demand is a full bar")
        XCTAssertEqual(c.offerMood(p, wage: demand * 7 / 10), 0)
        XCTAssertTrue((0.01..<1).contains(c.offerMood(p, wage: demand * 9 / 10)))
    }

    func testSquadReportListsFormAndBothSides() {
        var c = newCareer(seed: 703)
        let r0 = c.squadReport()
        XCTAssertEqual(r0.stars.count, 3)
        XCTAssertFalse(r0.strengths.isEmpty && r0.weaknesses.isEmpty)
        // A cold player in the XI shows up as a weak spot.
        let id = c.userClub.xi[0]
        c.players[id]?.form = -8
        XCTAssertTrue(c.squadReport().weaknesses.contains { $0.hasPrefix("Out of form") && $0.contains(c.players[id]!.name) })
    }

    func testMigrationFromSchema12DropsMorale() throws {
        let c = newCareer(seed: 704)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 12
        var players = json["players"] as! [String: Any]
        let id = c.userClub.xi[0]
        var p = players[id] as! [String: Any]
        p["squadRole"] = "key"; p["morale"] = 40; p["rolePromised"] = true
        players[id] = p
        json["players"] = players
        let back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.players[id]?.form, c.players[id]?.form)
        let again = try JSONSerialization.jsonObject(with: CareerSave.encode(back)) as! [String: Any]
        XCTAssertNil(((again["players"] as! [String: Any])[id] as! [String: Any])["morale"])
    }
}

extension CareerTests {
    /// Panel round 5: the opening draft left CHE 3 below the AI average and it never won a title.
    func testOpeningDraftIsBalanced() {
        for seed in [11, 900, 2027, 4242] as [UInt64] {
            let c = newCareer(seed: seed)
            let s = c.clubs.map { c.strength($0.id) }
            XCTAssertLessThanOrEqual(s.max()! - s.min()!, c.tuning.draftBalance + 1, "seed \(seed): \(s)")
            for club in c.clubs { XCTAssertGreaterThanOrEqual(club.squad.count, c.tuning.minSquad) }
        }
    }
}

extension CareerTests {
    func testRoleDescriptions() {
        let c = newCareer(seed: 905)
        let all = c.players.values.filter { !$0.retired }
        XCTAssertTrue(all.allSatisfy { !$0.roleDescription.isEmpty })
        for p in all {
            switch p.role {
            case .BOWL: XCTAssertTrue(p.roleDescription.hasSuffix("bowler"), p.roleDescription)
            case .AR: XCTAssertTrue(p.roleDescription.hasPrefix("All-rounder"), p.roleDescription)
            case .WK: XCTAssertTrue(p.roleDescription.hasPrefix("Keeper"), p.roleDescription)
            case .BAT: XCTAssertTrue(p.roleDescription.hasSuffix("batter") || p.roleDescription == "Finisher", p.roleDescription)
            }
            if p.bowlType == .spin, p.bowl >= 50 { XCTAssertEqual(p.bowlingStyle, "spin") }
        }
        XCTAssertTrue(all.contains { $0.roleDescription == "Fast bowler" })
        XCTAssertTrue(all.contains { $0.roleDescription == "Medium pace bowler" })
        XCTAssertTrue(all.contains { $0.roleDescription == "Spin bowler" })
    }
}
