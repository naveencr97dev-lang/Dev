import XCTest
@testable import AuctionEngine

/// M2: contracts, auctions and the transfer market.
extension CareerTests {

    func testContractsCapAndMoney() {
        let c = newCareer()
        for club in c.clubs {
            XCTAssertLessThanOrEqual(c.payroll(club.id), c.tuning.salaryCap)
            XCTAssertGreaterThan(c.payroll(club.id), c.tuning.salaryCap / 3, "wages are meaningful")
            XCTAssertEqual(c.bank(club.id), c.tuning.startingBank)
            for p in c.squad(club.id) { XCTAssertEqual(p.contract?.until, 2030, "contracts run to the first mega auction") }
        }
        XCTAssertFalse(c.isMegaYear(2027))
        XCTAssertTrue(c.isMegaYear(2030))
        XCTAssertEqual(c.nextMegaYear(after: 2028), 2030)
        XCTAssertEqual(c.nextMegaYear(after: 2030), 2033)
    }

    func testMigrationFromSchema1() throws {
        let c = newCareer(seed: 3)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 1
        json["finance"] = nil
        json["market"] = nil
        json["offseason"] = nil
        var players = json["players"] as! [String: Any]
        for (k, v) in players {
            var p = v as! [String: Any]
            p["contract"] = nil
            players[k] = p
        }
        json["players"] = players
        let old = try JSONSerialization.data(withJSONObject: json)
        let back = try CareerSave.decode(old)
        XCTAssertEqual(back.schemaVersion, Career.currentSchema)
        XCTAssertEqual(back.finance.count, 10)
        XCTAssertTrue(back.clubs.allSatisfy { club in back.squad(club.id).allSatisfy { $0.contract != nil } })
        assertLegalSquads(back)
    }

    func testMiniAuctionOffseason() {
        var c = newCareer(seed: 12)
        c.simToSeasonEnd()
        // Revenue and prize money are paid when the final ends.
        XCTAssertTrue(c.clubs.allSatisfy { c.bank($0.id) >= c.tuning.startingBank + c.tuning.seasonRevenue })
        XCTAssertGreaterThan(c.bank(c.championId!), c.tuning.startingBank + c.tuning.seasonRevenue)
        c.beginOffseason()
        XCTAssertEqual(c.year, 2028)
        XCTAssertEqual(c.phase, .offseason)
        XCTAssertEqual(c.offseason?.stage, .auction, "2028 is a mini-auction year")
        XCTAssertGreaterThan(c.offseason?.auction.queue.count ?? 0, 10)
        // Skip lots the user can't bid on (e.g. an overseas player with the overseas slots full).
        while let id = c.offseason?.auction.currentId, let p = c.players[id],
              c.userBidBlock(p, amount: c.auctionNextBid ?? p.basePrice(in: c.year)) != nil {
            _ = c.passLot()
        }
        // The user bids on the first lot they can until they lead or can't.
        let first = c.offseason!.auction.currentId!
        XCTAssertTrue(c.userBid())
        let a = c.offseason!.auction
        XCTAssertNotNil(a.bid)
        let sale = c.passLot()!
        XCTAssertEqual(sale.playerId, first)
        if a.leader == c.userClubId {
            XCTAssertEqual(sale.clubId, c.userClubId)
            XCTAssertEqual(sale.price, a.bid)
            XCTAssertEqual(c.players[first]?.contract?.wage, a.bid)
        } else {
            XCTAssertNotEqual(sale.clubId, c.userClubId)
            XCTAssertGreaterThanOrEqual(sale.price, a.bid!)
        }
        c.simRestOfAuction()
        XCTAssertEqual(c.offseason?.stage, .window)
        XCTAssertTrue(c.windowOpen)
        c.startSeasonFromOffseason()
        XCTAssertEqual(c.phase, .season)
        XCTAssertNil(c.offseason)
        assertLegalSquads(c)
        XCTAssertGreaterThan(c.offseason == nil ? c.leagueFixtures.count : 0, 0)
    }

    func testMegaAuctionRetentions() {
        var c = newCareer(seed: 21)
        for _ in 0..<3 {
            c.simToSeasonEnd()
            if c.year < 2029 { c.startNextSeason() }
        }
        XCTAssertEqual(c.year, 2029)
        c.beginOffseason()
        XCTAssertEqual(c.year, 2030)
        XCTAssertEqual(c.offseason?.stage, .retention)
        let keep = Array(c.suggestedRetentions().prefix(2))
        c.confirmRetention(userKeeps: keep)
        XCTAssertEqual(Set(c.userClub.squad), Set(keep))
        for club in c.clubs {
            XCTAssertLessThanOrEqual(club.squad.count, c.tuning.maxRetentions)
            for p in c.squad(club.id) { XCTAssertEqual(p.contract?.until, 2033) }
        }
        XCTAssertEqual(c.offseason?.stage, .auction)
        XCTAssertGreaterThan(c.offseason!.auction.queue.count, 100, "big pool at a mega auction")
        c.simRestOfAuction()
        c.startSeasonFromOffseason()
        assertLegalSquads(c)
        // AI clubs rebuilt properly, not just with minimum-wage fillers.
        let strengths = c.clubs.filter(\.isCPU).map { c.strength($0.id) }
        XCTAssertGreaterThan(strengths.min()!, 60, "\(strengths)")
    }

    func testTransferMarket() {
        var c = newCareer(seed: 8)
        c.settings.marketAlwaysOpen = false   // this test is about the real windows
        XCTAssertTrue(c.windowOpen, "window open for the first two rounds")
        let me = c.userClubId
        // Free agent at his asking wage.
        let fa = c.freeAgents.first { !$0.overseas }!
        let demand = c.wageDemand(fa)
        if case .counter = c.makeOffer(playerId: fa.id, fee: 0, wage: Int(Double(demand) * 0.9)) {} else { XCTFail("expected a counter") }
        guard case .accepted = c.makeOffer(playerId: fa.id, fee: 0, wage: demand) else { return XCTFail("free agent") }
        XCTAssertEqual(c.players[fa.id]?.clubId, me)
        XCTAssertEqual(c.players[fa.id]?.contract?.wage, demand)

        // A bench player from an AI club, so the fee fits the bank.
        let seller = c.clubs.first { $0.isCPU }!
        let target = c.squad(seller.id).filter { !seller.xi.contains($0.id) && !$0.overseas }
            .min { c.askingPrice($0) < c.askingPrice($1) }!
        let ask = c.askingPrice(target)
        let wage = c.wageDemand(target)
        XCTAssertLessThanOrEqual(ask, c.bank(me))
        if case .rejected = c.makeOffer(playerId: target.id, fee: ask / 2, wage: wage) {} else { XCTFail("lowball should fail") }
        if case .counter(let f, _, _) = c.makeOffer(playerId: target.id, fee: ask * 9 / 10, wage: wage) {
            XCTAssertEqual(f, ask)
        } else { XCTFail("expected a counter") }
        let bankBefore = c.bank(me), sellerBefore = c.bank(seller.id)
        guard case .accepted = c.makeOffer(playerId: target.id, fee: ask, wage: wage) else { return XCTFail("at asking price") }
        XCTAssertEqual(c.bank(me), bankBefore - ask)
        XCTAssertEqual(c.bank(seller.id), sellerBefore + ask)
        XCTAssertFalse(c.club(seller.id)!.squad.contains(target.id))
        // Three strikes per player per window.
        let other = c.squad(seller.id).first { $0.id != target.id && !$0.overseas }!
        for _ in 0..<3 { _ = c.makeOffer(playerId: other.id, fee: 0, wage: c.tuning.minWage) }
        XCTAssertTrue(c.makeOffer(playerId: other.id, fee: c.askingPrice(other), wage: c.wageDemand(other)).message.contains("stopped"))

        // Release costs half the wage.
        let leaving = c.squad(me).min { $0.rating < $1.rating }!
        let bank = c.bank(me)
        XCTAssertTrue(c.release(leaving.id))
        XCTAssertEqual(c.bank(me), bank - Int(Double(leaving.contract!.wage) * 0.5))
        XCTAssertNil(c.players[leaving.id]?.clubId)

        // Listing a player brings AI bids; accepting one moves him.
        let star = c.squad(me).max { $0.rating < $1.rating }!
        for _ in 0..<5 where c.market.offers.isEmpty { c.listForTransfer(star.id, asking: star.value(in: c.year)) }
        if let offer = c.market.offers.first(where: { $0.playerId == star.id }) {
            XCTAssertTrue(c.acceptOffer(offer.id))
            XCTAssertEqual(c.players[star.id]?.clubId, offer.fromClub)
        }
        assertLegalSquads(c)

        // The window shuts after round 2.
        while let f = c.nextFixture, (c.round(of: f) ?? 0) <= 2 { c.play(fixtureId: f.id) }
        XCTAssertFalse(c.windowOpen)
        XCTAssertTrue(c.makeOffer(playerId: other.id, fee: 0, wage: 100).message.contains("closed"))
        // It reopens before round 25 with AI business done.
        while let f = c.nextFixture, (c.round(of: f) ?? 0) < 25 {
            if c.pendingWindow != nil { c.simWindow(stopAtUser: false) } else { c.play(fixtureId: f.id) }
        }
        XCTAssertTrue(c.windowOpen)
        XCTAssertTrue(c.market.aiWindowsDone.contains("2027-mid"))
    }
}
