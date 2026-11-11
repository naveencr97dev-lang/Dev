import XCTest
@testable import AuctionEngine

/// Career › Squad building for the home pitch.
extension CareerTests {
    private func xi(team: Int, bowlType: BowlType, country: String, batTraits: [Trait], bowlTraits: [Trait]) -> [Player] {
        (0..<11).map { i in
            let bowler = i >= 6
            return Player(id: "t\(team)p\(i)", name: "P\(i)", role: i == 0 ? .WK : (bowler ? .BOWL : .BAT), overseas: false,
                          country: country, base: 20, pool: "Stars", rating: 76, bat: bowler ? 25 : 76, bowl: bowler ? 76 : 10,
                          line: "", bowlType: bowlType, traits: i % 2 == 0 ? (bowler ? bowlTraits : batTraits) : [],
                          slot: bowler ? .lower : (i < 2 ? .open : (i < 4 ? .top : .middle)), legend: false)
        }
    }

    /// Layer 0: conditions swing results. Two XIs with the same ratings; one is built for the pitch.
    func testPitchBuiltXIBeatsAnEqualRatedOneAtHome() {
        let cases: [(Pitch, BowlType, String, [Trait], [Trait])] = [
            (.dustyTurner, .spin, "IND", [.technician], [.turnerTerror]),
            (.englishSeam, .pace, "ENG", [.technician], [.newBallSwing]),
            (.aussieBounce, .pace, "AUS", [.flatTrackBully], [.bounceMerchant]),
            (.caribbeanSlow, .spin, "WI", [], [.turnerTerror]),
        ]
        for (pitch, type, country, batTraits, bowlTraits) in cases {
            let built = xi(team: 0, bowlType: type, country: country, batTraits: batTraits, bowlTraits: bowlTraits)
            let generic = xi(team: 1, bowlType: type == .spin ? .pace : .spin, country: "ZIM", batTraits: [], bowlTraits: [])
            XCTAssertEqual(built.map(\.bat), generic.map(\.bat))
            XCTAssertEqual(built.map(\.bowl), generic.map(\.bowl))
            var wins = 0
            let games = 200
            for g in 0..<games {
                var engine = MatchEngine(rng: SeededRNG(seed: UInt64(5000 + g)))
                var log: [BallEvent] = []
                let a = MatchEngine.Side(teamId: 0, xi: built), b = MatchEngine.Side(teamId: 1, xi: generic)
                let r = g % 2 == 0 ? engine.play(a, b, stage: .league, pitch: pitch, log: &log)
                    : engine.play(b, a, stage: .league, pitch: pitch, log: &log)
                if r.winnerId == 0 { wins += 1 }
            }
            if ProcessInfo.processInfo.environment["CAREER_VERBOSE"] == "1" { print("pitch-built XI on \(pitch): \(wins)/\(games)") }
            XCTAssertGreaterThanOrEqual(wins, games * 65 / 100, "\(pitch): the pitch-built XI won \(wins)/\(games)")
        }
    }

    func testPitchFitFollowsTheEngine() {
        func make(_ role: Role, _ type: BowlType, _ country: String, _ traits: [Trait]) -> CareerPlayer {
            var rng = SeededRNG(seed: 1)
            let attr = Attributes.seeded(bat: role == .BOWL ? 25 : 75, bowl: role == .BAT ? 10 : 75, keeper: false, traits: traits, rng: &rng)
            return CareerPlayer(id: "x", name: "X", country: country, role: role, bowlType: type, slot: .middle, traits: traits,
                                born: 2000, attr: attr, potential: 80, legend: false, generated: true, line: "", clubId: nil)
        }
        let spinner = make(.BOWL, .spin, "AUS", []), quick = make(.BOWL, .pace, "AUS", [])
        XCTAssertGreaterThan(Pitch.dustyTurner.fit(spinner), Pitch.dustyTurner.fit(quick))
        XCTAssertGreaterThan(Pitch.englishSeam.fit(quick), Pitch.englishSeam.fit(spinner))
        XCTAssertEqual(Pitch.dustyTurner.fit(spinner), Pitch.dustyTurner.spinBonus)
        let bully = make(.BAT, .pace, "ZIM", [.flatTrackBully])
        XCTAssertGreaterThanOrEqual(Pitch.indianFlat.fit(bully), PitchFit.suits)
        XCTAssertLessThan(Pitch.dustyTurner.fit(bully), 0)
        XCTAssertEqual(Pitch.indianFlat.fit(make(.BAT, .pace, "ZIM", [])), 0, "a neutral batter is neutral")
    }

    /// AI clubs build for their ground: more spin on turning pitches, more pace on quick ones, and
    /// every squad suits its own pitch better than the other clubs' squads would.
    func testClubsBuildSquadsForTheirHomePitch() {
        var spinAtSpinGrounds = 0.0, spinAtPaceGrounds = 0.0, own = 0.0, others = 0.0
        let seeds: [UInt64] = [901, 902, 903, 904]
        for seed in seeds {
            let c = newCareer(seed: seed)
            func spinShare(_ id: Int) -> Double {
                let bowlers = c.squad(id).filter { $0.role == .BOWL || $0.role == .AR }
                return Double(bowlers.filter { $0.bowlType == .spin }.count) / Double(max(1, bowlers.count))
            }
            func avg(_ xs: [Double]) -> Double { xs.reduce(0, +) / Double(max(1, xs.count)) }
            let spinGrounds = c.clubs.map(\.id).filter { [.dustyTurner, .caribbeanSlow].contains(c.homePitch($0)) }
            let paceGrounds = c.clubs.map(\.id).filter { [.englishSeam, .aussieBounce].contains(c.homePitch($0)) }
            spinAtSpinGrounds += avg(spinGrounds.map(spinShare))
            spinAtPaceGrounds += avg(paceGrounds.map(spinShare))
            for club in c.clubs {
                let squad = c.squad(club.id)
                own += avg(squad.map { Double(c.homeFit($0, clubId: club.id)) })
                others += avg(c.clubs.filter { $0.id != club.id }.map { o in avg(squad.map { Double(c.homeFit($0, clubId: o.id)) }) })
            }
        }
        let n = Double(seeds.count)
        if ProcessInfo.processInfo.environment["CAREER_VERBOSE"] == "1" { print("spin share: turning \(spinAtSpinGrounds / n), pace \(spinAtPaceGrounds / n); fit own \(own / n / 10), others \(others / n / 10)") }
        XCTAssertGreaterThan(spinAtSpinGrounds / n, spinAtPaceGrounds / n + 0.08,
                             "spin share: turning grounds \(spinAtSpinGrounds / n), pace grounds \(spinAtPaceGrounds / n)")
        XCTAssertGreaterThan(own, others + 5 * n, "squads fit their own pitch (\(own)) better than the others' (\(others))")
    }

    func testAIClubsPayMoreForPlayersWhoSuitTheirPitch() {
        let c = newCareer(seed: 905)
        let turner = c.clubs.first { c.homePitch($0.id) == .dustyTurner }!.id
        let seamer = c.clubs.first { c.homePitch($0.id) == .englishSeam }!.id
        let spinner = c.players.values.sorted { $0.id < $1.id }.first { $0.role == .BOWL && $0.bowlType == .spin }!
        XCTAssertGreaterThan(c.pitchValueFactor(spinner, clubId: turner), 1.15)
        XCTAssertGreaterThan(c.seasonFit(spinner, clubId: turner), c.seasonFit(spinner, clubId: seamer) + 5)
        XCTAssertGreaterThan(c.seasonFit(spinner, clubId: seamer), Double(c.homeFit(spinner, clubId: seamer)),
                             "a spinner is worth more to a pace-ground club over the season than at home alone")
        XCTAssertGreaterThan(c.pitchRating(spinner, clubId: turner), c.pitchRating(spinner, clubId: seamer))
    }

    /// The XI is picked for the day's pitch: on a turner the spinners play.
    func testAutoXIPicksForThePitch() {
        var spinXI = 0, paceXI = 0
        for seed in [906, 907, 908] as [UInt64] {
            let c = newCareer(seed: seed)
            let squad = c.squad(c.userClubId).compactMap { c.player($0.id) }
            let byId = Dictionary(uniqueKeysWithValues: squad.map { ($0.id, $0) })
            func spinners(_ pitch: Pitch) -> Int {
                let ids = TeamSelector.autoXI(squad: squad, rules: c.rules, pitch: pitch)
                XCTAssertTrue(TeamSelector.blockingIssues(ids.compactMap { byId[$0] }, rules: c.rules).isEmpty)
                return ids.compactMap { byId[$0] }.filter { $0.isBowlingOption && $0.bowlType == .spin }.count
            }
            spinXI += spinners(.dustyTurner)
            paceXI += spinners(.englishSeam)
        }
        XCTAssertGreaterThan(spinXI, paceXI, "spinners picked on a turner \(spinXI), on a seamer \(paceXI)")
    }

    /// Home advantage is real: across a league season, home sides win more than half.
    func testHomeSidesWinMoreThanHalf() {
        var home = 0, games = 0
        for seed in (ProcessInfo.processInfo.environment["HOME_SEEDS"].flatMap { Int($0) }.map { n in (0..<n).map { UInt64(911 + $0) } } ?? [911, 912, 913, 914, 915]) {
            var c = newCareer(seed: seed)
            c.simToSeasonEnd()
            for r in c.results where r.stage == .league {
                games += 1
                if r.winnerId == r.teamA { home += 1 }
            }
        }
        if ProcessInfo.processInfo.environment["CAREER_VERBOSE"] == "1" { print("home wins \(home)/\(games)") }
        XCTAssertGreaterThan(games, 800)
        XCTAssertGreaterThan(Double(home) / Double(games), 0.51, "home wins \(home)/\(games)")
    }
}
