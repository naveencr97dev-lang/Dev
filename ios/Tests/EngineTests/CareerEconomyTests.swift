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
}
