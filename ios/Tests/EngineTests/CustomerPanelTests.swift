import XCTest
@testable import AuctionEngine

/// Customer panel: simulated players ("personas") play full careers through the real engine, the way
/// a person would through the CONTINUE button, and each one reports what they noticed. Run it with
///
///     CUSTOMER_PANEL=1 swift test -c release -Xswiftc -enable-testing --filter CustomerPanelTests
///
/// `CUSTOMER_SEASONS` (default 4) sets the career length. The printed report is the raw input for
/// `docs/feedback/`. Without CUSTOMER_PANEL the test returns at once, so the normal suite stays fast.
final class CustomerPanelTests: XCTestCase {

    enum Persona: String, CaseIterable {
        /// Presses CONTINUE and nothing else (casts matches, wants a story).
        case caster
        /// Runs training every week, learns perks, builds facilities, sets aggressive tactics.
        case tinkerer
        /// Trades every week: buys the best affordable upgrade, sells the bench.
        case trader
        /// Lives for the auction: bids on every lot it can afford.
        case bidder
        /// Hard-core: Legend difficulty, plays sensibly.
        case veteran
        /// New to the genre: Easy difficulty, presses CONTINUE.
        case rookie

        var quote: String {
            switch self {
            case .caster: return "I cast matches to the TV and just want a story."
            case .tinkerer: return "I want every lever to matter."
            case .trader: return "The market is the game for me."
            case .bidder: return "The auction is why I play IPL games."
            case .veteran: return "Give me Legend and make me earn it."
            case .rookie: return "First manager game, Easy mode."
            }
        }
    }

    struct Report {
        var finishes: [String] = []
        var userWins = 0, userGames = 0
        var thrillers = 0, blowouts = 0, superOvers = 0
        var favouriteWins = 0, favouriteGames = 0
        var presses = 0, idlePresses = 0
        var newsPerSeason: [Int] = []
        var longestQuietStretch = 0
        var offersIn = 0
        var signings = 0
        var bank: [Int] = []
        var aiBank: [Int] = []
        var squadRatingStart = 0, squadRatingEnd = 0
        var aiStrength: [Int] = []
        var aiDeals = 0
        var objectives: [String] = []
        var monthAwards = 0
        var lotsWon = 0
        var managerLevel = 1
        var trophies = 0
        var notes: [String] = []
    }

    func testCustomerPanel() {
        guard ProcessInfo.processInfo.environment["CUSTOMER_PANEL"] == "1" else { return }
        let seasons = Int(ProcessInfo.processInfo.environment["CUSTOMER_SEASONS"] ?? "") ?? 4
        var pars: [Pitch: [Int]] = [:]
        print("\n=== CUSTOMER PANEL: \(Persona.allCases.count) personas × \(seasons) seasons ===")
        for (i, persona) in Persona.allCases.enumerated() {
            // Same club and seed for everyone: differences come from how they play, not from the draw.
            _ = i
            let r = play(persona, seasons: seasons, seed: 900, club: 3, pars: &pars)
            printReport(persona, r)
        }
        print("\n--- Pitch pars (avg 1st innings, all league matches) ---")
        for (p, runs) in pars.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            print("  \(p.rawValue): \(runs.reduce(0, +) / max(1, runs.count)) (n=\(runs.count))")
        }
    }

    // MARK: - Playing

    private func play(_ persona: Persona, seasons: Int, seed: UInt64, club: Int, pars: inout [Pitch: [Int]]) -> Report {
        var c = Career.new(managerName: "Panel", clubIndex: club, seed: seed, year: 2027, curated: EngineTests.players,
                           born: CareerTests.born, flags: CareerFlags(legendsEra: false))
        switch persona {
        case .veteran: c.settings.difficulty = .legend
        case .rookie: c.settings.difficulty = .easy
        default: break
        }
        if persona == .tinkerer {
            c.tactics = Tactics(field: [.attack, .balanced, .defend], intent: [.attack, .rotate, .attack])
        }
        var r = Report()
        r.squadRatingStart = c.strength(c.userClubId)
        let endYear = c.year + seasons
        var lastNewsCount = c.nextNewsId
        var quiet = 0
        var seasonNewsStart = c.nextNewsId
        var steps = 0
        while c.year < endYear && steps < 20_000 {
            steps += 1
            r.presses += 1
            let action = c.nextAction
            let before = c.results.count
            switch action {
            case .goToOffseason:
                r.finishes.append(c.userFinish())
                r.objectives.append(c.board.objectives.map { "\($0.kind.rawValue)\($0.target):\($0.met == true ? "✓" : "✗")" }.joined(separator: " "))
                if c.championId == c.userClubId { r.trophies += 1 }
                for res in c.results where res.stage == .league { pars[res.pitch, default: []].append(res.innings[0].runs) }
                r.newsPerSeason.append(c.nextNewsId - seasonNewsStart)
                r.bank.append(c.bank(c.userClubId) / 100)
                var aiTotal = 0
                for cl in c.clubs where cl.id != c.userClubId { aiTotal += c.bank(cl.id) }
                r.aiBank.append(aiTotal / 9 / 100)
                c.beginOffseason()
                if let offer = c.intl.offers.first, c.intl.job == nil { c.acceptJob(offer) }
                seasonNewsStart = c.nextNewsId
            case .openWindow: c.ensureWindow()
            case .playIntl(let id): _ = c.play(fixtureId: id)
            case .simWindow: c.simWindow(stopAtUser: true)
            case .retention: c.confirmRetention(userKeeps: c.suggestedRetentions())
            case .auction:
                if persona == .bidder || persona == .trader {
                    var guardCount = 0
                    while c.offseason?.stage == .auction && guardCount < 400 {
                        guardCount += 1
                        let mine = c.squad(c.userClubId).count
                        if mine < c.tuning.auctionSquadTarget + 2, c.userBid() { _ = c.userBid() }
                        if let sale = c.passLot(), sale.clubId == c.userClubId { r.lotsWon += 1 }
                    }
                } else {
                    c.simRestOfAuction(autoBid: true)
                }
            case .startSeason:
                c.startSeasonFromOffseason()
            case .playMatch(let id):
                weekly(persona, &c, &r)
                guard let (res, _) = c.play(fixtureId: id) else { XCTFail("\(persona) stuck"); return r }
                score(res, &c, &r)
            case .continueToMatch:
                // The app sims the round and opens the match in the same press when it can.
                c.simUntilUserMatch()
                if case .playMatch = c.nextAction { r.presses -= 1 } else { r.idlePresses += 1 }
            case .watchOther(let id):
                r.idlePresses += 1
                _ = c.play(fixtureId: id)
            case .none:
                XCTFail("\(persona): dead end"); return r
            }
            _ = before
            if c.nextNewsId == lastNewsCount && c.phase == CareerPhase.season { quiet += 1 } else { quiet = 0 }
            r.longestQuietStretch = max(r.longestQuietStretch, quiet)
            lastNewsCount = c.nextNewsId
        }
        r.offersIn = c.news.filter { $0.text.localizedCaseInsensitiveContains("bid") || $0.text.localizedCaseInsensitiveContains("offer") }.count
        r.squadRatingEnd = c.strength(c.userClubId)
        r.aiStrength = c.clubs.filter { $0.id != c.userClubId }.map { c.strength($0.id) }
        r.aiDeals = c.news.filter { n in n.text.hasPrefix("✍️") && !n.text.contains(c.userClub.short) && n.text.contains(" for ") }.count
        r.managerLevel = c.manager.level
        r.monthAwards = c.board.awards.filter { $0.managerClub == c.userClubId }.count
        return r
    }

    /// What each persona does between matches.
    private func weekly(_ persona: Persona, _ c: inout Career, _ r: inout Report) {
        switch persona {
        case .tinkerer, .veteran:
            c.runTrainingSession()
            if c.manager.points > 0, let p = Perk.allCases.first(where: { c.canLearn($0) == nil }) { c.learn(p) }
            if c.facilities.building == nil { _ = c.upgrade(FacilityKind.allCases[c.leaguePlayed % FacilityKind.allCases.count]) }
        case .trader:
            c.runTrainingSession()
            // Accept any offer worth more than value; list the weakest bench player.
            for o in c.market.offers { if c.acceptOffer(o.id) { r.notes.append("sold") } }
            let mine = c.squad(c.userClubId)
            let xi = Set(c.userClub.xi)
            if let weakest = mine.filter({ !xi.contains($0.id) && c.market.listed[$0.id] == nil }).min(by: { $0.rating < $1.rating }),
               mine.count > c.tuning.minSquad + 1 {
                c.listForTransfer(weakest.id, asking: weakest.value(in: c.year))
            }
            // Buy the best player who is better than our worst XI member and affordable.
            let worstXI = c.userClub.xi.compactMap { c.players[$0]?.rating }.min() ?? 0
            let targets = c.players.values.filter { $0.clubId != nil && $0.clubId != c.userClubId && !$0.retired && $0.rating > worstXI + 3 }
                .sorted { $0.rating > $1.rating }
            for t in targets.prefix(3) {
                let fee = c.askingPrice(t), wage = c.userWageDemand(t)
                if case .accepted = c.makeOffer(playerId: t.id, fee: fee, wage: wage) { r.signings += 1; break }
            }
        case .caster, .rookie, .bidder:
            break
        }
    }

    private func score(_ res: MatchResult, _ c: inout Career, _ r: inout Report) {
        let me = c.userClubId
        guard res.teamA == me || res.teamB == me else { return }
        r.userGames += 1
        if res.winnerId == me { r.userWins += 1 }
        let opp = res.teamA == me ? res.teamB : res.teamA
        let (sm, so) = (c.strength(me), c.strength(opp))
        if abs(sm - so) >= 3 {
            r.favouriteGames += 1
            if res.winnerId == (sm > so ? me : opp) { r.favouriteWins += 1 }
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

    // MARK: - Report

    private func printReport(_ persona: Persona, _ r: Report) {
        let g = max(1, r.userGames)
        let pct: (Int, Int) -> Int = { $1 == 0 ? 0 : $0 * 100 / $1 }
        print("\n## \(persona.rawValue) — \"\(persona.quote)\"")
        print("  finishes: \(r.finishes.joined(separator: ", ")) · trophies \(r.trophies) · manager level \(r.managerLevel)")
        print("  record: \(r.userWins)/\(r.userGames) (\(pct(r.userWins, g))%) · thrillers \(pct(r.thrillers, g))% · blowouts \(pct(r.blowouts, g))% · super overs \(r.superOvers)")
        print("  favourite (≥3 str gap) won \(pct(r.favouriteWins, r.favouriteGames))% of \(r.favouriteGames)")
        print("  presses \(r.presses), idle (no decision) \(pct(r.idlePresses, r.presses))% · longest quiet stretch \(r.longestQuietStretch) presses")
        print("  news per season \(r.newsPerSeason) · bids/offers mentioned \(r.offersIn) · signings \(r.signings) · lots won \(r.lotsWon)")
        print("  objectives \(r.objectives) · Manager of the Month ×\(r.monthAwards)")
        print("  bank (Cr) \(r.bank) · avg AI bank \(r.aiBank)")
        print("  XI strength \(r.squadRatingStart) → \(r.squadRatingEnd) · AI XIs now \(r.aiStrength) · AI paid deals in recent news \(r.aiDeals)")
    }
}
