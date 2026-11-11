import XCTest
@testable import AuctionEngine

/// Owner's request: scouts with jobs that help build the squad.
extension CareerTests {
    func testUpgradeScoutFindsBetterPlayersInTheSameRole() {
        var c = newCareer(seed: 41)
        let target = c.userClub.xi.compactMap { c.players[$0] }.filter { $0.role == .AR }.min { $0.rating < $1.rating }
            ?? c.squad(c.userClubId).min { $0.rating < $1.rating }!
        XCTAssertNil(c.scoutUpgrade(for: target.id))
        let scout = c.upgradeScout(for: target.id)!
        let picks = c.scoutPicks(scout)
        XCTAssertFalse(picks.isEmpty, "a first look straight away")
        for pick in picks {
            XCTAssertEqual(pick.player.role, target.role)
            XCTAssertGreaterThanOrEqual(pick.gain ?? 0, 2)
            XCTAssertNotEqual(pick.player.clubId, c.userClubId)
        }
        // Affordable picks come before ones the user can't afford yet.
        if let firstNo = picks.firstIndex(where: { !$0.affordable }) {
            XCTAssertFalse(picks[firstNo...].contains { $0.affordable && $0.gain! <= picks[firstNo].gain! })
        }
        // More matches, more names (and reports with a note).
        let reports = c.scouting.reports.count
        for _ in 0..<8 { c.scoutTick() }
        XCTAssertGreaterThanOrEqual(c.scoutPicks(c.upgradeScout(for: target.id)!).count, picks.count)
        XCTAssertGreaterThan(c.scouting.reports.count, reports)
        XCTAssertNotNil(c.scouting.reports.first?.note)
    }

    func testBowlingPlanScoutFindsBowlersForWeakSlots() {
        var c = newCareer(seed: 42)
        let weak = c.weakPlanSlots()
        XCTAssertFalse(weak.isEmpty, "a new club's plan has slots that only read ok")
        XCTAssertNil(c.scoutBowlingPlan())
        let scout = c.scout(on: .bowlingPlan)!
        for _ in 0..<3 { c.scoutTick() }
        let picks = c.scoutPicks(scout)
        XCTAssertFalse(picks.isEmpty)
        for pick in picks {
            XCTAssertTrue(weak.contains { Career.slotFit(pick.player, slot: $0) > MatchEngine.slotSuits }, pick.player.name)
        }
    }

    func testHomePitchAndBargainScouts() {
        var c = newCareer(seed: 43)
        let s = c.scouting.scouts[0]
        c.setScoutMission(s.id, mission: .homePitch)
        for _ in 0..<4 { c.scoutTick() }
        let home = c.scoutPicks(c.scouting.scouts[0])
        XCTAssertFalse(home.isEmpty)
        XCTAssertTrue(home.allSatisfy { c.suitsUserPitch($0.player) == true })
        c.setScoutMission(s.id, mission: .bargains)
        for _ in 0..<4 { c.scoutTick() }
        let deals = c.scoutPicks(c.scouting.scouts[0])
        XCTAssertFalse(deals.isEmpty)
        XCTAssertTrue(deals.allSatisfy { $0.affordable && $0.player.rating >= 72 })
    }

    func testOldScoutsDecodeWithoutAJob() throws {
        let c = newCareer(seed: 44)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        var scouting = json["scouting"] as! [String: Any]
        scouting["scouts"] = (scouting["scouts"] as! [[String: Any]]).map { s in
            var s = s; s["mission"] = nil; s["targetId"] = nil; return s
        }
        json["scouting"] = scouting
        let back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.mission(of: back.scouting.scouts[0]), .talent)
    }
}
