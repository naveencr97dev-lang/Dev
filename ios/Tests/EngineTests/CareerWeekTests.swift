import XCTest
@testable import AuctionEngine

/// Training session button and the season's money.
extension CareerTests {
    func testTrainingSessionAndSeasonMoney() {
        var c = newCareer(seed: 101)
        c.simUntilUserMatch()
        // A manual session runs once per week and replaces the automatic one.
        c.setTraining(TrainingPlan(drills: [.powerHitting, .rotation, .deathBowling], intensity: .hard))
        _ = c.runTrainingSession()
        XCTAssertTrue(c.trainingDoneThisWeek)
        XCTAssertTrue(c.runTrainingSession().isEmpty, "only once a week")
        let f = c.nextUserFixture!
        c.play(fixtureId: f.id)
        XCTAssertFalse(c.trainingDoneThisWeek, "a new week starts after the match")
        // Season money is tracked by category; ticket price moves the gate.
        c.simUntilUserMatch()
        if let g = c.nextUserFixture, g.home != c.userClubId { c.play(fixtureId: g.id); c.simUntilUserMatch() }
        XCTAssertGreaterThan(c.seasonTotal(.merchandise), 0)
        let normal = c.expectedGate!
        c.settings.ticketPrice = .high
        let high = c.expectedGate!
        XCTAssertLessThan(high.fans, normal.fans)
        XCTAssertGreaterThan(high.money, normal.money * 9 / 10)
        c.settings.ticketPrice = .low
        XCTAssertGreaterThan(c.expectedGate!.fans, normal.fans)
    }

    func testMigrationFromSchema8() throws {
        let c = newCareer(seed: 102)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 8
        json["trainingDoneThisWeek"] = nil
        json["seasonMoney"] = nil
        var s = json["settings"] as! [String: Any]; s["ticketPrice"] = nil; json["settings"] = s
        let back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.settings.ticketPrice, .normal)
        XCTAssertFalse(back.trainingDoneThisWeek)
    }
}
