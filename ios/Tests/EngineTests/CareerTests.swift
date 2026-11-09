import XCTest
@testable import AuctionEngine

final class CareerTests: XCTestCase {
    static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources")

    static let born: [String: Int] = {
        let data = try! Data(contentsOf: resources.appendingPathComponent("career_meta.json"))
        let meta = try! JSONDecoder().decode([String: [String: Int]].self, from: data)
        return meta.compactMapValues { $0["born"] }
    }()

    func newCareer(seed: UInt64 = 7, club: Int = 0, legends: Bool = false) -> Career {
        Career.new(managerName: "Test", clubIndex: club, seed: seed, year: 2027, curated: EngineTests.players,
                   born: Self.born, flags: CareerFlags(legendsEra: legends))
    }

    func assertLegalSquads(_ c: Career, file: StaticString = #filePath, line: UInt = #line) {
        var seen = Set<String>()
        for club in c.clubs {
            let squad = c.squad(club.id)
            XCTAssertGreaterThanOrEqual(squad.count, c.tuning.minSquad, "\(club.short) squad too small", file: file, line: line)
            XCTAssertLessThanOrEqual(squad.count, c.tuning.maxSquad, file: file, line: line)
            XCTAssertLessThanOrEqual(squad.filter(\.overseas).count, c.tuning.maxOverseasSquad, "\(club.short) overseas", file: file, line: line)
            XCTAssertTrue(squad.allSatisfy { $0.clubId == club.id && !$0.retired }, file: file, line: line)
            XCTAssertTrue(c.xiIssues(club.id).isEmpty, "\(club.short) XI: \(c.xiIssues(club.id))", file: file, line: line)
            // Minimum-wage signings needed to reach 18 players are exempt from the cap (the board tops
            // squads up even when the cap is full), so each minimum-wage contract counts as exempt.
            let exempt = squad.filter { ($0.contract?.wage ?? 0) <= c.tuning.minWage }.count * c.tuning.minWage
            XCTAssertLessThanOrEqual(c.payroll(club.id), c.tuning.salaryCap + exempt, "\(club.short) over the cap", file: file, line: line)
            XCTAssertTrue(squad.allSatisfy { $0.contract != nil }, "\(club.short) uncontracted player", file: file, line: line)
            for id in club.squad {
                XCTAssertFalse(seen.contains(id), "\(id) in two squads", file: file, line: line)
                seen.insert(id)
            }
        }
    }

    func testMetadataCoversEveryPlayer() {
        for p in EngineTests.players { XCTAssertNotNil(Self.born[p.id], p.id) }
    }

    func testTuningFileMatchesDefaults() throws {
        let data = try Data(contentsOf: Self.resources.appendingPathComponent("career_tuning.json"))
        XCTAssertEqual(try JSONDecoder().decode(CareerTuning.self, from: data), CareerTuning.standard,
                       "career_tuning.json is out of date: run CareerTests.testWriteTuningFile")
    }

    /// Regenerates Resources/career_tuning.json from the defaults (run when tuning defaults change).
    func testWriteTuningFile() throws {
        guard ProcessInfo.processInfo.environment["WRITE_TUNING"] == "1" else { return }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(CareerTuning.standard).write(to: Self.resources.appendingPathComponent("career_tuning.json"))
    }

    func testSeededAttributesMatchRatings() {
        var rng = SeededRNG(seed: 3)
        for p in EngineTests.players {
            let a = Attributes.seeded(bat: p.bat, bowl: p.bowl, keeper: p.role == .WK, traits: p.traits, rng: &rng)
            XCTAssertLessThanOrEqual(abs(a.bat - p.bat), 2, p.name)
            XCTAssertLessThanOrEqual(abs(a.bowl - p.bowl), 2, p.name)
        }
    }

    func testNewCareer() {
        let c = newCareer()
        XCTAssertEqual(c.clubs.count, 10)
        XCTAssertEqual(c.clubs.filter { !$0.isCPU }.map(\.id), [0])
        for club in c.clubs { XCTAssertEqual(club.squad.count, c.tuning.startSquad, club.short) }
        assertLegalSquads(c)
        XCTAssertFalse(c.players.values.contains { $0.legend }, "no legends in a normal start")
        XCTAssertTrue(newCareer(legends: true).players.values.contains { $0.legend })
        // Squads are balanced: strongest and weakest XI within a few points.
        let s = c.clubs.map { c.strength($0.id) }
        XCTAssertLessThanOrEqual(s.max()! - s.min()!, 6, "draft balance \(s)")
        // Every club has keepers and enough bowlers.
        for club in c.clubs {
            let squad = c.squad(club.id)
            XCTAssertGreaterThanOrEqual(squad.filter { $0.role == .WK }.count, 1, club.short)
            XCTAssertGreaterThanOrEqual(squad.filter { $0.bowl >= 40 }.count, 6, club.short)
        }
    }

    func testScheduleIsIPLExtended() {
        let c = newCareer()
        let league = c.leagueFixtures
        XCTAssertEqual(league.count, 180)
        for club in c.clubs {
            XCTAssertEqual(league.filter { $0.involves(club.id) }.count, 36, "36 league matches each")
            XCTAssertEqual(league.filter { $0.home == club.id }.count, 18, "half at home")
        }
        for a in 0..<10 {
            for b in (a + 1)..<10 {
                let games = league.filter { $0.involves(a) && $0.involves(b) }
                XCTAssertEqual(games.count, 4)
                XCTAssertEqual(games.filter { $0.home == a }.count, 2)
            }
        }
        // Nobody plays twice on one day; home pitch is used.
        var byDay: [Int: [Fixture]] = [:]
        for f in league { byDay[c.day(of: f), default: []].append(f) }
        XCTAssertEqual(byDay.count, 36, "36 rounds")
        for (_, fs) in byDay {
            let teams = fs.flatMap { [$0.home, $0.away] }
            XCTAssertEqual(Set(teams).count, teams.count)
        }
        for f in league { XCTAssertEqual(f.pitch, c.info(f.home)?.homePitch) }
        // Rounds avoid the April and August international windows.
        for f in league {
            let month = CareerCalendar.monthDay(c.day(of: f)).month
            XCTAssertFalse([3, 7].contains(month), "league match in an international window")
        }
    }

    func testSeasonPlaysThroughToChampionAndNextSeason() {
        var c = newCareer(seed: 11)
        let simmed = c.simUntilUserMatch()
        XCTAssertTrue(c.nextFixture.map(c.isUserFixture) ?? false)
        XCTAssertLessThan(simmed, 5)
        c.simToSeasonEnd()
        XCTAssertEqual(c.phase, .seasonEnd)
        XCTAssertNotNil(c.championId)
        XCTAssertEqual(c.results.count, 184, "180 league + 4 playoffs")
        XCTAssertEqual(c.history.count, 1)
        XCTAssertNotNil(c.history[0].orangeCap)
        XCTAssertFalse(c.userFinish().isEmpty)
        XCTAssertNil(c.play(fixtureId: 1), "no matches after the season")
        let champ = c.championId!
        XCTAssertEqual(c.info(champ)?.titles, 1)
        // Biggest save: a full season of results before rollover.
        let fullSave = try! CareerSave.encode(c)
        print("Save size at season end: \(fullSave.count / 1024) KB")
        XCTAssertLessThan(fullSave.count, 5_000_000)
        // Form moves during a season.
        XCTAssertTrue(c.players.values.contains { $0.form != 0 })
        // Career stats were recorded.
        let totalRuns = c.players.values.map(\.stats.runs).reduce(0, +)
        XCTAssertGreaterThan(totalRuns, 184 * 250, "about 140+ a side")

        let report = c.startNextSeason()
        XCTAssertEqual(c.year, 2028)
        XCTAssertEqual(c.phase, .season)
        XCTAssertEqual(c.results.count, 0)
        XCTAssertEqual(c.leagueFixtures.count, 180)
        XCTAssertGreaterThan(report.youth, 0)
        XCTAssertTrue(c.players.values.allSatisfy { $0.form == 0 })
        assertLegalSquads(c)
    }

    func testDeterministic() {
        var a = newCareer(seed: 99), b = newCareer(seed: 99)
        a.simToSeasonEnd(); b.simToSeasonEnd()
        XCTAssertEqual(a.championId, b.championId)
        XCTAssertEqual(a.results.map(\.id), b.results.map(\.id))
        a.startNextSeason(); b.startNextSeason()
        XCTAssertEqual(a.players.keys.sorted(), b.players.keys.sorted())
        XCTAssertEqual(a.clubs.map(\.squad), b.clubs.map(\.squad))
    }

    func testSaveRoundTripAndVersioning() throws {
        var c = newCareer(seed: 5)
        c.simUntilUserMatch()
        if let f = c.nextUserFixture { c.play(fixtureId: f.id) }
        let data = try CareerSave.encode(c)
        let back = try CareerSave.decode(data)
        XCTAssertEqual(back.results.map(\.id), c.results.map(\.id))
        XCTAssertEqual(back.players, c.players)
        XCTAssertEqual(back.fixtureDays, c.fixtureDays)
        XCTAssertEqual(back.rng, c.rng)
        // A save from a newer app version is refused, not misread.
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json["schemaVersion"] = Career.currentSchema + 1
        XCTAssertThrowsError(try CareerSave.decode(JSONSerialization.data(withJSONObject: json)))
        XCTAssertLessThan(data.count, 5_000_000, "save size")
    }

    func testUserXIIsRespectedAndRepairedWhenInvalid() {
        var c = newCareer(seed: 2)
        let squad = c.userClub.squad
        // A legal custom XI is kept.
        let auto = c.userClub.xi
        var custom = auto
        if let bench = squad.first(where: { !auto.contains($0) && !(c.players[$0]?.overseas ?? true) }),
           let swapOut = auto.first(where: { !(c.players[$0]?.overseas ?? true) && c.players[$0]?.role != .WK }) {
            custom[custom.firstIndex(of: swapOut)!] = bench
        }
        c.setXI(clubId: c.userClubId, ids: custom)
        XCTAssertTrue(c.xiIssues(c.userClubId).isEmpty)
        let side = c.side(c.userClubId)
        XCTAssertEqual(side.xi.map(\.id), custom)
        // An illegal XI (10 players) falls back to the auto pick.
        c.setXI(clubId: c.userClubId, ids: Array(custom.prefix(10)))
        XCTAssertFalse(c.xiIssues(c.userClubId).isEmpty)
        XCTAssertEqual(c.side(c.userClubId).xi.count, 11)
    }

    /// Headless balance harness (ROADMAP balance targets). 8 seasons keeps the debug test quick;
    /// set CAREER_SEASONS=20 for the full check.
    func testMultiSeasonBalance() {
        let seasons = Int(ProcessInfo.processInfo.environment["CAREER_SEASONS"] ?? "") ?? 8
        var c = newCareer(seed: 2027)
        let startPopulation = c.players.values.filter { !$0.retired }.count
        var champions: [Int] = []
        var firstInnings: [Pitch: [Int]] = [:]
        let start = Date()
        for _ in 0..<seasons {
            c.simToSeasonEnd()
            for r in c.results where r.stage == .league { firstInnings[r.pitch, default: []].append(r.innings[0].runs) }
            if ProcessInfo.processInfo.environment["CAREER_VERBOSE"] == "1" {
                let flat = c.results.filter { $0.pitch == .indianFlat && $0.stage == .league }.map { $0.innings[0].runs }
                let seam = c.results.filter { $0.pitch == .englishSeam && $0.stage == .league }.map { $0.innings[0].runs }
                let xis = c.clubs.map { c.side($0.id).xi }
                let bat7 = xis.flatMap { $0.prefix(7).map(\.bat) }
                let bowl5 = xis.flatMap { MatchEngine.autoAttack($0, pitch: nil).map(\.bowl) }
                print("  banks \(c.clubs.map { c.bank($0.id) / 100 }) Cr, payroll \(c.clubs.map { c.payroll($0.id) / 100 }) Cr")
                print("  \(c.year): flat \(flat.reduce(0, +) / max(1, flat.count)) seam \(seam.reduce(0, +) / max(1, seam.count)) top7 bat \(bat7.reduce(0, +) / bat7.count) attack \(bowl5.reduce(0, +) / bowl5.count) str \(c.clubs.map { c.strength($0.id) })")
            }
            champions.append(c.championId!)
            c.startNextSeason()
            assertLegalSquads(c)
        }
        let perSeason = Date().timeIntervalSince(start) / Double(seasons)
        print("Career balance: \(seasons) seasons, \(String(format: "%.2f", perSeason)) s/season (debug), champions \(champions)")
        for (p, runs) in firstInnings.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            print("  \(p.rawValue): avg 1st innings \(runs.reduce(0, +) / runs.count)")
        }
        XCTAssertGreaterThanOrEqual(Set(champions).count, seasons >= 20 ? 6 : 3, "titles spread around")
        let maxTitles = Dictionary(grouping: champions, by: { $0 }).values.map(\.count).max() ?? 0
        // Dynasty check needs a real sample (8 seasons is noise): CAREER_SEASONS=20 enforces it.
        if seasons >= 20 { XCTAssertLessThanOrEqual(Double(maxTitles), Double(seasons) * 0.4, "no runaway dynasty") }
        let population = c.players.values.filter { !$0.retired }.count
        XCTAssertGreaterThan(population, startPopulation * 7 / 10, "player pool doesn't collapse")
        XCTAssertLessThan(population, startPopulation * 15 / 10, "player pool doesn't explode")
        // Quality doesn't drain away: the best XIs stay strong.
        let strengths = c.clubs.map { c.strength($0.id) }
        XCTAssertGreaterThan(strengths.max()!, 60, "\(strengths)")
        let save = try! CareerSave.encode(c)
        XCTAssertLessThan(save.count, 5_000_000)
        print("  save size after \(seasons) seasons: \(save.count / 1024) KB, pool \(population)")
    }

    func testDevelopmentCurve() {
        var rng = SeededRNG(seed: 1)
        let t = CareerTuning.standard
        // A potential-85 18-year-old rated 60 grows into the mid-70s+ by 24.
        var p = PlayerGen.make(id: "x", role: .BAT, nation: "IND", born: 2009, rating: 60, potential: 85,
                               taken: [], rng: &rng)
        for year in 2027...2033 {
            let gain = min(Int.random(in: t.growthRange(age: p.age(in: year)), using: &rng), max(0, p.potential - p.bat))
            p.attr.shift(Attributes.batKeys, by: gain)
        }
        XCTAssertGreaterThanOrEqual(p.bat, 72)
        XCTAssertLessThanOrEqual(p.bat, 86)
    }

    func testTakeChargeAndHubHelpers() {
        var c = newCareer(seed: 4, club: 0)
        let strengths = c.clubs.map { c.strength($0.id) }
        c.takeCharge(clubId: 6, managerName: "Naveen")
        XCTAssertEqual(c.userClubId, 6)
        XCTAssertEqual(c.clubs.filter { !$0.isCPU }.map(\.id), [6])
        XCTAssertEqual(c.clubs.map { c.strength($0.id) }, strengths, "squads unchanged")
        XCTAssertLessThanOrEqual(c.news.count, 2, "the takeover, plus the retirement watch if anyone is close")
        XCTAssertTrue(c.news[0].text.contains("Naveen"))
        XCTAssertEqual(c.userFixtures.count, 36)
        XCTAssertEqual(c.totalRounds, 36)
        XCTAssertEqual(c.round(of: c.leagueFixtures[0]), 1)
        XCTAssertEqual(c.round(of: c.leagueFixtures[179]), 36)
        XCTAssertTrue(c.userForm().isEmpty)
        c.simUntilUserMatch()
        c.play(fixtureId: c.nextUserFixture!.id)
        XCTAssertEqual(c.userForm().count, 1)
        XCTAssertTrue((1...10).contains(c.position(of: 6)))
        XCTAssertTrue(c.news.contains { $0.kind == .result })
    }

    func testCalendarLabels() {
        XCTAssertEqual(CareerCalendar.label(1), "1 Jan")
        XCTAssertEqual(CareerCalendar.label(60), "1 Mar")
        XCTAssertEqual(CareerCalendar.label(365), "31 Dec")
        XCTAssertEqual(Career.ordinal(1), "1st")
        XCTAssertEqual(Career.ordinal(2), "2nd")
        XCTAssertEqual(Career.ordinal(3), "3rd")
        XCTAssertEqual(Career.ordinal(11), "11th")
        XCTAssertEqual(Career.ordinal(10), "10th")
    }
}
