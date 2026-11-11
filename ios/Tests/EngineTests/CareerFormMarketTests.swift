import XCTest
@testable import AuctionEngine

/// Owner's requests: a form score on a 7 = average scale, and AI bids priced by form.
extension CareerTests {
    func testFormScoreScale() {
        var c = newCareer(seed: 1402)
        let anyone = c.userClub.xi[0]
        XCTAssertNil(c.formScore(anyone), "a dash before his first match")
        c.simToSeasonEnd()
        let scores = c.players.keys.sorted().filter { c.matchRatings($0).count >= 5 }.compactMap { c.formScore($0) }.sorted()
        let median = scores[scores.count / 2], p90 = scores[scores.count * 9 / 10]
        XCTAssertTrue((6.6...7.4).contains(median), "an average player reads about 7 (median \(median))")
        XCTAssertGreaterThanOrEqual(p90, 7.8, "the best tenth read 8 or so (p90 \(p90))")
        XCTAssertTrue(scores.allSatisfy { (3...10).contains($0) })
        XCTAssertEqual(Career.formScale(6.3), 7.0)
    }

    func testOffersArePricedByForm() {
        XCTAssertEqual(Career.offerRange(formScore: 5.9), 0.6...0.8, "out of form: a bargain")
        XCTAssertEqual(Career.offerRange(formScore: 7.0), 0.85...1.05)
        XCTAssertEqual(Career.offerRange(formScore: 8.0), 1.0...1.2)
        XCTAssertEqual(Career.offerRange(formScore: 9.1), 1.2...1.6, "on fire: clubs try to poach him")
        XCTAssertEqual(Career.offerRange(formScore: nil), 0.85...1.0)
    }

    /// Run 1401: overseas players got no bids (8 of 9 clubs at the overseas limit). Now they do,
    /// and the buyer releases an overseas player to stay within the limits.
    func testListedOverseasPlayerGetsBidsAndLimitsHold() {
        var c = newCareer(seed: 1403)
        c.simUntilUserMatch()
        guard let p = c.squad(c.userClubId).filter(\.overseas).sorted(by: { $0.id < $1.id }).first else { return XCTFail("no overseas") }
        c.listForTransfer(p.id, asking: p.value(in: c.year))
        for _ in 0..<6 where !c.market.offers.contains(where: { $0.playerId == p.id }) {
            if let f = c.nextUserFixture { c.play(fixtureId: f.id) }
            c.simUntilUserMatch()
        }
        guard let offer = c.market.offers.first(where: { $0.playerId == p.id }) else { return XCTFail("no bid for \(p.name)") }
        XCTAssertTrue(c.acceptOffer(offer.id))
        XCTAssertEqual(c.players[p.id]?.clubId, offer.fromClub)
        for club in c.clubs {
            XCTAssertLessThanOrEqual(c.squad(club.id).filter(\.overseas).count, c.tuning.maxOverseasSquad, club.short)
            XCTAssertLessThanOrEqual(c.squad(club.id).count, c.tuning.maxSquad, club.short)
        }
    }
}
