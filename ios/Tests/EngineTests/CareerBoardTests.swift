import XCTest
@testable import AuctionEngine

/// Career › Club › Board (objectives, monthly awards) and the panel-driven market changes.
extension CareerTests {
    func testObjectivesAreSetAndJudged() {
        var c = newCareer(seed: 301)
        XCTAssertEqual(c.board.year, c.year)
        XCTAssertEqual(Array(c.board.objectives.map(\.kind).prefix(2)), [.finish, .homeWins])
        XCTAssertTrue([.youth, .awayWins].contains(c.board.objectives[2].kind))
        XCTAssertTrue(c.board.objectives.allSatisfy { $0.met == nil && $0.target > 0 })
        let (gold, confidence) = (c.gold, c.board.confidence)
        c.simToSeasonEnd()
        XCTAssertEqual(c.phase, .seasonEnd)
        XCTAssertTrue(c.board.objectives.allSatisfy { $0.met != nil }, "judged at the final")
        let met = c.board.objectives.filter { $0.met == true }
        XCTAssertGreaterThanOrEqual(c.gold, gold + met.map(\.gold).reduce(0, +))
        XCTAssertNotEqual(c.board.confidence, confidence)
        XCTAssertTrue(c.news.contains { $0.text.hasPrefix("Board review") })
        // Next season: new objectives.
        c.startNextSeason()
        XCTAssertEqual(c.board.year, c.year)
        XCTAssertTrue(c.board.objectives.allSatisfy { $0.met == nil })
    }

    func testMonthlyAwardsEveryLeagueMonth() {
        var c = newCareer(seed: 302)
        c.simToSeasonEnd()
        let leagueMonths = Set(c.leagueFixtures.map { CareerCalendar.monthDay(c.day(of: $0)).month })
        let awarded = Set(c.board.awards.filter { $0.year == c.year }.map(\.month))
        XCTAssertEqual(awarded, leagueMonths, "one award per month with league cricket")
        XCTAssertTrue(c.board.awards.allSatisfy { !$0.line.isEmpty && c.club($0.managerClub) != nil })
    }

    func testAITransfersSpendSurplusAndKeepSquadsLegal() {
        var c = newCareer(seed: 303)
        for ci in c.clubs.indices where c.clubs[ci].isCPU { c.finance[c.clubs[ci].id].bank = 8_000 }
        let before = c.clubs.filter(\.isCPU).map { c.bank($0.id) }.reduce(0, +)
        c.aiTransfers()
        let after = c.clubs.filter(\.isCPU).map { c.bank($0.id) }.reduce(0, +)
        // Fees move between AI clubs (the total is conserved), and some deals happen.
        XCTAssertEqual(before, after)
        XCTAssertTrue(c.news.contains { $0.text.hasPrefix("✍️") }, "rich AI clubs buy")
        XCTAssertTrue(c.squad(c.userClubId).allSatisfy { $0.clubId == c.userClubId }, "the user's players are never taken")
        for club in c.clubs { XCTAssertGreaterThanOrEqual(club.squad.count, c.tuning.minSquad) }
    }

    func testPitchCalibrationOnlyInCareer() {
        let c = newCareer(seed: 304)
        let id = c.userClub.xi[0]
        let flat = c.enginePlayer(id, pitch: .indianFlat)!.bat
        let seam = c.enginePlayer(id, pitch: .englishSeam)!.bat
        XCTAssertEqual(seam - flat, min(c.tuning.pitchBatBoost[1], 99 - flat))
    }

    func testScoutAdviceFlagsUpgrades() {
        let c = newCareer(seed: 305)
        let xi = c.userClub.xi.compactMap { c.players[$0] }
        let weakest = xi.min { $0.rating < $1.rating }!
        var star = weakest
        star.clubId = nil
        for k in [\Attributes.technique, \.power, \.vsPace, \.vsSpin, \.temperament,
                  \.accuracy, \.potency, \.variation, \.death, \.newBall] { star.attr[keyPath: k] = 99 }
        XCTAssertTrue(c.scoutAdvice(star).good, c.scoutAdvice(star).text)
    }

    func testMigrationFromSchema9() throws {
        let c = newCareer(seed: 306)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 9
        json["board"] = nil
        var t = json["tuning"] as! [String: Any]
        t["pitchBatBoost"] = nil; t["aiReserveBank"] = nil; t["aiDealsPerWindow"] = nil; t["aiUpgradeMargin"] = nil
        json["tuning"] = t
        let back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.board, BoardState())
        XCTAssertEqual(back.tuning.pitchBatBoost, CareerTuning.standard.pitchBatBoost)
    }
}

/// Panel rounds 2-3: the XI repair, the assistant, Right to Match, objectives that fit the squad.
extension CareerTests {
    func testPatchXIKeepsBattersUpTheOrder() {
        var c = newCareer(seed: 401)
        // Two top-order batters leave: the patched XI must still be valid and nobody exposed.
        let ci = c.userClubIndex
        let gone = Array(c.clubs[ci].xi.prefix(2))
        c.clubs[ci].squad.removeAll { gone.contains($0) }
        for id in gone { c.players[id]?.clubId = nil }
        c.patchXI(clubId: c.userClubId)
        let xi = c.userClub.xi.compactMap { c.player($0) }
        XCTAssertEqual(xi.count, 11)
        XCTAssertTrue(c.xiIssues(c.userClubId).isEmpty, "\(c.xiIssues(c.userClubId))")
        XCTAssertFalse(xi.indices.contains { xi[$0].isExposed(atPosition: $0) }, "a tail-ender in the top six")
    }

    func testAssistantExplainsALosingRun() throws {
        var c = newCareer(seed: 402)
        XCTAssertNil(c.assistantReport())
        var guardCount = 0
        while c.losingRun < 3 && c.phase == .season && guardCount < 400 {
            guardCount += 1
            c.simUntilUserMatch()
            if let f = c.nextUserFixture { c.play(fixtureId: f.id) } else { break }
        }
        guard c.losingRun >= 3 else { return }   // never lost three straight with this seed
        let report = try XCTUnwrap(c.assistantReport())
        XCTAssertTrue(report.diagnosis.hasPrefix("\(c.losingRun) defeats in a row"))
        XCTAssertFalse(report.advice.isEmpty)
        XCTAssertTrue(c.news.contains { $0.text.hasPrefix("📋 Assistant") })
    }

    func testRightToMatchKeepsAFormerPlayer() {
        var c = newCareer(seed: 403)
        // Play to the first mega auction (every 3rd season).
        while !(c.phase == .offseason && c.offseason?.mega == true) {
            c.simToSeasonEnd()
            c.beginOffseason()
            if c.offseason?.mega != true { c.startSeasonFromOffseason() }
        }
        c.confirmRetention(userKeeps: Array(c.suggestedRetentions().prefix(2)))
        XCTAssertEqual(c.offseason?.rtmLeft, c.tuning.maxRetentions - 2)
        XCTAssertFalse(c.offseason?.released?.isEmpty ?? true)
        var used = false
        var guardCount = 0
        while c.offseason?.stage == .auction && guardCount < 600 {
            guardCount += 1
            if c.canUseRTM, let id = c.offseason?.auction.currentId, let price = c.rtmPrice {
                let sale = c.useRTM()
                XCTAssertEqual(sale?.clubId, c.userClubId)
                XCTAssertEqual(sale?.price, price)
                XCTAssertEqual(c.players[id]?.clubId, c.userClubId)
                used = true
                break
            }
            c.passLot()
        }
        XCTAssertTrue(used, "an AI club wanted one of the released players")
        XCTAssertEqual(c.offseason?.rtmLeft, c.tuning.maxRetentions - 3)
    }

    func testObjectivesFitTheSquad() {
        var c = newCareer(seed: 404)
        // Nobody under 24 in the squad.
        let ci = c.userClubIndex
        for p in c.squad(c.userClubId) where p.age(in: c.year) <= 23 {
            c.clubs[ci].squad.removeAll { $0 == p.id }
            c.clubs[ci].xi.removeAll { $0 == p.id }
            c.players[p.id]?.clubId = nil
        }
        c.setObjectives()
        XCTAssertFalse(c.board.objectives.contains { $0.kind == .youth })
        XCTAssertTrue(c.board.objectives.contains { $0.kind == .awayWins })
        c.finance[c.userClubId].bank = c.tuning.investObjectiveBank
        c.setObjectives()
        XCTAssertTrue(c.board.objectives.contains { $0.kind == .invest })
    }

    func testScoutAdviceKnowsSlotsAndMoney() {
        var c = newCareer(seed: 405)
        let foreign = c.players.values.filter { $0.overseas && $0.clubId != c.userClubId && !$0.retired }
            .sorted { $0.rating > $1.rating }.first!
        // Fill the overseas slots.
        var extra = c.players.values.filter { $0.overseas && $0.clubId == nil && !$0.retired }.sorted { $0.id < $1.id }.makeIterator()
        while c.squad(c.userClubId).filter(\.overseas).count < c.tuning.maxOverseasSquad,
              c.squad(c.userClubId).count < c.tuning.maxSquad, let p = extra.next() {
            c.sign(p.id, to: c.userClubIndex, wage: c.tuning.minWage)
        }
        if c.squad(c.userClubId).filter(\.overseas).count >= c.tuning.maxOverseasSquad {
            XCTAssertFalse(c.scoutAdvice(foreign).good)
        }
        let local = c.players.values.filter { !$0.overseas && $0.clubId != nil && $0.clubId != c.userClubId }.first!
        XCTAssertFalse(c.scoutAdvice(local, fee: c.bank(c.userClubId) + 1).good, "can't afford")
    }

    func testRealisticChaseIsCareerOnly() {
        XCTAssertFalse(MatchEngine(rng: SeededRNG(seed: 1)).realisticChase, "the quick game keeps its engine")
    }

    func testMigrationFromSchema10() throws {
        let c = newCareer(seed: 406)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 10
        var board = json["board"] as! [String: Any]; board["upgradesStarted"] = nil; json["board"] = board
        var t = json["tuning"] as! [String: Any]; t["investObjectiveBank"] = nil; json["tuning"] = t
        var st = json["settings"] as! [String: Any]; st["assistantPicksXI"] = nil; json["settings"] = st
        let back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.board.upgradesStarted, 0)
        XCTAssertFalse(back.settings.assistantPicksXI, "existing careers keep picking their own XI")
        XCTAssertTrue(c.settings.assistantPicksXI, "new careers start with the assistant on")
    }

    func testMigrationFromSchema11() throws {
        let c = newCareer(seed: 407)
        var json = try JSONSerialization.jsonObject(with: CareerSave.encode(c)) as! [String: Any]
        json["schemaVersion"] = 11
        var players = json["players"] as! [String: Any]
        for (k, v) in players {
            var p = v as! [String: Any]
            p["squadRole"] = nil; p["morale"] = nil; p["rolePromised"] = nil
            players[k] = p
        }
        json["players"] = players
        var back = try CareerSave.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(back.players.values.first { $0.clubId == back.userClubId }?.squadRole)
        back.assignDefaultRoles()   // the store does this on load
        XCTAssertTrue(back.squad(back.userClubId).allSatisfy { $0.squadRole != nil && $0.morale != nil })
        XCTAssertEqual(back.tuning.investObjectiveBank, CareerTuning.standard.investObjectiveBank)
    }
}
