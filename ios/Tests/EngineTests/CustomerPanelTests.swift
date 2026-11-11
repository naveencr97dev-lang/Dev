import XCTest
@testable import AuctionEngine

/// Customer panel: simulated players ("personas") play full careers through the real engine, doing
/// what a person does in the app (CONTINUE, Auto-pick XI, training, the market, the auction with the
/// staff advice), and each one writes the complaints a real player would. Run it with
///
///     CUSTOMER_PANEL=1 swift test -c release -Xswiftc -enable-testing --filter CustomerPanelTests
///
/// `CUSTOMER_SEASONS` (default 4) sets the career length and `CUSTOMER_CLUBS` (default "3,8") the
/// clubs each persona manages (same seed, so differences come from how they play). The printed report
/// is the raw input for `docs/feedback/`. Without CUSTOMER_PANEL the test returns at once.
final class CustomerPanelTests: XCTestCase {

    enum Persona: String, CaseIterable {
        /// Presses CONTINUE and nothing else (casts matches, wants a story).
        case caster
        /// Training every week, perks, facilities, tactics; re-picks the XI; reacts to losing runs.
        case tinkerer
        /// Trades every week: buys upgrades, sells the bench, then re-picks the XI.
        case trader
        /// Lives for the auction: bids when the staff advice says the player helps.
        case bidder
        /// Hard-core: Legend difficulty, plays like the tinkerer.
        case veteran
        /// New to the genre: Easy, presses CONTINUE, taps Auto-pick once a season.
        case rookie

        // Panel 2, "the home crowd" (CUSTOMER_PANEL=2): what the home-pitch build feels like.
        /// Builds for the home pitch: buys and bids for players who suit it, picks the XI for the day's pitch.
        case groundsman
        /// "Ratings are ratings": best-rated XI and signings, never looks at the pitch.
        case purist
        /// Season-ticket holder: presses CONTINUE (the assistant picks), judges the club by its home record.
        case homeFan
        /// Picks an XI once a season and never touches it again.
        case setAndForget
        /// Star collector: buys the highest-rated player he can afford, whatever the role.
        case collector
        /// Youth developer: trains every week and plays the U23s.
        case developer

        var panel: Int { [.groundsman, .purist, .homeFan, .setAndForget, .collector, .developer].contains(self) ? 2 : 1 }

        var quote: String {
            switch self {
            case .caster: return "I cast matches to the TV and just want a story."
            case .tinkerer: return "I want every lever to matter."
            case .trader: return "The market is the game for me."
            case .bidder: return "The auction is why I play IPL games."
            case .veteran: return "Give me Legend and make me earn it."
            case .rookie: return "First manager game, Easy mode."
            case .groundsman: return "I build the squad for my ground."
            case .purist: return "Ratings are ratings. The pitch is noise."
            case .homeFan: return "I only care that we win at home."
            case .setAndForget: return "I pick my team in week one and leave it."
            case .collector: return "I want every star in my colours."
            case .developer: return "Give the kids a game."
            }
        }
        var difficulty: Difficulty { self == .veteran ? .legend : (self == .rookie ? .easy : .normal) }
        var managesSquad: Bool { [.tinkerer, .trader, .veteran].contains(self) }
        /// Picks the XI by hand (the assistant is off).
        var picksOwnXI: Bool { managesSquad || [.bidder, .groundsman, .purist, .setAndForget, .collector, .developer].contains(self) }
    }

    struct Report {
        var finishes: [String] = []
        var userWins = 0, userGames = 0
        var thrillers = 0, blowouts = 0, superOvers = 0
        var presses = 0, idlePresses = 0
        var longestLosingRun = 0, losingRun = 0
        var staleXIMatches = 0
        var trainingSessions = 0, emptySessions = 0
        var offerTries = 0, offerFails = 0, failReasons: [String: Int] = [:]
        var signings = 0, sold = 0
        var auctionDeltas: [Int] = []
        var lotsWon = 0
        var bank: [Int] = []
        var aiBank: [Int] = []
        var strength: [Int] = []
        var aiStrength: [Int] = []
        var aiStart: [Int] = []
        var aiSeasonEnd = 0
        var objectivesMet = 0, objectivesSet = 0
        var youthImpossible = 0
        var objectiveLog: [String] = []
        var monthAwards = 0
        var trophies = 0
        var managerLevel = 1
        var starsRetired: [String] = []
        var youthGrowth: [Int] = []
        var tacticChanges = 0
        var assistantNotes = 0, retirementWarnings = 0, rtmUsed = 0
        var formEnd = 0, coldEnd = 0
        var planFailures = 0
        // Panel 2
        var homeWins = 0, homeGames = 0, awayWins = 0, awayGames = 0
        /// Sum of the XI's average home-pitch fit at home matches, and the visitors' fit to my pitch.
        var homeFitSum = 0.0, visitorFitSum = 0.0
        var suitedSigned = 0, suitedTargetWeeks = 0, weeks = 0
        var suitedLots = 0, suitedLotsWon = 0, suitedPaid = 0, suitedValue = 0
        var kidsPlayed = 0
        var confidence = 0
        var squadSizeEnd = 0, overseasEnd = 0, benchValue = 0
    }

    func testCustomerPanel() {
        let env = ProcessInfo.processInfo.environment
        let seasons = Int(env["CUSTOMER_SEASONS"] ?? "") ?? 4
        guard env["CUSTOMER_PANEL"] == "1" else { return }
        let clubs = (env["CUSTOMER_CLUBS"] ?? "3,8").split(separator: ",").compactMap { Int($0) }
        var pars: [Pitch: [Int]] = [:]
        var allComplaints: [String: [String]] = [:]
        print("\n=== CUSTOMER PANEL: \(Persona.allCases.filter { $0.panel == 1 }.count) personas × clubs \(clubs) × \(seasons) seasons ===")
        for persona in Persona.allCases where persona.panel == 1 {
            for club in clubs {
                let (r, c) = play(persona, seasons: seasons, seed: UInt64(env["CUSTOMER_SEED"] ?? "") ?? 900, club: club, pars: &pars)
                let complaints = feedback(persona, r, c)
                printReport(persona, club: c.userClub.short, r, complaints)
                for k in complaints { allComplaints[k.key, default: []].append("\(persona.rawValue)@\(c.userClub.short)") }
            }
        }
        print("\n--- Pitch pars (avg 1st innings, all league matches) ---")
        for (p, runs) in pars.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            print("  \(p.rawValue): \(runs.reduce(0, +) / max(1, runs.count)) (n=\(runs.count))")
        }
        print("\n--- Complaints by how many players raised them ---")
        for (k, who) in allComplaints.sorted(by: { $0.value.count != $1.value.count ? $0.value.count > $1.value.count : $0.key < $1.key }) {
            print("  \(who.count)× \(k): \(who.joined(separator: ", "))")
        }
    }

    /// Panel 2, "the home crowd": six new personas judge home-pitch squad building. Run it with
    ///
    ///     CUSTOMER_PANEL=2 swift test -c release -Xswiftc -enable-testing --filter CustomerPanelTests
    ///
    /// Default clubs are a turner (1), a seamer (4) and a road (0). After the per-player reports it
    /// compares the personas at each club: does building for the pitch beat ignoring it?
    func testHomeCrowdPanel() {
        let env = ProcessInfo.processInfo.environment
        guard env["CUSTOMER_PANEL"] == "2" else { return }
        let seasons = Int(env["CUSTOMER_SEASONS"] ?? "") ?? 4
        let clubs = (env["CUSTOMER_CLUBS"] ?? "1,4,0").split(separator: ",").compactMap { Int($0) }
        let seed = UInt64(env["CUSTOMER_SEED"] ?? "") ?? 900
        var pars: [Pitch: [Int]] = [:]
        var allComplaints: [String: [String]] = [:]
        var byClub: [String: [(Persona, Report)]] = [:]
        let personas = Persona.allCases.filter { $0.panel == 2 }
        print("\n=== HOME CROWD PANEL: \(personas.count) personas × clubs \(clubs) × \(seasons) seasons · seed \(seed) ===")
        for persona in personas {
            for club in clubs {
                let (r, c) = play(persona, seasons: seasons, seed: seed, club: club, pars: &pars)
                let complaints = feedback(persona, r, c)
                printReport(persona, club: c.userClub.short, r, complaints)
                let pct: (Int, Int) -> Int = { $1 == 0 ? 0 : $0 * 100 / $1 }
                print("  home \(r.homeWins)/\(r.homeGames) (\(pct(r.homeWins, r.homeGames))%) · away \(r.awayWins)/\(r.awayGames) (\(pct(r.awayWins, r.awayGames))%) · XI fit at home \(String(format: "%.1f", r.homeFitSum / Double(max(1, r.homeGames)))) vs visitors \(String(format: "%.1f", r.visitorFitSum / Double(max(1, r.homeGames)))) · pitch \(c.homePitch(c.userClubId).rawValue)")
                print("  suited signings \(r.suitedSigned) · weeks with a suited target \(r.suitedTargetWeeks)/\(r.weeks) · suited lots won \(r.suitedLotsWon)/\(r.suitedLots) paid \(r.suitedPaid) for value \(r.suitedValue) · kids played \(r.kidsPlayed) · board \(r.confidence)% · squad \(r.squadSizeEnd) (\(r.overseasEnd) overseas)")
                for k in complaints { allComplaints[k.key, default: []].append("\(persona.rawValue)@\(c.userClub.short)") }
                byClub[c.userClub.short, default: []].append((persona, r))
            }
        }
        print("\n--- Same club, different managers (win %: home / away / all) ---")
        for (club, rows) in byClub.sorted(by: { $0.key < $1.key }) {
            let line = rows.map { p, r in
                "\(p.rawValue) \(r.homeWins * 100 / max(1, r.homeGames))/\(r.awayWins * 100 / max(1, r.awayGames))/\(r.userWins * 100 / max(1, r.userGames))"
            }.joined(separator: " · ")
            print("  \(club): \(line)")
            if let g = rows.first(where: { $0.0 == .groundsman })?.1, let u = rows.first(where: { $0.0 == .purist })?.1 {
                let (gh, uh) = (g.homeWins * 100 / max(1, g.homeGames), u.homeWins * 100 / max(1, u.homeGames))
                if gh <= uh { allComplaints["pitch build didn't beat ignoring it", default: []].append("groundsman@\(club) \(gh)% vs purist \(uh)% at home") }
            }
        }
        print("\n--- Complaints by how many players raised them ---")
        for (k, who) in allComplaints.sorted(by: { $0.value.count != $1.value.count ? $0.value.count > $1.value.count : $0.key < $1.key }) {
            print("  \(who.count)× \(k): \(who.joined(separator: ", "))")
        }
    }

    /// Diagnostic: league-wide win % by the club's home pitch, home and away, plus XI strength
    /// (CUSTOMER_PANEL=table; CUSTOMER_SEASONS seasons × 6 seeds, the user is a CONTINUE-only manager).
    func testPitchTable() {
        let env = ProcessInfo.processInfo.environment
        guard env["CUSTOMER_PANEL"] == "table" else { return }
        let seasons = Int(env["CUSTOMER_SEASONS"] ?? "") ?? 1
        var home: [Pitch: (Int, Int)] = [:], away: [Pitch: (Int, Int)] = [:], strength: [Pitch: [Int]] = [:]
        var pars: [Pitch: [Int]] = [:]
        for seed in 0..<(Int(env["CUSTOMER_SEEDS"] ?? "") ?? 6) {
            let (_, c) = play(.homeFan, seasons: seasons, seed: UInt64(700 + seed), club: seed, pars: &pars, onSeasonEnd: { c in
                for r in c.results where r.stage == .league {
                    let (hp, ap) = (c.homePitch(r.teamA), c.homePitch(r.teamB))
                    home[hp, default: (0, 0)].1 += 1; away[ap, default: (0, 0)].1 += 1
                    if r.winnerId == r.teamA { home[hp, default: (0, 0)].0 += 1 } else { away[ap, default: (0, 0)].0 += 1 }
                }
            })
            for cl in c.clubs { strength[c.homePitch(cl.id), default: []].append(c.strength(cl.id)) }
        }
        print("\n--- Win % by the club's home pitch (\(seasons) season(s)) ---")
        for p in Pitch.allCases {
            let (h, a) = (home[p] ?? (0, 1), away[p] ?? (0, 1))
            let s = strength[p] ?? []
            print("  \(p.rawValue): home \(h.0 * 100 / max(1, h.1))% · away \(a.0 * 100 / max(1, a.1))% · all \((h.0 + a.0) * 100 / max(1, h.1 + a.1))% · XI at the end \(s.reduce(0, +) / max(1, s.count))")
        }
    }

    // MARK: - Playing

    private func play(_ persona: Persona, seasons: Int, seed: UInt64, club: Int, pars: inout [Pitch: [Int]],
                      onSeasonEnd: (Career) -> Void = { _ in }) -> (Report, Career) {
        var c = Career.new(managerName: "Panel", clubIndex: club, seed: seed, year: 2027, curated: EngineTests.players,
                           born: CareerTests.born, flags: CareerFlags(legendsEra: false))
        c.settings.difficulty = persona.difficulty
        // Hands-on managers pick their own XI (in the app, picking by hand turns the assistant off).
        if persona.picksOwnXI { c.settings.assistantPicksXI = false }
        if persona == .tinkerer || persona == .veteran {
            c.tactics = Tactics(field: [.attack, .balanced, .defend], intent: [.attack, .rotate, .attack])
        }
        var r = Report()
        r.strength.append(c.strength(c.userClubId))
        r.aiStart = c.clubs.filter { $0.id != c.userClubId }.map { c.strength($0.id) }
        let endYear = c.year + seasons
        var youthWatch: [String: Int] = youngsters(c)
        var steps = 0
        var lastNews = 0
        while c.year < endYear && steps < 20_000 {
            steps += 1
            // Read the news like a player skimming the feed.
            for n in c.news where n.id > lastNews {
                if n.text.hasPrefix("📋 Assistant") { r.assistantNotes += 1 }
                if n.text.hasPrefix("🕰️ Retirement watch") { r.retirementWarnings += 1 }
                if n.text.hasPrefix("🃏") { r.rtmUsed += 1 }
            }
            lastNews = max(lastNews, c.news.map(\.id).max() ?? 0)
            r.presses += 1
            switch c.nextAction {
            case .goToOffseason:
                onSeasonEnd(c)
                endOfSeason(&c, &r, &pars, &youthWatch)
                let report = c.beginOffseason()
                r.starsRetired += report.userRetired
                if let offer = c.intl.offers.first, c.intl.job == nil { c.acceptJob(offer) }
            case .openWindow: c.ensureWindow()
            case .playIntl(let id): _ = c.play(fixtureId: id)
            case .simWindow: c.simWindow(stopAtUser: true)
            case .retention: c.confirmRetention(userKeeps: c.suggestedRetentions())
            case .auction:
                // Compared with last season's XI (after retentions the XI is only the keepers).
                let before = r.strength.last ?? 0
                let aiBefore = r.aiSeasonEnd
                auction(persona, &c, &r)
                if persona != .caster && persona != .homeFan { c.autoPickXI(clubIndex: c.userClubIndex) }
                var check = c
                check.autoPickXI(clubIndex: check.userClubIndex)
                // Relative to the AI clubs over the same off-season (everyone ages and loses retirees).
                var aiNow = 0
                for cl in check.clubs where cl.id != c.userClubId {
                    var x = check
                    x.autoPickXI(clubIndex: x.clubs.firstIndex { $0.id == cl.id }!)
                    aiNow += x.strength(cl.id)
                }
                aiNow /= max(1, check.clubs.count - 1)
                r.auctionDeltas.append((check.strength(c.userClubId) - before) - (aiNow - aiBefore))
            case .startSeason:
                c.startSeasonFromOffseason()
                if persona == .rookie || persona.picksOwnXI { c.autoPickXI(clubIndex: c.userClubIndex) }
            case .playMatch(let id):
                weekly(persona, &c, &r)
                matchDay(id, &c, &r)
            case .continueToMatch:
                // The app sims the round and opens the match in the same press.
                c.simUntilUserMatch()
                if case .playMatch(let id) = c.nextAction {
                    weekly(persona, &c, &r)
                    matchDay(id, &c, &r)
                } else {
                    r.idlePresses += 1
                }
            case .watchOther(let id):
                r.idlePresses += 1
                _ = c.play(fixtureId: id)
            case .none:
                XCTFail("\(persona): dead end"); return (r, c)
            }
        }
        r.strength.append(c.strength(c.userClubId))
        r.aiStrength = c.clubs.filter { $0.id != c.userClubId }.map { c.strength($0.id) }
        r.managerLevel = c.manager.level
        let sq = c.squad(c.userClubId)
        r.formEnd = sq.map(\.form).reduce(0, +) / max(1, sq.count)
        r.coldEnd = sq.filter { c.userClub.xi.contains($0.id) && $0.form <= -4 }.count
        r.monthAwards = c.board.awards.filter { $0.managerClub == c.userClubId }.count
        r.confidence = c.board.confidence
        r.squadSizeEnd = sq.count
        r.overseasEnd = sq.filter(\.overseas).count
        return (r, c)
    }

    private func matchDay(_ id: Int, _ c: inout Career, _ r: inout Report) {
        // Would Auto-pick have fielded a clearly better side?
        var best = c
        best.autoPickXI(clubIndex: best.userClubIndex)
        if best.strength(c.userClubId) - c.strength(c.userClubId) >= 2 { r.staleXIMatches += 1 }
        let fixture = c.fixtures.first { $0.id == id }
        guard let (res, _) = c.play(fixtureId: id) else { XCTFail("stuck at \(id)"); return }
        score(res, c, &r)
        guard let f = fixture, f.stage == .league else { return }
        let won = res.winnerId == c.userClubId
        if f.home == c.userClubId {
            r.homeGames += 1
            if won { r.homeWins += 1 }
            r.homeFitSum += c.xiHomeFit(c.userClubId)
            let visitors = c.club(f.away)?.xi.compactMap { c.players[$0] } ?? []
            r.visitorFitSum += Double(visitors.map { c.homeFit($0, clubId: c.userClubId) }.reduce(0, +)) / Double(max(1, visitors.count))
        } else {
            r.awayGames += 1
            if won { r.awayWins += 1 }
        }
    }

    private func youngsters(_ c: Career) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: c.squad(c.userClubId).filter { $0.age(in: c.year) <= 21 }.map { ($0.id, $0.rating) })
    }

    private func endOfSeason(_ c: inout Career, _ r: inout Report, _ pars: inout [Pitch: [Int]], _ youthWatch: inout [String: Int]) {
        r.finishes.append(c.userFinish())
        if c.championId == c.userClubId { r.trophies += 1 }
        for o in c.board.objectives {
            r.objectivesSet += 1
            if o.met == true { r.objectivesMet += 1 }
        }
        r.objectiveLog.append(c.board.objectives.map { "\($0.kind.rawValue)\($0.target)\($0.met == true ? "✓" : "✗")" }.joined(separator: " "))
        if c.board.objectives.contains(where: { $0.kind == .youth && $0.met == false }),
           c.squad(c.userClubId).filter({ $0.age(in: c.year) <= 23 }).count <= 1 { r.youthImpossible += 1 }
        for res in c.results where res.stage == .league { pars[res.pitch, default: []].append(res.innings[0].runs) }
        r.bank.append(c.bank(c.userClubId) / 100)
        let ai = c.clubs.filter { $0.id != c.userClubId }.map { c.bank($0.id) }
        r.aiBank.append(ai.reduce(0, +) / max(1, ai.count) / 100)
        r.strength.append(c.strength(c.userClubId))
        let ais = c.clubs.filter { $0.id != c.userClubId }.map { c.strength($0.id) }
        r.aiSeasonEnd = ais.reduce(0, +) / max(1, ais.count)
        for (id, start) in youthWatch { if let p = c.players[id], !p.retired { r.youthGrowth.append(p.rating - start) } }
        youthWatch = youngsters(c)
    }

    private func auction(_ persona: Persona, _ c: inout Career, _ r: inout Report) {
        guard [.bidder, .trader, .groundsman, .purist, .collector].contains(persona) else { c.simRestOfAuction(autoBid: true); return }
        var guardCount = 0
        while c.offseason?.stage == .auction && guardCount < 500 {
            guardCount += 1
            if let id = c.offseason?.auction.currentId, let p = c.players[id] {
                // Bid while the staff say he helps and the price stays sane.
                let suited = c.suitsUserPitch(p)
                var wants = c.scoutAdvice(p).good && c.squad(c.userClubId).count < c.tuning.auctionSquadTarget + 2
                var ceiling = 1.4
                if persona == .groundsman {
                    // Only players who don't struggle on his pitch; pays up for the ones who suit it.
                    wants = wants && suited != false
                    if suited == true { ceiling = 1.6; r.suitedLots += wants ? 1 : 0 }
                }
                if persona == .collector {
                    wants = p.rating >= 80 && c.squad(c.userClubId).count < c.tuning.maxSquad - 1; ceiling = 1.6
                }
                // Right to Match on a former player the staff rate.
                if c.canUseRTM, c.scoutAdvice(p).good, let price = c.rtmPrice, Double(price) <= Double(p.value(in: c.year)) * 1.4 {
                    if c.useRTM() != nil { r.lotsWon += 1 }
                    continue
                }
                var tries = 0
                while wants, tries < 30, c.offseason?.auction.leader != c.userClubId,
                      let next = c.auctionNextBid, Double(next) <= Double(p.value(in: c.year)) * ceiling, c.userBid() { tries += 1 }
                if let sale = c.passLot(), sale.clubId == c.userClubId {
                    r.lotsWon += 1
                    if persona == .groundsman, suited == true {
                        r.suitedLotsWon += 1; r.suitedPaid += sale.price; r.suitedValue += p.value(in: c.year)
                    }
                }
                continue
            }
            if let sale = c.passLot(), sale.clubId == c.userClubId { r.lotsWon += 1 }
        }
    }

    /// What each persona does between matches.
    private func weekly(_ persona: Persona, _ c: inout Career, _ r: inout Report) {
        if persona.panel == 2 { homeCrowdWeek(persona, &c, &r); return }
        if persona.managesSquad {
            r.trainingSessions += 1
            if c.runTrainingSession().isEmpty { r.emptySessions += 1 }
            if c.manager.points > 0, let p = Perk.allCases.first(where: { c.canLearn($0) == nil }) { c.learn(p) }
            if c.facilities.building == nil, c.bank(c.userClubId) > 2_000 {
                _ = c.upgrade(FacilityKind.allCases[c.leaguePlayed % FacilityKind.allCases.count])
            }
            // Follow the game-plan badge for the next pitch (keeps captain, toss and roles).
            if let pitch = c.nextUserFixture?.pitch { c.tactics = GamePlan.suggested(for: pitch).apply(to: c.tactics) }
            if c.tactics.captain == nil { c.tactics.captain = c.userClub.xi.compactMap { c.players[$0] }.max { $0.rating < $1.rating }?.id }
            // A losing run: follow the assistant's advice, like a real manager would.
            if [3, 6, 9, 12].contains(r.losingRun), let report = c.assistantReport() {
                for line in report.advice {
                    if line.contains("powerplay intent to Attack") { c.tactics.intent[0] = .attack; r.tacticChanges += 1 }
                    if line.contains("field to Defend") { c.tactics.field[2] = .defend; r.tacticChanges += 1 }
                    if line.hasPrefix("Fix the order") { c.autoPickXI(clubIndex: c.userClubIndex); r.tacticChanges += 1 }
                    if line.hasPrefix("Rest "), let cold = c.userClub.xi.compactMap({ c.players[$0] }).min(by: { $0.form < $1.form }) {
                        var ids = c.userClub.xi.filter { $0 != cold.id }
                        if let sub = c.squad(c.userClubId).filter({ !ids.contains($0.id) && $0.id != cold.id && $0.role == cold.role })
                            .max(by: { $0.rating < $1.rating }) {
                            ids.append(sub.id)
                            if TeamSelector.blockingIssues(ids.compactMap { c.player($0) }, rules: c.rules).isEmpty {
                                c.setXI(clubId: c.userClubId, ids: ids); r.tacticChanges += 1
                            }
                        }
                    }
                }
            }
        }
        if persona == .trader { trade(&c, &r) }
        if persona.managesSquad && ![3, 6, 9, 12].contains(r.losingRun) {
            if persona == .tinkerer {
                // The tinkerer runs the team through the squad planner.
                c.autoPlan()
                if !c.applyPlan().isEmpty { r.planFailures += 1; c.autoPickXI(clubIndex: c.userClubIndex) }
            } else {
                c.autoPickXI(clubIndex: c.userClubIndex)
            }
        }
    }

    /// Panel 2: what each home-crowd persona does between matches.
    private func homeCrowdWeek(_ persona: Persona, _ c: inout Career, _ r: inout Report) {
        r.weeks += 1
        let pitch = c.nextUserFixture?.pitch
        switch persona {
        case .groundsman:
            // Shop for players who suit the ground, then pick for the day's pitch (the Auto-pick button).
            trade(&c, &r, want: { c, p in c.suitsUserPitch(p) == true }, rank: { c, p in c.pitchRating(p, clubId: c.userClubId) })
            c.autoPickXI(clubIndex: c.userClubIndex, pitch: pitch)
        case .purist:
            trade(&c, &r)
            c.autoPickXI(clubIndex: c.userClubIndex)
        case .collector:
            // The best player money can buy, whatever the staff say about the squad shape.
            trade(&c, &r, want: { _, p in p.rating >= 78 }, needsAdvice: false)
            c.autoPickXI(clubIndex: c.userClubIndex)
        case .developer:
            r.trainingSessions += 1
            if c.runTrainingSession().isEmpty { r.emptySessions += 1 }
            c.autoPickXI(clubIndex: c.userClubIndex, pitch: pitch)
            // Up to three U23s replace the weakest older player of the same role.
            var ids = c.userClub.xi
            let kids = c.squad(c.userClubId).filter { $0.age(in: c.year) <= 23 && !ids.contains($0.id) }
                .sorted { $0.potential != $1.potential ? $0.potential > $1.potential : $0.id < $1.id }
            var inXI = ids.compactMap { c.players[$0] }.filter { $0.age(in: c.year) <= 23 }.count
            for kid in kids where inXI < 3 {
                guard let out = ids.compactMap({ c.players[$0] })
                    .filter({ $0.role == kid.role && $0.age(in: c.year) > 23 && $0.overseas == kid.overseas })
                    .min(by: { $0.rating < $1.rating }), let i = ids.firstIndex(of: out.id) else { continue }
                ids[i] = kid.id
                inXI += 1
            }
            if TeamSelector.blockingIssues(ids.compactMap { c.player($0) }, rules: c.rules).isEmpty { c.setXI(clubId: c.userClubId, ids: ids) }
            r.kidsPlayed += c.userClub.xi.compactMap { c.players[$0] }.filter { $0.age(in: c.year) <= 23 }.count
        default:
            break   // homeFan: the assistant picks. setAndForget: the XI from week one stands.
        }
    }

    private func trade(_ c: inout Career, _ r: inout Report, want: (Career, CareerPlayer) -> Bool = { _, _ in true },
                       rank: (Career, CareerPlayer) -> Double = { _, p in Double(p.rating) }, needsAdvice: Bool = true) {
        for o in c.market.offers.sorted(by: { $0.id < $1.id }) where c.acceptOffer(o.id) { r.sold += 1 }
        let mine = c.squad(c.userClubId)
        let xi = Set(c.userClub.xi)
        if mine.count > c.tuning.minSquad + 1,
           let weakest = mine.filter({ !xi.contains($0.id) && c.market.listed[$0.id] == nil }).min(by: { $0.rating < $1.rating }) {
            c.listForTransfer(weakest.id, asking: weakest.value(in: c.year))
        }
        // Once a week: try for the best upgrade the staff recommend, at the asking price.
        let targets = c.players.values
            .filter { $0.clubId != c.userClubId && !$0.retired && $0.academyOf == nil && want(c, $0)
                && (needsAdvice ? c.scoutAdvice($0, fee: $0.clubId == nil ? 0 : c.askingPrice($0)).good
                    : c.askingPrice($0) <= c.bank(c.userClubId) && c.squad(c.userClubId).count < c.tuning.maxSquad
                        // The app refuses these bids with a clear message; a person stops trying.
                        && (!$0.overseas || c.squad(c.userClubId).filter(\.overseas).count < c.tuning.maxOverseasSquad)) }
            .sorted { rank(c, $0) != rank(c, $1) ? rank(c, $0) > rank(c, $1) : $0.id < $1.id }
        if !targets.isEmpty { r.suitedTargetWeeks += 1 }
        for t in targets.prefix(2) {
            r.offerTries += 1
            var outcome = c.makeOffer(playerId: t.id, fee: t.clubId == nil ? 0 : c.askingPrice(t), wage: c.userWageDemand(t))
            if case .counter(let fee, let wage, _) = outcome { outcome = c.makeOffer(playerId: t.id, fee: fee, wage: wage) }
            switch outcome {
            case .accepted:
                r.signings += 1
                if c.suitsUserPitch(t) == true { r.suitedSigned += 1 }
                return
            case .counter(_, _, let m), .rejected(let m):
                r.offerFails += 1
                r.failReasons[reason(m), default: 0] += 1
            }
        }
    }

    private func reason(_ m: String) -> String {
        for (k, v) in [("salary cap", "cap"), ("bank", "bank"), ("squad is full", "squad full"), ("overseas", "overseas"),
                       ("stopped talking", "talks over"), ("turned it down", "fee too low"), ("isn't interested", "wage"),
                       ("window is closed", "window")] where m.contains(k) { return v }
        return "other"
    }

    private func score(_ res: MatchResult, _ c: Career, _ r: inout Report) {
        let me = c.userClubId
        guard res.teamA == me || res.teamB == me else { return }
        r.userGames += 1
        if res.winnerId == me { r.userWins += 1; r.losingRun = 0 } else {
            r.losingRun += 1
            r.longestLosingRun = max(r.longestLosingRun, r.losingRun)
            if r.losingRun == 10, ProcessInfo.processInfo.environment["PANEL_DEBUG"] == "1" {
                let xi = c.userClub.xi.compactMap { c.players[$0] }
                var best = c; best.autoPickXI(clubIndex: best.userClubIndex)
                let opp = res.teamA == me ? res.teamB : res.teamA
                print("    DEBUG 10-loss run \(c.year) wk\(c.leaguePlayed): XI str \(c.strength(me)) auto \(best.strength(me)) opp \(c.strength(opp)) · forms \(xi.map(\.form)) · ratings \(xi.map(\.rating)) · roles \(xi.map(\.role.rawValue)) · issues \(c.xiIssues(me)) · score \(res.innings.map { "\($0.teamId):\($0.runs)/\($0.wickets)" })")
            }
        }
        if res.superOver { r.superOvers += 1; r.thrillers += 1; return }
        let first = res.innings[0], second = res.innings[1]
        let chaseWon = res.winnerId == second.teamId
        let runsMargin = chaseWon ? 0 : first.runs - second.runs
        let ballsLeft = chaseWon ? 120 - second.balls : 0
        let wktsLeft = chaseWon ? 10 - second.wickets : 0
        if (!chaseWon && runsMargin <= 8) || (chaseWon && (ballsLeft <= 3 || wktsLeft <= 2)) { r.thrillers += 1 }
        if (!chaseWon && runsMargin >= 45) || (chaseWon && (ballsLeft >= 30 || wktsLeft >= 8)) { r.blowouts += 1 }
    }

    // MARK: - Feedback (what a real player would say)

    private func feedback(_ persona: Persona, _ r: Report, _ c: Career) -> [String: String] {
        var out: [String: String] = [:]
        let g = max(1, r.userGames)
        let pct: (Int, Int) -> Int = { $1 == 0 ? 0 : $0 * 100 / $1 }
        // (The developer benches better players for the kids on purpose.)
        if pct(r.staleXIMatches, g) >= 15, persona != .developer {
            out["stale XI"] = "\(r.staleXIMatches) of \(g) matches had a clearly better XI sitting on my bench, and nobody told me."
        }
        if r.longestLosingRun >= 6 && r.assistantNotes == 0 {
            out["losing run"] = "I lost \(r.longestLosingRun) in a row and the game never told me why or what to change."
        } else if r.longestLosingRun >= 8 && persona.managesSquad {
            out["advice didn't help"] = "I followed the assistant (\(r.tacticChanges) changes) and still lost \(r.longestLosingRun) in a row."
        }
        if r.trainingSessions > 20, pct(r.emptySessions, r.trainingSessions) >= 50 {
            out["training feels empty"] = "\(r.emptySessions) of \(r.trainingSessions) training sessions showed no gains."
        }
        if r.offerTries >= 20, pct(r.offerFails, r.offerTries) >= 70 {
            let top = r.failReasons.sorted { $0.value > $1.value }.prefix(3).map { "\($0.key) \($0.value)" }.joined(separator: ", ")
            out["market blocks me"] = "\(r.offerFails) of \(r.offerTries) bids failed (\(top))."
        }
        if let last = r.bank.last, last >= 150, r.signings == 0, !persona.managesSquad,
           !r.objectiveLog.contains(where: { $0.contains("invest") }) {
            out["money unused"] = "₹\(last) Cr in the bank and nothing pushed me to spend it."
        }
        if r.youthImpossible > 0 {
            out["impossible objective"] = "The board wanted U23 appearances when I had at most one U23 player (\(r.youthImpossible)×)."
        }
        let setPct = pct(r.objectivesMet, r.objectivesSet)
        if persona.difficulty == .normal && setPct >= 85 { out["objectives too easy"] = "Met \(setPct)% of objectives on Normal." }
        if persona.difficulty != .legend && setPct <= 25 { out["objectives too hard"] = "Met only \(setPct)% of objectives." }
        if pct(r.thrillers, g) < 15 { out["few close games"] = "Only \(pct(r.thrillers, g))% of my games went to the wire." }
        if pct(r.blowouts, g) >= 45 { out["one-sided games"] = "\(pct(r.blowouts, g))% of my games were blowouts." }
        let aiAvg = r.aiStrength.reduce(0, +) / max(1, r.aiStrength.count)
        let aiStartAvg = r.aiStart.reduce(0, +) / max(1, r.aiStart.count)
        if let first = r.strength.first, let last = r.strength.last, (first - last) - (aiStartAvg - aiAvg) >= 3 {
            out["squad decays"] = "My XI fell from \(first) to \(last) while the AI went \(aiStartAvg) → \(aiAvg)."
        }
        if r.auctionDeltas.contains(where: { $0 <= -4 }) {
            out["auction hurt"] = "Off-seasons left my XI weaker than the AI clubs got's (\(r.auctionDeltas))."
        }
        if r.youthGrowth.count >= 3, Double(r.youthGrowth.reduce(0, +)) / Double(r.youthGrowth.count) < 2 {
            out["youngsters don't grow"] = "My U21s grew \(String(format: "%.1f", Double(r.youthGrowth.reduce(0, +)) / Double(r.youthGrowth.count))) a season on average."
        }
        if pct(r.idlePresses, r.presses) >= 25 { out["too much tapping"] = "\(pct(r.idlePresses, r.presses))% of presses were just waiting." }
        if !r.starsRetired.isEmpty, persona == .caster, r.retirementWarnings == 0 {
            out["stars vanish"] = "\(r.starsRetired.count) of my players retired; I only noticed in the news."
        }
        if r.planFailures > 0 { out["planner broke"] = "The squad planner couldn't name a legal XI \(r.planFailures) times." }
        if persona == .tinkerer, r.staleXIMatches > r.userGames / 10 {
            out["planner weaker"] = "My planned XI was clearly weaker than Auto-pick in \(r.staleXIMatches) matches."
        }
        if persona.panel == 2 {
            let (home, away) = (pct(r.homeWins, r.homeGames), pct(r.awayWins, r.awayGames))
            let (fit, visitors) = (r.homeFitSum / Double(max(1, r.homeGames)), r.visitorFitSum / Double(max(1, r.homeGames)))
            if r.homeGames >= 30, home + 3 < away {
                out["home means nothing"] = "I win less at home (\(home)%) than away (\(away)%)."
            }
            if persona == .homeFan, home < 45 { out["poor at home"] = "We won \(home)% at home with the assistant picking." }
            if fit < visitors - 0.5 {
                out["visitors suit my pitch better"] = "My XI's fit to my own pitch (\(String(format: "%.1f", fit))) was below the visitors' (\(String(format: "%.1f", visitors)))."
            }
            if persona == .groundsman {
                if r.weeks > 20, pct(r.suitedTargetWeeks, r.weeks) < 25 {
                    out["nobody to buy for my pitch"] = "Only \(r.suitedTargetWeeks) of \(r.weeks) weeks had a player who suits my pitch that the staff would sign."
                }
                if r.suitedLots >= 5, pct(r.suitedLotsWon, r.suitedLots) < 20 {
                    out["outbid for pitch players"] = "I won \(r.suitedLotsWon) of \(r.suitedLots) auction lots that suit my pitch."
                }
                if r.suitedValue > 0, r.suitedPaid * 100 / r.suitedValue >= 140 {
                    out["pitch players overpriced"] = "I paid \(r.suitedPaid * 100 / r.suitedValue)% of value for players who suit my pitch."
                }
                if fit < visitors + 1 { out["building for the pitch barely shows"] = "After all that, my XI's fit (\(String(format: "%.1f", fit))) is level with the visitors' (\(String(format: "%.1f", visitors)))." }
            }
            if persona == .setAndForget, pct(r.staleXIMatches, g) >= 15, r.assistantNotes == 0 {
                out["nobody nudged me"] = "My XI was out of date in \(r.staleXIMatches) matches and no one said so."
            }
            if persona == .collector {
                let aiNow = r.aiStrength.reduce(0, +) / max(1, r.aiStrength.count)
                if let last = r.strength.last, last - aiNow >= 6 { out["stars are too easy to hoard"] = "My XI is \(last), the AI average \(aiNow)." }
                if r.offerTries >= 20, r.signings == 0 { out["can't buy a star"] = "\(r.offerTries) bids for stars, none signed (\(r.failReasons))." }
            }
            if persona == .developer {
                if r.kidsPlayed == 0 { out["no kids to play"] = "I never had a U23 who could take a place in the XI." }
                if r.confidence < 45 { out["board hates youth"] = "Playing the kids left the board at \(r.confidence)%." }
            }
            if r.confidence <= 20 { out["board has given up"] = "Board confidence ended at \(r.confidence)%." }
        }
        if persona.difficulty == .legend && r.trophies > 0 { out["legend too soft"] = "Won \(r.trophies) titles on Legend." }
        if persona.difficulty == .easy && r.trophies == 0 { out["easy too hard"] = "No title on Easy in \(r.finishes.count) seasons." }
        return out
    }

    private func printReport(_ persona: Persona, club: String, _ r: Report, _ complaints: [String: String]) {
        let g = max(1, r.userGames)
        let pct: (Int, Int) -> Int = { $1 == 0 ? 0 : $0 * 100 / $1 }
        print("\n## \(persona.rawValue) @ \(club) — \"\(persona.quote)\"")
        print("  finishes: \(r.finishes.joined(separator: ", ")) · trophies \(r.trophies) · level \(r.managerLevel)")
        print("  record \(r.userWins)/\(r.userGames) (\(pct(r.userWins, g))%) · thrillers \(pct(r.thrillers, g))% · blowouts \(pct(r.blowouts, g))% · longest losing run \(r.longestLosingRun)")
        print("  assistant notes \(r.assistantNotes) · retirement warnings \(r.retirementWarnings) · RTM \(r.rtmUsed) · squad form \(r.formEnd) (\(r.coldEnd) cold in the XI)")
        print("  presses \(r.presses), idle \(pct(r.idlePresses, r.presses))% · stale XI \(r.staleXIMatches) · tactic changes \(r.tacticChanges)")
        print("  training \(r.trainingSessions) (empty \(r.emptySessions)) · bids \(r.offerTries) (failed \(r.offerFails) \(r.failReasons)) · signed \(r.signings) · sold \(r.sold) · lots \(r.lotsWon) · auction ΔXI \(r.auctionDeltas)")
        print("  objectives \(r.objectivesMet)/\(r.objectivesSet) \(r.objectiveLog) · MotM ×\(r.monthAwards)")
        print("  bank \(r.bank) · AI bank \(r.aiBank) · XI \(r.strength) · AI XIs \(r.aiStart.reduce(0, +) / max(1, r.aiStart.count)) → \(r.aiStrength) · U21 growth/season \(r.youthGrowth.isEmpty ? 0 : r.youthGrowth.reduce(0, +) / r.youthGrowth.count) · retired \(r.starsRetired.count)")
        for (_, line) in complaints.sorted(by: { $0.key < $1.key }) { print("  💬 \"\(line)\"") }
    }
}
