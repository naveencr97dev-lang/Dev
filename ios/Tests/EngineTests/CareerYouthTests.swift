import XCTest
@testable import AuctionEngine

/// Owner's request: young real players with high potential, faster growth, and pay rises that a
/// club can afford.
extension CareerTests {
    func testEliteYoungstersHaveSuperstarPotential() {
        let c = newCareer()
        for id in ["sai-sudharsan", "yashasvi-jaiswal", "noor-ahmad"] {
            let p = c.players[id]!
            XCTAssertGreaterThanOrEqual(p.potential, 92, p.name)
            XCTAssertLessThanOrEqual(p.potential, 95, p.name)
        }
        for p in c.players.values where !p.generated && p.age(in: c.year) >= 29 {
            XCTAssertEqual(p.potential, max(p.bat, p.bowl), "\(p.name): no growth left at 29+")
        }
    }

    func testLateBloomerKeepsGrowingAndGetsAffordableRaises() {
        var c = newCareer()
        let id = "sai-sudharsan"
        let me = c.userClubId
        // Move him to the user's club so the raise lands on the user's payroll.
        if let from = c.players[id]?.clubId, let fi = c.clubs.firstIndex(where: { $0.id == from }),
           let mi = c.clubs.firstIndex(where: { $0.id == me }) {
            c.clubs[fi].squad.removeAll { $0 == id }; c.clubs[fi].xi.removeAll { $0 == id }
            c.clubs[mi].squad.append(id); c.players[id]?.clubId = me
        }
        let start = c.players[id]!.rating
        let wage = c.players[id]!.contract!.wage
        for _ in 0..<2 { c.simToSeasonEnd(); c.startNextSeason() }
        let p = c.players[id]!
        XCTAssertGreaterThanOrEqual(p.rating, start + 4, "84 at 26 with 94 potential keeps climbing")
        XCTAssertGreaterThan(p.contract!.wage, wage, "a pay rise as he improves")
        XCTAssertLessThanOrEqual(c.payroll(me), c.tuning.salaryCap + c.tuning.minWage * 7)
    }

    func testOldSavesGetTheNewPotential() throws {
        var c = newCareer()
        c.players["noor-ahmad"]?.potential = 81
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 15
        let back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertGreaterThanOrEqual(back.players["noor-ahmad"]!.potential, 92)
        let again = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(again.players["noor-ahmad"]!.potential, back.players["noor-ahmad"]!.potential, "same on every load")
    }
}
