import Foundation

/// Per-club career data that the quick-game `Franchise` doesn't carry.
struct ClubInfo: Codable, Hashable, Identifiable {
    let id: Int
    /// The home ground's surface: home league matches are played on it.
    var homePitch: Pitch
    var titles = 0
}

enum CareerPhase: String, Codable {
    /// League and playoffs in progress.
    case season
    /// Final played: review the season, then roll over.
    case seasonEnd
    /// Between seasons: retentions (mega-auction years), the auction, then the transfer window.
    case offseason
}

struct AwardLine: Codable, Hashable {
    let playerId: String
    let name: String
    let teamId: Int
    let value: String
}

/// One finished season, kept for the club history screen.
struct SeasonRecord: Codable, Hashable, Identifiable {
    var id: Int { year }
    let year: Int
    let championId: Int
    let runnerUpId: Int
    /// The user's league position (1-based) and how far they went.
    let userPosition: Int
    let userFinish: String
    let orangeCap: AwardLine?
    let purpleCap: AwardLine?
    let mvp: AwardLine?
}

struct NewsItem: Codable, Hashable, Identifiable {
    enum Kind: String, Codable { case result, milestone, squad, season, info }
    let id: Int
    let year: Int
    let day: Int
    let kind: Kind
    let text: String
}

struct CareerFlags: Codable, Hashable {
    /// Start with retired IPL legends in the pool (fantasy start).
    var legendsEra = false
}

/// The whole career save. A pure value type: every rule lives here or in the engines, so the
/// career can be unit-tested and simulated headlessly.
struct Career: Codable {
    static let currentSchema = 15
    static let maxNews = 80

    var schemaVersion = Career.currentSchema
    var managerName: String
    var userClubId: Int
    var startYear: Int
    var year: Int
    var phase: CareerPhase = .season
    var rules: Rules
    var tuning: CareerTuning
    var flags: CareerFlags
    var clubs: [Franchise]
    var clubInfo: [ClubInfo]
    var players: [String: CareerPlayer]
    var fixtures: [Fixture] = []
    /// Fixture id → day of year.
    var fixtureDays: [Int: Int] = [:]
    var results: [MatchResult] = []
    var championId: Int? = nil
    var history: [SeasonRecord] = []
    var news: [NewsItem] = []
    var nextPlayerId: Int
    var nextNewsId = 1
    var rng: SeededRNG
    // Schema 2 (M2): money, the transfer market and the off-season.
    /// Indexed by club id.
    var finance: [ClubFinance] = []
    var market = MarketState()
    var offseason: OffseasonState? = nil
    // Schema 3 (M3): training, scouting, the youth academy.
    var training = TrainingPlan()
    var scouting = ScoutingState()
    /// The user's academy (player ids).
    var academy: [String] = []
    // Schema 4 (M4): facilities, the manager, gold.
    var facilities = FacilityState()
    var manager = ManagerProfile()
    var gold = 0
    var trainingBoostWeeks = 0
    // Schema 5 (M5): international cricket.
    var intl = InternationalState()
    // Schema 6 (M6): match-day tactics.
    var tactics = Tactics()
    // Schema 8: difficulty and test switches.
    var settings = CareerSettings()
    // Schema 9: weekly training session and the season's money by category.
    var trainingDoneThisWeek = false
    var seasonMoney: [String: Int] = [:]
    /// Schema 10: season objectives, board confidence, monthly awards.
    var board = BoardState()
    /// Schema 14: the squad planner's depth chart (optional: nil until the manager opens it).
    var plan: SquadPlan? = nil
    /// Schema 15: the last month (year × 12 + month) the main sponsor paid for.
    var sponsorMonthPaid: Int? = nil

    /// Home grounds, by franchise template order.
    static let homePitches: [Pitch] = [.indianFlat, .dustyTurner, .indianFlat, .caribbeanSlow, .englishSeam,
                                       .aussieBounce, .indianFlat, .dustyTurner, .caribbeanSlow, .aussieBounce]

    // MARK: - New career

    /// - curated: the hand-picked players (players.json); born: birth year by player id.
    static func new(managerName: String, clubIndex: Int, seed: UInt64, year: Int, curated: [Player],
                    born: [String: Int], tuning: CareerTuning = .standard, flags: CareerFlags = CareerFlags()) -> Career {
        var rng = SeededRNG(seed: seed)
        var players: [String: CareerPlayer] = [:]
        for p in curated where flags.legendsEra || !p.legend {
            let b = born[p.id] ?? (year - 27)
            let age = year - b
            let headroom = age <= 21 ? Int.random(in: 5...12, using: &rng)
                : (age <= 24 ? Int.random(in: 2...7, using: &rng) : (age <= 27 ? Int.random(in: 0...3, using: &rng) : 0))
            let attr = Attributes.seeded(bat: p.bat, bowl: p.bowl, keeper: p.role == .WK, traits: p.traits, rng: &rng)
            var cp = CareerPlayer(id: p.id, name: p.name, country: p.country, role: p.role, bowlType: p.bowlType,
                                  slot: p.slot, traits: p.traits, born: b, attr: attr, potential: 0,
                                  legend: p.legend, generated: false, line: p.line, clubId: nil)
            cp.potential = min(99, max(cp.bat, cp.bowl) + headroom)
            players[p.id] = cp
        }
        let taken = Set(players.values.map(\.name))
        for p in PlayerGen.depth(count: tuning.depthPlayers, year: year, startId: 1, taken: taken, tuning: tuning, rng: &rng) {
            players[p.id] = p
        }

        var rules = Rules()
        rules.purse = 12_000
        rules.minSquad = tuning.minSquad
        rules.maxSquad = tuning.maxSquad
        rules.maxOverseasSquad = tuning.maxOverseasSquad
        rules.maxOverseasXI = tuning.maxOverseasXI

        let clubs = FranchiseTemplate.all.enumerated().map { i, t in
            Franchise(id: i, name: t.name, short: t.short, colorHex: t.color, isCPU: i != clubIndex,
                      purse: rules.purse, personality: [0.9, 1.0, 1.1, 1.2, 0.95, 1.05, 1.15, 0.85, 1.0, 1.1][i])
        }
        let info = clubs.map { ClubInfo(id: $0.id, homePitch: homePitches[$0.id % homePitches.count]) }

        var c = Career(managerName: managerName, userClubId: clubIndex, startYear: year, year: year,
                       rules: rules, tuning: tuning, flags: flags, clubs: clubs, clubInfo: info,
                       players: players, nextPlayerId: tuning.depthPlayers + 1, rng: rng)
        c.draftSquads()
        c.balanceDraft()
        c.finance = c.clubs.map { _ in ClubFinance(bank: tuning.startingBank) }
        c.assignDraftContracts()
        for i in c.clubs.indices { c.autoPickXI(clubIndex: i) }
        c.facilities.levels = Dictionary(uniqueKeysWithValues: FacilityKind.allCases.map { ($0.rawValue, tuning.aiFacilityLevel) })
        c.gold = tuning.startingGold
        c.scouting.scouts = [Scout(id: 0, name: "Chief scout", stars: 2, wage: tuning.scoutWage * 2)]
        c.refreshScoutCandidates()
        _ = c.academyIntake()
        c.setUpInternational()
        c.generateJobOffers()
        c.startSeason()
        c.addNews(.info, "\(managerName) takes charge of \(c.clubs[clubIndex].name). The \(year) season starts on \(CareerCalendar.label(c.tuning.roundDays.first ?? 10)).")
        return c
    }

    /// Balanced snake draft so every club starts with a fair squad of `startSquad`.
    /// After the opening draft: swap same-role players between the strongest and weakest XIs until
    /// every XI is within `draftBalance` points (panel: CHE started 3 below the AI average, never won
    /// a title in two 20-season runs, and a CONTINUE-only manager won 18%). Deterministic.
    mutating func balanceDraft() {
        for i in clubs.indices { autoPickXI(clubIndex: i) }
        for _ in 0..<120 {
            let ranked = clubs.indices.sorted { strength(clubs[$0].id) != strength(clubs[$1].id)
                ? strength(clubs[$0].id) > strength(clubs[$1].id) : clubs[$0].id < clubs[$1].id }
            guard let hi = ranked.first, let lo = ranked.last else { return }
            let gap = strength(clubs[hi].id) - strength(clubs[lo].id)
            guard gap > tuning.draftBalance else { return }
            // The swap whose rating gain is closest to evening the two XIs out.
            let want = Double(gap * 11) / 2
            var best: (String, String, Double)? = nil
            for a in clubs[hi].xi.sorted().compactMap({ players[$0] }) {
                for b in clubs[lo].squad.sorted().compactMap({ players[$0] })
                    where b.role == a.role && b.overseas == a.overseas && b.rating < a.rating {
                    let miss = abs(Double(a.rating - b.rating) - want)
                    if best == nil || miss < best!.2 { best = (a.id, b.id, miss) }
                }
            }
            guard let (aId, bId, _) = best else { return }
            let (hiId, loId) = (clubs[hi].id, clubs[lo].id)
            clubs[hi].squad = clubs[hi].squad.map { $0 == aId ? bId : $0 }
            clubs[lo].squad = clubs[lo].squad.map { $0 == bId ? aId : $0 }
            players[aId]?.clubId = loId
            players[bId]?.clubId = hiId
            autoPickXI(clubIndex: hi)
            autoPickXI(clubIndex: lo)
        }
    }

    /// How far down the draft board a club looks for a player who suits its home pitch.
    static let draftShortlist = 6

    mutating func draftSquads() {
        let shape = tuning.squadShape
        let roleIndex: (Role) -> Int = { r in [Role.WK, .BAT, .AR, .BOWL].firstIndex(of: r)! }
        // Strongest first, with a little noise so drafts differ between careers.
        // (Iterate in id order: dictionary order differs between runs and would break determinism.)
        var pool = players.values.filter { $0.clubId == nil && !$0.retired }.sorted { $0.id < $1.id }
            .map { ($0.id, Double($0.rating) + rng.range(-3, 3)) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
            .map(\.0)
        let order = clubs.map(\.id).shuffled(using: &rng)
        let maxOverseas = tuning.maxOverseasSquad
        for round in 0..<tuning.startSquad {
            for cid in (round % 2 == 0 ? order : order.reversed()) {
                guard let ci = clubs.firstIndex(where: { $0.id == cid }) else { continue }
                let squad = clubs[ci].squad.compactMap { players[$0] }
                var counts = [0, 0, 0, 0]
                for p in squad { counts[roleIndex(p.role)] += 1 }
                let overseas = squad.filter(\.overseas).count
                let fits: (CareerPlayer) -> Bool = { p in
                    counts[roleIndex(p.role)] < shape[roleIndex(p.role)] && (!p.overseas || overseas < maxOverseas)
                }
                let room: (CareerPlayer) -> Bool = { p in !p.overseas || overseas < maxOverseas }
                // Of the next few who fit the shape, take the one who suits the home pitch best
                // (but every squad carries a couple of spinners and quicks for away grounds).
                let variety: (CareerPlayer) -> Double = { p in
                    guard p.role == .BOWL || p.role == .AR else { return 0 }
                    let same = squad.filter { ($0.role == .BOWL || $0.role == .AR) && $0.bowlType == p.bowlType }.count
                    return same < PitchFit.minPerBowlType ? PitchFit.varietyPoints : 0
                }
                var shortlist: [Int] = []
                for i in pool.indices where shortlist.count < Career.draftShortlist {
                    if players[pool[i]].map(fits) ?? false { shortlist.append(i) }
                }
                let suited = shortlist.max { a, b in
                    let (pa, pb) = (players[pool[a]]!, players[pool[b]]!)
                    let (sa, sb) = (pitchRating(pa, clubId: cid) + variety(pa), pitchRating(pb, clubId: cid) + variety(pb))
                    return sa != sb ? sa < sb : a > b
                }
                guard let pick = suited ?? pool.firstIndex(where: { players[$0].map(room) ?? false }) else { continue }
                let id = pool.remove(at: pick)
                sign(id, to: ci)
            }
        }
    }

    /// Adds a player to a club. With a wage, also writes a contract to the next mega auction.
    mutating func sign(_ playerId: String, to clubIndex: Int, wage: Int? = nil) {
        players[playerId]?.clubId = clubs[clubIndex].id
        clubs[clubIndex].squad.append(playerId)
        if let wage {
            let until = nextMegaYear(after: year)
            players[playerId]?.contract = Contract(wage: wage, until: until)
        }
    }

    /// Hands a club to the user (the setup screen drafts first, then lets the user pick a club).
    mutating func takeCharge(clubId: Int, managerName: String) {
        guard clubs.contains(where: { $0.id == clubId }) else { return }
        userClubId = clubId
        self.managerName = managerName
        for i in clubs.indices { clubs[i].isCPU = clubs[i].id != clubId }
        news = []
        if !fixtures.isEmpty { setObjectives() }
        announceRetirementWatch()
        addNews(.info, "\(managerName) takes charge of \(userClub.name). The \(year) season starts on \(CareerCalendar.label(tuning.roundDays.first ?? 10)).")
    }

    // MARK: - Lookups

    var userClub: Franchise { clubs[userClubIndex] }
    var userClubIndex: Int { clubs.firstIndex { $0.id == userClubId } ?? 0 }
    func club(_ id: Int) -> Franchise? { clubs.first { $0.id == id } }
    func info(_ id: Int) -> ClubInfo? { clubInfo.first { $0.id == id } }

    /// Match-engine player (form applied).
    func player(_ id: String) -> Player? { players[id]?.matchPlayer() }

    func squad(_ clubId: Int) -> [CareerPlayer] {
        club(clubId)?.squad.compactMap { players[$0] } ?? []
    }

    var freeAgents: [CareerPlayer] {
        players.values.filter { $0.clubId == nil && !$0.retired && $0.academyOf == nil }
            .sorted { $0.rating != $1.rating ? $0.rating > $1.rating : $0.id < $1.id }
    }

    /// Average rating of the best XI's main skills.
    func strength(_ clubId: Int) -> Int {
        guard let c = club(clubId) else { return 0 }
        let xi = c.xi.compactMap { players[$0] }
        guard !xi.isEmpty else { return 0 }
        return xi.map { max($0.bat, $0.bowl) }.reduce(0, +) / xi.count
    }

    var table: [TableRow] { SeasonEngine.table(teamIds: clubs.map(\.id), results: results) }
    var leagueFixtures: [Fixture] { fixtures.filter { $0.stage == .league } }
    var nextFixture: Fixture? { fixtures.first { !$0.played } }
    var nextUserFixture: Fixture? { fixtures.first { !$0.played && $0.involves(userClubId) } }
    var leaguePlayed: Int { results.filter { $0.stage == .league }.count }
    func day(of fixture: Fixture) -> Int { fixtureDays[fixture.id] ?? 0 }

    /// "Today": the next fixture's day, or early December in the off-season.
    var currentDay: Int {
        if phase == .seasonEnd { return 335 }
        return nextFixture.map { day(of: $0) } ?? 335
    }

    func result(_ id: UUID?) -> MatchResult? {
        guard let id else { return nil }
        return results.first { $0.id == id } ?? intl.results.first { $0.id == id }
    }

    /// A fixture's result if it has been played (club or international).
    func playedResult(fixtureId: Int) -> MatchResult? {
        let f = fixtureId >= Career.intlIdBase ? intl.fixtures.first { $0.id == fixtureId } : fixtures.first { $0.id == fixtureId }
        return result(f?.resultId)
    }

    /// Club or nation by team id (nations use ids from 100).
    func team(_ id: Int) -> Franchise? { club(id) ?? nationTeam(id) }

    func isUserFixture(_ f: Fixture) -> Bool { f.involves(userClubId) }

    /// 1-based league round of a fixture ("Round 7"), or nil for playoffs.
    func round(of f: Fixture) -> Int? {
        guard f.stage == .league else { return nil }
        let perRound = max(1, clubs.count / 2)
        return (f.id - 1) / perRound + 1
    }

    var totalRounds: Int { leagueFixtures.count / max(1, clubs.count / 2) }

    /// League position, 1-based.
    func position(of clubId: Int) -> Int { (table.firstIndex { $0.teamId == clubId } ?? clubs.count - 1) + 1 }

    /// The user's recent results, oldest first (true = won).
    func userForm(last n: Int = 5) -> [Bool] {
        Array(results.filter { $0.teamA == userClubId || $0.teamB == userClubId }.suffix(n).map { $0.winnerId == userClubId })
    }

    /// The user's fixtures in date order.
    var userFixtures: [Fixture] { fixtures.filter(isUserFixture) }

    // MARK: - Season

    mutating func startSeason() {
        seasonMoney = [:]
        trainingDoneThisWeek = false
        fixtures = []
        fixtureDays = [:]
        results = []
        championId = nil
        phase = .season
        let ids = clubs.map(\.id)
        var pairs: [(Int, Int)] = []
        for _ in 0..<(tuning.meetings / 2) {
            pairs += SeasonEngine.leagueFixtures(teamIds: ids, double: true, rng: &rng).map { ($0.home, $0.away) }
        }
        if tuning.meetings % 2 == 1 {
            pairs += SeasonEngine.leagueFixtures(teamIds: ids, double: false, rng: &rng).map { ($0.home, $0.away) }
        }
        let perRound = max(1, ids.count / 2)
        let days = tuning.roundDays
        for (i, pair) in pairs.enumerated() {
            let round = i / perRound
            let day = round < days.count ? days[round] : (days.last ?? 300) + (round - days.count + 1) * 2
            let f = Fixture(id: i + 1, home: pair.0, away: pair.1, stage: .league,
                            pitch: info(pair.0)?.homePitch ?? .indianFlat)
            fixtures.append(f)
            fixtureDays[f.id] = min(day, 310)
        }
        for k in players.keys {
            players[k]?.form = 0
            let r = players[k]?.rating
            players[k]?.seasonStartRating = r
        }
        setObjectives()
        announceRetirementWatch()
    }

    /// Picks the XI from the squad (AI clubs before every match; the user's when theirs is invalid).
    /// With a pitch (match day), the XI is picked for that surface.
    mutating func autoPickXI(clubIndex ci: Int, pitch: Pitch? = nil) {
        let squad = clubs[ci].squad.compactMap { player($0) }
        clubs[ci].xi = TeamSelector.autoXI(squad: squad, rules: rules, pitch: pitch)
        if clubs[ci].isCPU { clubs[ci].bowlingOrder = [] }
    }

    /// Problems with a club's chosen XI (empty = valid).
    func xiIssues(_ clubId: Int) -> [String] {
        guard let c = club(clubId) else { return ["No club"] }
        let xi = c.xi.compactMap { player($0) }
        var issues = TeamSelector.blockingIssues(xi, rules: rules)
        if Set(c.xi).count != c.xi.count { issues.append("A player is picked twice") }
        if !c.xi.allSatisfy({ c.squad.contains($0) }) { issues.append("A picked player has left the squad") }
        return issues
    }

    mutating func setXI(clubId: Int, ids: [String]) {
        guard let i = clubs.firstIndex(where: { $0.id == clubId }) else { return }
        clubs[i].xi = ids
        // Keep the bowling plan only if all five are still in the XI.
        if !clubs[i].bowlingOrder.allSatisfy({ ids.contains($0) }) { clubs[i].bowlingOrder = [] }
    }

    /// Squad screen drag or tap: `a` onto `b`. Two XI players swap batting places; a bench player
    /// onto an XI player (either way round) takes his place in the order. Returns why it was
    /// refused (e.g. too many overseas), or nil when done. A manual pick: the assistant stops picking.
    @discardableResult
    mutating func swapLineup(_ a: String, _ b: String) -> String? {
        guard a != b, let ci = clubs.firstIndex(where: { $0.id == userClubId }) else { return nil }
        let club = clubs[ci]
        guard club.squad.contains(a), club.squad.contains(b) else { return "Only your own players." }
        var xi = club.xi
        switch (xi.firstIndex(of: a), xi.firstIndex(of: b)) {
        case let (i?, j?): xi.swapAt(i, j)
        case let (i?, nil): xi[i] = b
        case let (nil, j?): xi[j] = a
        case (nil, nil): return "Drag a bench player onto someone in the XI."
        }
        let issues = TeamSelector.blockingIssues(xi.compactMap { player($0) }, rules: rules)
        if let first = issues.first { return first }
        setXI(clubId: userClubId, ids: xi)
        settings.assistantPicksXI = false
        return nil
    }

    mutating func setBowlingOrder(clubId: Int, ids: [String]) {
        guard let i = clubs.firstIndex(where: { $0.id == clubId }) else { return }
        clubs[i].bowlingOrder = ids.count == 5 ? ids : []
    }

    /// The player as the match engine sees them (form plus the career batting calibration).
    func enginePlayer(_ id: String, pitch: Pitch? = nil) -> Player? {
        players[id]?.matchPlayer(batBoost: tuning.engineBatBoost + pitchBoost(pitch))
    }

    /// The pitch's extra batting calibration (career only; the quick game is untouched).
    func pitchBoost(_ pitch: Pitch?) -> Int {
        guard let pitch, let i = Pitch.allCases.firstIndex(of: pitch), i < tuning.pitchBatBoost.count else { return 0 }
        return tuning.pitchBatBoost[i]
    }

    func side(_ clubId: Int, fixture: Fixture? = nil) -> MatchEngine.Side {
        let c = club(clubId)!
        var ids = c.xi
        if !xiIssues(clubId).isEmpty {
            ids = TeamSelector.autoXI(squad: c.squad.compactMap { player($0) }, rules: rules)
        }
        var xi = ids.compactMap { enginePlayer($0, pitch: fixture?.pitch) }
        var plan = c.bowlingOrder.compactMap { enginePlayer($0, pitch: fixture?.pitch) }
        if clubId == userClubId {
            // Perks and the Analytics Room lift the user's players a little.
            let attackIds = (plan.count == 5 ? plan : MatchEngine.autoAttack(xi, pitch: fixture?.pitch)).map(\.id)
            let boosted = xi.enumerated().map { i, p -> Player in
                let b = userBoost(for: p, position: i, attackSlot: attackIds.firstIndex(of: p.id), fixture: fixture)
                return p.adjusted(bat: b.bat, bowl: b.bowl)
            }
            let byId = Dictionary(uniqueKeysWithValues: boosted.map { ($0.id, $0) })
            xi = boosted
            plan = plan.compactMap { byId[$0.id] }
        }
        let attack = plan.count == 5 && Set(plan.map(\.id)).count == 5 && plan.allSatisfy { ids.contains($0.id) } ? plan : nil
        return MatchEngine.Side(teamId: clubId, xi: xi, attack: attack, tactics: clubId == userClubId ? tactics : nil)
    }

    /// Plays one fixture. Returns the result and the ball log (for the live view).
    @discardableResult
    mutating func play(fixtureId: Int, changes: [LiveChange] = []) -> (MatchResult, [BallEvent])? {
        if fixtureId >= Career.intlIdBase { return playIntl(fixtureId, changes: changes) }
        guard phase == .season, pendingWindow == nil,
              let fi = fixtures.firstIndex(where: { $0.id == fixtureId }), !fixtures[fi].played else { return nil }
        let f = fixtures[fi]
        prepareSides(f)
        let (r, log, after) = simulate(f, changes: changes)
        rng = after
        results.append(r)
        fixtures[fi].resultId = r.id
        record(r)
        checkMonthEnd(after: f)
        assistantAfterMatch(r)
        defer { marketTick() }

        if f.stage == .final {
            championId = r.winnerId
            finishSeason()
        } else if nextFixture == nil {
            let playoffResults = results.filter { $0.stage != .league }
            if var next = SeasonEngine.nextPlayoff(table: table, playoffResults: playoffResults, nextId: fixtures.count + 1) {
                next.pitch = Pitch.allCases.randomElement(using: &rng) ?? .indianFlat
                fixtures.append(next)
                let stageIndex = [Stage.qualifier1, .eliminator, .qualifier2, .final].firstIndex(of: next.stage) ?? 0
                fixtureDays[next.id] = tuning.playoffDays[min(stageIndex, tuning.playoffDays.count - 1)]
                if next.stage == .qualifier1 {
                    let top4 = table.prefix(4).compactMap { club($0.teamId)?.short }.joined(separator: ", ")
                    addNews(.season, "League stage over. Playoffs: \(top4).")
                }
            }
        }
        return (r, log)
    }

    /// AI clubs (and an invalid user XI) pick their XI before a match.
    mutating func prepareSides(_ f: Fixture) {
        for tid in [f.home, f.away] {
            let assistant = tid == userClubId && settings.assistantPicksXI
            if let ci = clubs.firstIndex(where: { $0.id == tid }), clubs[ci].isCPU || assistant || !xiIssues(tid).isEmpty {
                autoPickXI(clubIndex: ci, pitch: f.pitch)
            }
        }
    }

    /// Runs the match engine for a club fixture without recording anything.
    func simulate(_ f: Fixture, changes: [LiveChange]) -> (MatchResult, [BallEvent], SeededRNG) {
        var engine = MatchEngine(rng: rng)
        engine.liveChanges = changes
        engine.realisticChase = true
        var log: [BallEvent] = []
        let r = engine.play(side(f.home, fixture: f), side(f.away, fixture: f), stage: f.stage, pitch: f.pitch, log: &log)
        return (r, log, engine.rng)
    }

    /// The match as it would play with these live changes, without recording it (the live view
    /// shows this, then `play(fixtureId:changes:)` commits the identical match at the end).
    func previewMatch(fixtureId: Int, changes: [LiveChange]) -> (MatchResult, [BallEvent])? {
        if fixtureId >= Career.intlIdBase {
            guard let f = intl.fixtures.first(where: { $0.id == fixtureId }), !f.played else { return nil }
            let (r, log, _) = simulateIntl(f, changes: changes)
            return (r, log)
        }
        guard phase == .season, pendingWindow == nil,
              let f = fixtures.first(where: { $0.id == fixtureId }), !f.played else { return nil }
        var copy = self
        copy.prepareSides(f)
        let (r, log, _) = copy.simulate(f, changes: changes)
        return (r, log)
    }

    /// The other matches of a fixture's round (same day), for the match centre's "Around the league":
    /// those already played (CONTINUE sims them before the user's match) and those still to come.
    func roundResults(around fixtureId: Int) -> [MatchResult] {
        roundFixtures(around: fixtureId).filter(\.played).compactMap { result($0.resultId) }
    }

    func roundFixtures(around fixtureId: Int) -> [Fixture] {
        guard let f = fixtures.first(where: { $0.id == fixtureId }), let day = fixtureDays[f.id] else { return [] }
        return fixtures.filter { $0.id != fixtureId && fixtureDays[$0.id] == day }.sorted { $0.id < $1.id }
    }

    /// The user's team in a fixture (club or national side), if they're playing.
    func userTeam(in fixtureId: Int) -> Int? {
        if fixtureId >= Career.intlIdBase {
            guard let f = intl.fixtures.first(where: { $0.id == fixtureId }), isUserNationFixture(f), let job = intl.job else { return nil }
            return nationTeamId(job)
        }
        guard let f = fixtures.first(where: { $0.id == fixtureId }), isUserFixture(f) else { return nil }
        return userClubId
    }

    /// Simulates every fixture before the user's next match. Returns how many were played.
    @discardableResult
    mutating func simUntilUserMatch() -> Int {
        var n = 0
        while phase == .season, n < 1000 {
            if pendingWindow != nil {
                // International window: play it out, stopping before the user's nation plays.
                n += simWindow(stopAtUser: true)
                if pendingWindow != nil { break }
                continue
            }
            guard let f = nextFixture, !isUserFixture(f) else { break }
            play(fixtureId: f.id)
            n += 1
        }
        return n
    }

    /// Quick-sims the rest of the season, the user's matches included.
    mutating func simToSeasonEnd() {
        var guardCount = 0
        while phase == .season, guardCount < 2000 {
            if pendingWindow != nil {
                simWindow(stopAtUser: false)
                guardCount += 1
                continue
            }
            guard let f = nextFixture else { break }
            play(fixtureId: f.id)
            guardCount += 1
        }
    }

    // MARK: Per-match bookkeeping

    private mutating func record(_ r: MatchResult) {
        var delta: [String: Int] = [:]
        var played = Set<String>()
        for inn in r.innings.prefix(2) {
            for (pos, b) in inn.batters.enumerated() {
                played.insert(b.id)
                guard b.batted else { continue }
                var d = 0
                // Only the top six lose form for a cheap dismissal: a No. 9 out for 4 is normal, and
                // punishing it sent weak sides into a form spiral (panel: 42 defeats in a row).
                if b.runs >= 50 { d = 4 } else if b.runs >= 30 { d = 2 } else if pos < 6 && b.dismissal != nil && b.runs < 10 { d = -2 }
                delta[b.id, default: 0] += d
                players[b.id]?.stats.runs += b.runs
                players[b.id]?.stats.ballsFaced += b.balls
                players[b.id]?.stats.fours += b.fours
                players[b.id]?.stats.sixes += b.sixes
                if b.runs >= 100 { players[b.id]?.stats.hundreds += 1 } else if b.runs >= 50 { players[b.id]?.stats.fifties += 1 }
                if let p = players[b.id], b.runs > p.stats.highScore { players[b.id]?.stats.highScore = b.runs }
            }
            for bw in inn.bowlers where bw.balls > 0 {
                var d = 0
                if bw.wickets >= 3 { d = 4 } else if bw.wickets == 2 { d = 2 }
                if bw.balls >= 12 && bw.economy > 10.5 { d -= 2 } else if bw.balls >= 18 && bw.economy < 6.5 { d += 1 }
                delta[bw.id, default: 0] += d
                players[bw.id]?.stats.wickets += bw.wickets
                players[bw.id]?.stats.ballsBowled += bw.balls
                players[bw.id]?.stats.runsConceded += bw.runs
            }
        }
        players[r.potmId]?.stats.potm += 1
        if r.teamA == userClubId || r.teamB == userClubId {
            // Training runs after the match unless the user already ran this week's session.
            if trainingDoneThisWeek { trainingDoneThisWeek = false } else { trainingTick() }
            let week = results.filter { $0.teamA == userClubId || $0.teamB == userClubId }.count
            if week % max(1, tuning.scoutReportEveryWeeks) == 0 { scoutTick() }
            weeklyIncome(after: r)
            facilityTick()
            gold += tuning.goldPerMatch
            if r.winnerId == userClubId { gainXP(r.stage == .league ? 20 : 40, reason: nil) }
            if manager.has(.settledSide) {
                for id in userClub.squad { if let f = players[id]?.form, f < -4 { players[id]?.form = -4 } }
            }
        }
        let cap = tuning.formCap
        for id in played.sorted() {
            guard var p = players[id] else { continue }
            p.stats.matches += 1
            let decay = p.form > 0 ? -tuning.formDecay : (p.form < 0 ? tuning.formDecay : 0)
            p.form = max(-cap, min(cap, p.form + decay + (delta[id] ?? 0)))
            players[id] = p
        }

        // News for the user's matches and big milestones.
        if r.teamA == userClubId || r.teamB == userClubId {
            let opp = club(r.teamA == userClubId ? r.teamB : r.teamA)?.short ?? ""
            let won = r.winnerId == userClubId
            let stage = r.stage == .league ? "" : "\(r.stage.label): "
            addNews(.result, "\(stage)\(won ? "Won" : "Lost") vs \(opp) — \(club(r.winnerId)?.short ?? "") \(r.margin). Player of the match: \(r.potmName).")
        }
        for inn in r.innings.prefix(2) {
            for b in inn.batters where b.runs >= 100 {
                addNews(.milestone, "💯 \(b.name) hits \(b.runs) off \(b.balls) for \(club(inn.teamId)?.short ?? "").")
            }
        }
    }

    mutating func addNews(_ kind: NewsItem.Kind, _ text: String) {
        news.insert(NewsItem(id: nextNewsId, year: year, day: currentDay, kind: kind, text: text), at: 0)
        nextNewsId += 1
        if news.count > Career.maxNews { news.removeLast(news.count - Career.maxNews) }
    }

    // MARK: - Season end

    /// The user's furthest stage this season.
    func userFinish() -> String {
        if championId == userClubId { return "Champions" }
        let mine = results.filter { $0.stage != .league && ($0.teamA == userClubId || $0.teamB == userClubId) }
        if let final = mine.first(where: { $0.stage == .final }), final.loserId == userClubId { return "Runners-up" }
        if let last = mine.last, last.loserId == userClubId { return "Out in \(last.stage.label)" }
        let pos = (table.firstIndex { $0.teamId == userClubId } ?? 9) + 1
        return "League stage (\(Career.ordinal(pos)))"
    }

    static func ordinal(_ n: Int) -> String {
        let suffix = (11...13).contains(n % 100) ? "th" : (["th", "st", "nd", "rd"] + Array(repeating: "th", count: 6))[n % 10]
        return "\(n)\(suffix)"
    }

    private mutating func finishSeason() {
        guard let champ = championId else { return }
        let final = results.first { $0.stage == .final }
        let stats = SeasonEngine.playerStats(results: results).values.sorted { $0.id < $1.id }
        func line(_ s: PlayerSeason?, _ value: (PlayerSeason) -> String) -> AwardLine? {
            guard let s, let p = players[s.id] else { return nil }
            return AwardLine(playerId: s.id, name: p.name, teamId: s.teamId, value: value(s))
        }
        let orange = stats.max { ($0.runs, -$0.ballsFaced) < ($1.runs, -$1.ballsFaced) }
        let purple = stats.max { ($0.wickets, -$0.economy) < ($1.wickets, -$1.economy) }
        let mvp = stats.max { $0.mvpPoints < $1.mvpPoints }
        let pos = (table.firstIndex { $0.teamId == userClubId } ?? 9) + 1
        history.append(SeasonRecord(year: year, championId: champ, runnerUpId: final?.loserId ?? champ,
                                    userPosition: pos, userFinish: userFinish(),
                                    orangeCap: line(orange) { "\($0.runs) runs" },
                                    purpleCap: line(purple) { "\($0.wickets) wickets" },
                                    mvp: line(mvp) { "\(Int($0.mvpPoints)) pts" }))
        if let i = clubInfo.firstIndex(where: { $0.id == champ }) { clubInfo[i].titles += 1 }
        archiveSeasonStats()
        payPrizeMoney()
        if champ == userClubId {
            gainXP(300, reason: nil)
            gold += tuning.goldForTitle
        } else if results.contains(where: { $0.stage != .league && ($0.teamA == userClubId || $0.teamB == userClubId) }) {
            gainXP(100, reason: nil)
        }
        for id in club(champ)?.squad ?? [] { players[id]?.stats.titles += 1 }
        phase = .seasonEnd
        let name = club(champ)?.name ?? ""
        addNews(.season, champ == userClubId ? "🏆 CHAMPIONS! \(name) win the \(year) title!" : "🏆 \(name) are the \(year) champions.")
        judgeObjectives()
    }

    // MARK: - Rollover

    struct RolloverReport {
        var retired: [String] = []
        var userRetired: [String] = []
        var signed: [String] = []
        var bigRisers: [String] = []
        var youth = 0
        var academy: [String] = []
    }

    /// Runs the whole off-season automatically (headless sims and tests): the user keeps their best
    /// players at a mega auction and doesn't bid. The app walks through the same steps one by one.
    @discardableResult
    mutating func startNextSeason() -> RolloverReport {
        guard phase == .seasonEnd else { return RolloverReport() }
        var report = beginOffseason()
        if offseason?.stage == .retention {
            confirmRetention(userKeeps: suggestedRetentions())
        }
        simRestOfAuction(autoBid: true)
        report.signed += startSeasonFromOffseason()
        return report
    }

    /// Old one-step rollover, kept for reference by `beginOffseason`: ages, develops and retires,
    /// adds the youth intake.
    mutating func ageAndRefreshPool() -> RolloverReport {
        year += 1
        var report = develop()
        let taken = Set(players.values.map(\.name))
        let intake = PlayerGen.youth(count: tuning.youthIntake, year: year, startId: nextPlayerId, taken: taken,
                                     tuning: tuning, rng: &rng)
        for p in intake { players[p.id] = p }
        nextPlayerId += intake.count
        report.youth = intake.count
        addNews(.season, "Off-season \(year): \(report.retired.count) players retired, \(report.youth) youngsters entered the pool.")
        if !report.userRetired.isEmpty {
            addNews(.squad, "Retired from your squad: \(report.userRetired.joined(separator: ", ")).")
        }
        return report
    }

    /// Yearly development, ageing and retirement.
    /// Chance a player retires at this age (the retirement watch uses the same rule).
    func retireChance(_ p: CareerPlayer, age: Int) -> Double {
        let paceBowler = !p.primaryIsBat && p.bowlType == .pace
        let threshold = tuning.retireAge - (paceBowler ? tuning.paceRetireOffset : 0)
        var chance = 0.0
        if age >= threshold { chance = tuning.retireBase + tuning.retirePerYear * Double(age - threshold) }
        if age >= 31 && p.rating < tuning.weakVeteranRating { chance = max(chance, 0.5) }
        return chance
    }

    mutating func develop() -> RolloverReport {
        var report = RolloverReport()
        for id in players.keys.sorted() {
            guard var p = players[id], !p.retired else { continue }
            let age = p.age(in: year)
            var gain = Int.random(in: tuning.growthRange(age: age), using: &rng)
            let main = max(p.bat, p.bowl)
            if gain > 0 { gain = min(gain, max(0, p.potential - main)) }
            let mine = p.clubId == userClubId
            if mine && gain < 0 && age >= 30 && manager.has(.veteranCare) { gain += 1 }
            if gain != 0 {
                if p.role == .AR {
                    p.attr.shift(Attributes.batKeys, by: gain)
                    p.attr.shift(Attributes.bowlKeys, by: gain)
                } else if p.primaryIsBat {
                    p.attr.shift(Attributes.batKeys, by: gain)
                } else {
                    p.attr.shift(Attributes.bowlKeys, by: gain)
                }
                if gain < 0 { p.attr.fielding = Attributes.clamp(p.attr.fielding + gain / 2) }
            }
            if gain >= 4 && p.clubId == userClubId { report.bigRisers.append(p.name) }
            p.form = 0

            // Retirement.
            var chance = retireChance(p, age: age)
            // Unsigned journeymen drift out of the game.
            let unsigned = p.clubId == nil && p.generated && p.academyOf == nil
            if unsigned && age >= 26 && (p.rating < 50 || age >= 30) { chance = max(chance, 0.6) }
            if unsigned && age >= 22 && p.potential < 68 { chance = max(chance, 0.4) }
            if p.academyOf != nil { chance = 0 }
            if mine {
                chance *= 1 - 0.04 * Double(facility(.medical) - 1)
                if manager.has(.ironBody) { chance *= 0.8 }
            }
            if age >= 41 { chance = 1 }
            if chance > 0 && rng.unit() < chance {
                p.retired = true
                if let cid = p.clubId, let ci = clubs.firstIndex(where: { $0.id == cid }) {
                    clubs[ci].squad.removeAll { $0 == id }
                    clubs[ci].xi.removeAll { $0 == id }
                    clubs[ci].bowlingOrder.removeAll { $0 == id }
                    if cid == userClubId { report.userRetired.append(p.name) }
                    players[id] = p
                    patchXI(clubId: cid)
                }
                p.clubId = nil
                p.contract = nil
                report.retired.append(p.name)
                if p.rating >= 75 && !p.generated {
                    addNews(.squad, "\(p.name) retires at \(age) after \(p.stats.matches) matches and \(p.stats.runs) runs, \(p.stats.wickets) wickets.")
                }
            }
            players[id] = p
        }
        // Forget retired players nobody will look up again.
        for id in players.keys.sorted() {
            if let p = players[id], p.retired, p.generated, p.stats.matches < 30 { players[id] = nil }
        }
        return report
    }

    /// Fills every squad back up to the minimum from the free-agent pool.
    /// Returns "Name → CLUB" lines for the user's club.
    mutating func topUpSquads() -> [String] {
        var signedForUser: [String] = []
        let roles: [Role] = [.WK, .BAT, .AR, .BOWL]
        for ci in clubs.indices {
            while clubs[ci].squad.count < tuning.minSquad {
                let squad = clubs[ci].squad.compactMap { players[$0] }
                let overseas = squad.filter(\.overseas).count
                // Role furthest below the starting shape.
                let deficits = roles.enumerated().map { i, r in
                    (r, Double(tuning.squadShape[i]) - Double(squad.filter { $0.role == r }.count))
                }
                let need = deficits.max { $0.1 < $1.1 }?.0 ?? .BOWL
                let room = capRoom(clubs[ci].id)
                let free = freeAgents.filter {
                    (!$0.overseas || overseas < tuning.maxOverseasSquad) && wageDemand($0) <= room
                }
                // Cheapest decent option: best rating among those asking the least.
                guard let pick = free.first(where: { $0.role == need }) ?? free.first
                        ?? freeAgents.filter({ !$0.overseas || overseas < tuning.maxOverseasSquad }).last else { break }
                sign(pick.id, to: ci, wage: min(wageDemand(pick), max(tuning.minWage, room)))
                if clubs[ci].id == userClubId { signedForUser.append(pick.name) }
            }
        }
        if !signedForUser.isEmpty {
            addNews(.squad, "The board signed free agents to fill your squad: \(signedForUser.joined(separator: ", ")).")
        }
        return signedForUser
    }
}

// MARK: - Saving

enum CareerSave {
    enum LoadError: Error { case tooNew(Int), notACareer }

    /// JSON migrations, keyed by the version they upgrade from.
    static let migrations: [Int: ([String: Any]) -> [String: Any]] = [
        // v14 → v15: monthly sponsor (an optional field) and new tuning keys (sponsorMonthly).
        14: { json in
            var j = json
            var tuning = j["tuning"] as? [String: Any] ?? [:]
            let standard = CareerSave.jsonObject(CareerTuning.standard) as? [String: Any] ?? [:]
            for (k, v) in standard where tuning[k] == nil { tuning[k] = v }
            j["tuning"] = tuning
            return j
        },
        // v13 → v14: squad planner (an optional field: nothing to convert).
        13: { json in json },
        // v12 → v13: morale and squad roles replaced by form; drop their player fields.
        12: { json in
            var j = json
            var players = j["players"] as? [String: Any] ?? [:]
            for (id, value) in players {
                guard var p = value as? [String: Any] else { continue }
                p["squadRole"] = nil; p["morale"] = nil; p["rolePromised"] = nil
                players[id] = p
            }
            j["players"] = players
            return j
        },
        // v11 → v12: squad roles and morale (optional player fields: nothing to convert; roles are
        // assigned on the next load or season start).
        11: { json in json },
        // v10 → v11: board upgrade counter, retirement watch, RTM cards; new tuning keys.
        10: { json in
            var j = json
            var board = j["board"] as? [String: Any] ?? [:]
            board["upgradesStarted"] = 0
            j["board"] = board
            // Existing careers keep picking their own XI.
            var settings = j["settings"] as? [String: Any] ?? [:]
            settings["assistantPicksXI"] = false
            j["settings"] = settings
            var tuning = j["tuning"] as? [String: Any] ?? [:]
            let standard = CareerSave.jsonObject(CareerTuning.standard) as? [String: Any] ?? [:]
            for (k, v) in standard where tuning[k] == nil { tuning[k] = v }
            j["tuning"] = tuning
            return j
        },
        // v9 → v10: board objectives and monthly awards; new tuning keys (the app reloads tuning).
        9: { json in
            var j = json
            j["board"] = CareerSave.jsonObject(BoardState())
            var tuning = j["tuning"] as? [String: Any] ?? [:]
            let standard = CareerSave.jsonObject(CareerTuning.standard) as? [String: Any] ?? [:]
            for (k, v) in standard where tuning[k] == nil { tuning[k] = v }
            j["tuning"] = tuning
            return j
        },
        // v8 → v9: training session flag, season money, ticket price.
        8: { json in
            var j = json
            j["trainingDoneThisWeek"] = false
            j["seasonMoney"] = [String: Any]()
            var settings = j["settings"] as? [String: Any] ?? [:]
            settings["ticketPrice"] = "normal"
            j["settings"] = settings
            return j
        },
        // v7 → v8: settings (difficulty, market always open).
        7: { json in
            var j = json
            j["settings"] = CareerSave.jsonObject(CareerSettings())
            return j
        },
        // v6 → v7: players' season logs (an optional field: nothing to convert).
        6: { json in json },
        // v5 → v6: tactics.
        5: { json in
            var j = json
            j["tactics"] = CareerSave.jsonObject(Tactics())
            return j
        },
        // v4 → v5: international cricket (nations are set up on first use).
        4: { json in
            var j = json
            j["intl"] = CareerSave.jsonObject(InternationalState())
            return j
        },
        // v3 → v4: facilities, manager, gold.
        3: { json in
            var j = json
            var f = FacilityState()
            f.levels = Dictionary(uniqueKeysWithValues: FacilityKind.allCases.map { ($0.rawValue, CareerTuning.standard.aiFacilityLevel) })
            j["facilities"] = CareerSave.jsonObject(f)
            j["manager"] = CareerSave.jsonObject(ManagerProfile())
            j["gold"] = CareerTuning.standard.startingGold
            j["trainingBoostWeeks"] = 0
            return j
        },
        // v2 → v3: training, scouting, academy.
        2: { json in
            var j = json
            j["training"] = CareerSave.jsonObject(TrainingPlan())
            j["scouting"] = CareerSave.jsonObject(ScoutingState())
            j["academy"] = [Any]()
            return j
        },
        // v1 → v2: money and the transfer market. Contracts are filled in after decoding.
        1: { json in
            var j = json
            let clubs = (j["clubs"] as? [Any])?.count ?? 10
            let bank = CareerTuning.standard.startingBank
            j["finance"] = (0..<clubs).map { _ in ["bank": bank, "ledger": [Any]()] as [String: Any] }
            j["market"] = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(MarketState()))) ?? [String: Any]()
            return j
        },
    ]

    static func encode(_ c: Career) throws -> Data { try JSONEncoder().encode(c) }

    static func jsonObject<T: Encodable>(_ v: T) -> Any {
        (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(v))) ?? [String: Any]()
    }

    static func decode(_ data: Data) throws -> Career {
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw LoadError.notACareer }
        let version = json["schemaVersion"] as? Int ?? 0
        guard version <= Career.currentSchema else { throw LoadError.tooNew(version) }
        var v = version
        while v < Career.currentSchema {
            if let m = migrations[v] { json = m(json) }
            v += 1
            json["schemaVersion"] = v
        }
        let upgraded = try JSONSerialization.data(withJSONObject: json)
        var c = try JSONDecoder().decode(Career.self, from: upgraded)
        c.repairContracts()
        return c
    }
}
