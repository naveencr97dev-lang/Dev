import XCTest
@testable import AuctionEngine

/// Career › Squad › Roles and morale, and the squad report.
extension CareerTests {
    func testDefaultRolesFollowTheXI() {
        let c = newCareer(seed: 501)
        let xi = Set(c.userClub.xi)
        for p in c.squad(c.userClubId) {
            let role = c.squadRole(p)
            if xi.contains(p.id) { XCTAssertTrue([.key, .firstTeam].contains(role), "\(p.name) is in the XI but \(role)") }
            else { XCTAssertTrue([.rotation, .backup].contains(role), "\(p.name) is on the bench but \(role)") }
        }
        XCTAssertEqual(c.keyPlayerCount, 3)
    }

    func testBrokenPromiseEndsInATransferRequest() {
        var c = newCareer(seed: 502)
        c.settings.assistantPicksXI = true
        // Promise a backup a key role: the assistant still won't pick him.
        let xi = Set(c.userClub.xi)
        let backup = c.squad(c.userClubId).filter { !xi.contains($0.id) }.min { $0.rating < $1.rating }!
        c.setSquadRole(backup.id, .key)
        XCTAssertEqual(c.players[backup.id]?.rolePromised, true)
        var guardCount = 0
        while c.market.listed[backup.id] == nil && c.phase == .season && guardCount < 200 {
            guardCount += 1
            c.simUntilUserMatch()
            if let f = c.nextUserFixture { c.play(fixtureId: f.id) } else { break }
        }
        XCTAssertNotNil(c.market.listed[backup.id], "a key-player promise never kept ends in a transfer request")
        XCTAssertTrue(c.news.contains { $0.text.contains("transfer request") })
    }

    func testCasualManagersGetNoTransferRequests() {
        var c = newCareer(seed: 503)
        c.simToSeasonEnd()
        XCTAssertTrue(c.market.listed.isEmpty, "no promises made, so nobody hands in a request")
        XCTAssertGreaterThan(c.squad(c.userClubId).map { c.morale($0) }.reduce(0, +) / c.squad(c.userClubId).count, 50)
    }

    func testPromisingABiggerRoleLowersTheWage() {
        let c = newCareer(seed: 504)
        let p = c.freeAgents.first!
        XCTAssertLessThan(c.wageDemand(p, promising: .key), c.wageDemand(p, promising: .backup))
        XCTAssertEqual(c.offerMood(p, wage: c.wageDemand(p, promising: .firstTeam), role: .firstTeam), 1)
        XCTAssertEqual(c.offerMood(p, wage: c.tuning.minWage, role: .key), c.wageDemand(p, promising: .key) <= c.tuning.minWage ? 1 : 0, accuracy: 0.5)
    }

    func testDemotionCostsMorale() {
        var c = newCareer(seed: 505)
        let star = c.squad(c.userClubId).first { c.squadRole($0) == .key }!
        let before = c.morale(star)
        c.setSquadRole(star.id, .backup)
        XCTAssertEqual(c.morale(c.players[star.id]!), max(0, before - 30))
    }

    func testSquadReportHasBothSides() {
        let c = newCareer(seed: 506)
        let r = c.squadReport()
        XCTAssertEqual(r.stars.count, 3)
        XCTAssertGreaterThan(r.averageRating, 40)
        XCTAssertFalse(r.strengths.isEmpty && r.weaknesses.isEmpty)
    }
}
