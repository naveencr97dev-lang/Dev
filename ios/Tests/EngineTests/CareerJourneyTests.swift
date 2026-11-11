import XCTest
@testable import AuctionEngine

/// Layer-2 smoke test: plays a career by pressing CONTINUE (`Career.nextAction`), through three
/// seasons (including a mega auction and both international windows), and fails on any dead end.
extension CareerTests {
    func testPlayerJourneyHasNoDeadEnds() {
        var c = newCareer(seed: 77)
        var steps = 0, userMatches = 0, intlMatches = 0, bids = 0
        var seen = Set<String>()
        while c.year < 2031 && steps < 5_000 {
            steps += 1
            let action = c.nextAction
            XCTAssertFalse(c.nextActionLabel.title.isEmpty)
            seen.insert("\(action)".components(separatedBy: "(").first!)
            let before = (c.year, c.phase, c.results.count, c.intl.results.count, c.offseason?.stage, c.offseason?.auction.index)
            switch action {
            case .goToOffseason:
                c.beginOffseason()
                if let offer = c.intl.offers.first, c.intl.job == nil { c.acceptJob(offer) }
            case .openWindow: c.ensureWindow()
            case .playIntl(let id):
                XCTAssertNotNil(c.play(fixtureId: id)); intlMatches += 1
            case .simWindow: c.simWindow(stopAtUser: true)
            case .retention: c.confirmRetention(userKeeps: c.suggestedRetentions())
            case .auction:
                // Bid on the first few lots like a player would, then hand over to the staff.
                if bids < 6, c.userBid() { bids += 1; c.passLot() } else { c.simRestOfAuction(autoBid: true) }
            case .startSeason:
                if let fa = c.freeAgents.first(where: { !$0.overseas && c.wageDemand($0) <= c.capRoom(c.userClubId) }),
                   c.squad(c.userClubId).count < c.tuning.maxSquad {
                    _ = c.makeOffer(playerId: fa.id, fee: 0, wage: c.wageDemand(fa))
                }
                c.startSeasonFromOffseason()
            case .playMatch(let id):
                XCTAssertNotNil(c.play(fixtureId: id), "user match \(id) wouldn't play")
                userMatches += 1
                // Between matches: spend points, upgrade, buy gold.
                if c.manager.points > 0, let p = Perk.allCases.first(where: { c.canLearn($0) == nil }) { c.learn(p) }
                if c.facilities.building == nil { c.upgrade(.trainingGround) }
            case .continueToMatch: c.simUntilUserMatch()
            case .watchOther(let id): XCTAssertNotNil(c.play(fixtureId: id))
            case .none: XCTFail("dead end in \(c.phase) \(c.year)"); return
            }
            let after = (c.year, c.phase, c.results.count, c.intl.results.count, c.offseason?.stage, c.offseason?.auction.index)
            if before == after && action != .startSeason && action != .openWindow {
                XCTFail("no progress after \(action) in \(c.year) \(c.phase)")
                return
            }
            assertLegalSquadsIfInSeason(c)
        }
        XCTAssertEqual(c.year, 2031, "reached the 2031 season (after steps: \(steps))")
        XCTAssertGreaterThanOrEqual(userMatches, 3 * 36, "played every league match")
        XCTAssertGreaterThan(intlMatches, 0, "coached the national side")
        XCTAssertTrue(seen.isSuperset(of: ["goToOffseason", "retention", "auction", "startSeason", "playMatch", "continueToMatch"]), "\(seen)")
        // The international window opens from its own step or from "continue to match" (the
        // schedule is drawn each season); either way the window has to be reached.
        XCTAssertFalse(seen.isDisjoint(with: ["openWindow", "simWindow", "playIntl"]), "\(seen)")
        XCTAssertGreaterThan(c.history.count, 2)
        // The save still round-trips at the end.
        XCTAssertNoThrow(try CareerSave.decode(CareerSave.encode(c)))
    }

    private func assertLegalSquadsIfInSeason(_ c: Career) {
        guard c.phase == .season else { return }
        for club in c.clubs {
            XCTAssertGreaterThanOrEqual(club.squad.count, 11, "\(club.short) can't field an XI")
        }
    }
}
