import XCTest
@testable import AuctionEngine

/// Club money (owner's requests): prize money, ticket sales, facility costs and the sponsor.
extension CareerTests {
    func testPrizeMoneyAndGate() {
        let c = newCareer(seed: 1301)
        XCTAssertEqual(c.tuning.prizeMoney.first, 4_000, "₹40 Cr to the champions")
        // Smallest crowd (55%), normal price and difficulty, a level-2 stadium: at least ₹50 L.
        XCTAssertEqual(c.facility(.stadium), 2)
        XCTAssertGreaterThanOrEqual(Career.round5(Double(c.gate(for: c.userClubId)) * 0.55 * 1.3), 50)
    }

    /// A season of ticket sales (18 home matches, smallest crowd) pays for one upgrade of every
    /// facility when they're at the stadium's level, at every level.
    func testTicketsPayForAnUpgradeOfEachFacility() {
        var c = newCareer(seed: 1302)
        let homeGames = c.leagueFixtures.filter { $0.home == c.userClubId }.count
        XCTAssertEqual(homeGames, 18)
        for level in 1...9 {
            for k in FacilityKind.allCases { c.facilities.levels[k.rawValue] = level }
            let perMatch = Career.round5(Double(c.gate(for: c.userClubId)) * 0.55 * 1.3)
            let tickets = perMatch * homeGames
            let upgrades = FacilityKind.allCases.map { c.upgradeCost($0) }.reduce(0, +)
            XCTAssertGreaterThanOrEqual(tickets, upgrades, "level \(level): tickets \(tickets), upgrades \(upgrades)")
        }
    }

    /// The sponsor pays once a month through the season, and only for January to November.
    func testSponsorPaysEachMonthOfTheSeason() {
        var c = newCareer(seed: 1303)
        c.simToSeasonEnd()
        // (The ledger keeps the last 40 entries; the season total counts every payment.)
        let recent = c.finance[c.userClubId].ledger.filter { $0.text.hasPrefix("Sponsor:") && $0.year == c.year }
        XCTAssertTrue(recent.allSatisfy { $0.amount == c.sponsorMonthly(for: c.userClubId) })
        XCTAssertFalse(recent.contains { $0.text.contains("(Dec)") })
        XCTAssertEqual(c.seasonTotal(.sponsors), c.sponsorMonthly(for: c.userClubId) * Career.sponsorMonths)
        XCTAssertGreaterThanOrEqual(c.sponsorMonthly(for: c.userClubId), 40)
    }

    /// Owner's targets: ₹25 Cr starting money buys an 85-86, 90+ players cost about ₹45 Cr and up,
    /// the very best ₹50-75 Cr, and a season's profit buys one star at most.
    func testTransferFeesMatchTheOwnersTargets() {
        var c = newCareer()
        let me = c.userClubId
        let others = c.players.values.filter { $0.clubId != nil && $0.clubId != me && !$0.retired }
        let mid = others.filter { $0.rating == 85 || $0.rating == 86 }.map { c.askingPrice($0) }
        XCTAssertFalse(mid.isEmpty)
        XCTAssertLessThanOrEqual(mid.min()!, c.bank(me), "an 85-86 is affordable on day 1")
        let stars = others.filter { $0.rating >= 90 }
        XCTAssertFalse(stars.isEmpty)
        for p in stars {
            XCTAssertGreaterThan(c.askingPrice(p), c.bank(me), "\(p.name) affordable on day 1")
            XCTAssertGreaterThanOrEqual(c.askingPrice(p), 4_000, p.name)
            XCTAssertLessThanOrEqual(c.askingPrice(p), 7_500, p.name)
        }
        XCTAssertGreaterThanOrEqual(CareerPlayer.feeCurve(95) * c.tuning.askXIMultiplier, 6_000)
        // A season's profit (after wages) buys one star, not two.
        let before = c.bank(me)
        c.simToSeasonEnd()
        c.beginOffseason()
        let cheapest = stars.map { c.askingPrice($0) }.min()!
        XCTAssertLessThan(c.bank(me) - before, cheapest * 2)
    }
}
