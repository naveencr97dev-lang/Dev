import Foundation

// MARK: - Types

struct Nation: Codable, Hashable, Identifiable {
    let code: String
    let name: String
    let colorHex: String
    let fullMember: Bool
    let homePitch: Pitch
    /// Ranking points (Elo-style).
    var points: Double
    var id: String { code }
}

struct IntlEvent: Codable, Hashable {
    enum Kind: String, Codable { case series, worldCup }
    var kind: Kind
    /// "2028-A": the April window of 2028.
    var key: String
    var host: String? = nil
    var groups: [[String]] = []
    var superEight: [[String]] = []
    var stage: Stage = .series
    var finished = false
    var winner: String? = nil

    var title: String {
        let year = key.prefix(4)
        return kind == .worldCup ? "\(year) T20 World Cup" : "\(year) T20I series (\(key.hasSuffix("A") ? "April" : "August"))"
    }
}

struct IntlRecord: Codable, Hashable, Identifiable {
    var id: String { key }
    let key: String
    let title: String
    let winner: String?
    let userNation: String?
    let userResult: String?
}

struct InternationalState: Codable, Hashable {
    var nations: [Nation] = []
    var fixtures: [Fixture] = []
    var days: [Int: Int] = [:]
    var results: [MatchResult] = []
    var event: IntlEvent? = nil
    var done: [String] = []
    var history: [IntlRecord] = []
    /// The user's national job (nation code), offers on the table, and the board's patience.
    var job: String? = nil
    var offers: [String] = []
    var squad: [String] = []
    var strikes = 0
    var target = ""
    var sacking = true
    var caps: [String: Int] = [:]
    var nextFixtureId = Career.intlIdBase
}

// MARK: - Engine

extension Career {
    static let intlIdBase = 10_000
    static let nationIdBase = 100

    /// code, name, colour, full member, home pitch
    static let nationList: [(String, String, String, Bool, Pitch)] = [
        ("IND", "India", "#1D4ED8", true, .indianFlat), ("AUS", "Australia", "#EAB308", true, .aussieBounce),
        ("ENG", "England", "#1E3A8A", true, .englishSeam), ("SA", "South Africa", "#15803D", true, .aussieBounce),
        ("NZ", "New Zealand", "#334155", true, .englishSeam), ("PAK", "Pakistan", "#166534", true, .dustyTurner),
        ("WI", "West Indies", "#7F1D1D", true, .caribbeanSlow), ("SL", "Sri Lanka", "#1E40AF", true, .dustyTurner),
        ("AFG", "Afghanistan", "#2563EB", true, .dustyTurner), ("BAN", "Bangladesh", "#047857", true, .dustyTurner),
        ("ZIM", "Zimbabwe", "#DC2626", true, .caribbeanSlow), ("IRE", "Ireland", "#16A34A", true, .englishSeam),
        ("NED", "Netherlands", "#F97316", false, .englishSeam), ("SCO", "Scotland", "#4338CA", false, .englishSeam),
        ("NAM", "Namibia", "#0EA5E9", false, .aussieBounce), ("USA", "USA", "#B91C1C", false, .indianFlat),
        ("UAE", "UAE", "#6B7280", false, .indianFlat), ("NEP", "Nepal", "#DB2777", false, .dustyTurner),
        ("OMA", "Oman", "#9F1239", false, .caribbeanSlow), ("CAN", "Canada", "#E11D48", false, .indianFlat),
    ]

    static let intlRules: Rules = {
        var r = Rules()
        r.maxOverseasXI = 11
        r.maxOverseasSquad = 99
        return r
    }()

    // MARK: Nations and squads

    mutating func setUpInternational() {
        if intl.nations.isEmpty {
            ensureNationalPools()
            intl.nations = Career.nationList.map { n in
                Nation(code: n.0, name: n.1, colorHex: n.2, fullMember: n.3, homePitch: n.4, points: 0)
            }
            for i in intl.nations.indices {
                intl.nations[i].points = 1000 + Double(nationStrength(intl.nations[i].code) - 60) * 15
            }
        } else {
            ensureNationalPools()
        }
    }

    /// Every nation keeps at least 16 active players (generated where real ones run out).
    mutating func ensureNationalPools() {
        var taken = Set(players.values.map(\.name))
        for n in Career.nationList {
            let have = players.values.filter { $0.country == n.0 && !$0.retired }.count
            guard have < 16 else { continue }
            for _ in have..<16 {
                let band = n.3 ? (56, 76) : (46, 66)
                let rating = Int.random(in: band.0...band.1, using: &rng)
                let age = Int.random(in: 20...32, using: &rng)
                let p = PlayerGen.make(id: "g\(nextPlayerId)", role: PlayerGen.randomRole(&rng), nation: n.0, born: year - age,
                                       rating: rating, potential: rating + Int.random(in: 0...6, using: &rng),
                                       taken: taken, tuning: tuning, rng: &rng)
                nextPlayerId += 1
                taken.insert(p.name)
                players[p.id] = p
            }
        }
    }

    func nationPlayers(_ code: String) -> [CareerPlayer] {
        players.values.filter { $0.country == code && !$0.retired && $0.academyOf == nil }
            .sorted { $0.rating != $1.rating ? $0.rating > $1.rating : $0.id < $1.id }
    }

    /// The 15-man squad: the user's pick for their nation, otherwise the best 15.
    func nationSquad(_ code: String) -> [String] {
        let pool = nationPlayers(code)
        if code == intl.job {
            let ids = Set(pool.map(\.id))
            let mine = intl.squad.filter { ids.contains($0) }
            if mine.count >= 11 { return mine }
        }
        return Array(pool.prefix(15).map(\.id))
    }

    func nationXI(_ code: String) -> [String] {
        TeamSelector.autoXI(squad: nationSquad(code).compactMap { player($0) }, rules: Career.intlRules)
    }

    func nationStrength(_ code: String) -> Int {
        let xi = TeamSelector.autoXI(squad: Array(nationPlayers(code).prefix(15)).map { $0.matchPlayer(formMatters: false) },
                                     rules: Career.intlRules).compactMap { players[$0] }
        guard !xi.isEmpty else { return 40 }
        return xi.map { max($0.bat, $0.bowl) }.reduce(0, +) / xi.count
    }

    func nationIndex(_ code: String) -> Int? { intl.nations.firstIndex { $0.code == code } }
    func nationCode(teamId: Int) -> String? {
        let i = teamId - Career.nationIdBase
        return i >= 0 && i < intl.nations.count ? intl.nations[i].code : nil
    }
    func nationTeamId(_ code: String) -> Int { Career.nationIdBase + (nationIndex(code) ?? 0) }

    /// A nation dressed as a franchise, so the match screens can show it.
    func nationTeam(_ teamId: Int) -> Franchise? {
        guard let code = nationCode(teamId: teamId), let n = intl.nations.first(where: { $0.code == code }) else { return nil }
        return Franchise(id: teamId, name: n.name, short: code, colorHex: n.colorHex, isCPU: code != intl.job,
                         squad: nationSquad(code), xi: nationXI(code))
    }

    var rankings: [Nation] { intl.nations.sorted { $0.points > $1.points } }
    func rank(of code: String) -> Int { (rankings.firstIndex { $0.code == code } ?? 19) + 1 }

    // MARK: Windows

    /// "2028-A" when the league has reached an international window that hasn't been played.
    var pendingWindow: String? {
        guard phase == .season, let f = nextFixture, let r = round(of: f) else { return nil }
        let key: String? = r >= 25 ? "\(year)-B" : (r >= 13 ? "\(year)-A" : nil)
        guard let k = key, !intl.done.contains(k) else { return nil }
        return k
    }

    var nextIntlFixture: Fixture? {
        intl.fixtures.filter { !$0.played }.min { (intl.days[$0.id] ?? 0, $0.id) < (intl.days[$1.id] ?? 0, $1.id) }
    }

    func isUserNationFixture(_ f: Fixture) -> Bool {
        guard let job = intl.job else { return false }
        let id = nationTeamId(job)
        return f.home == id || f.away == id
    }

    /// Creates the window's fixtures (a World Cup in April of even years, otherwise bilateral series).
    mutating func ensureWindow() {
        guard let key = pendingWindow, intl.event?.key != key else { return }
        setUpInternational()
        intl.fixtures = []
        intl.days = [:]
        intl.results = []
        let worldCup = year % 2 == 0 && key.hasSuffix("A")
        var event = IntlEvent(kind: worldCup ? .worldCup : .series, key: key)
        let start = key.hasSuffix("A") ? 95 : 215
        let ranked = rankings.map(\.code)
        if worldCup {
            let full = intl.nations.filter(\.fullMember).map(\.code)
            event.host = full.randomElement(using: &rng)
            event.stage = .group
            var groups: [[String]] = [[], [], [], []]
            for (i, code) in ranked.enumerated() {
                let row = i / 4
                groups[row % 2 == 0 ? i % 4 : 3 - i % 4].append(code)
            }
            event.groups = groups
            let pitch = intl.nations.first { $0.code == event.host }?.homePitch ?? .indianFlat
            var n = 0
            for g in groups { addRoundRobin(g, stage: .group, pitch: pitch, startDay: start, counter: &n) }
        } else {
            var order = ranked
            // Pair neighbours in the rankings, shuffled a little.
            for i in stride(from: 0, to: order.count - 2, by: 2) where rng.unit() < 0.3 { order.swapAt(i + 1, i + 2) }
            var n = 0
            for i in stride(from: 0, to: order.count - 1, by: 2) {
                let a = order[i], b = order[i + 1]
                let host = rng.unit() < 0.5 ? a : b
                let pitch = intl.nations.first { $0.code == host }?.homePitch ?? .indianFlat
                for m in 0..<3 {
                    addIntlFixture(home: host == a ? a : b, away: host == a ? b : a, stage: .series, pitch: pitch,
                                   day: start + m * 3 + n % 2)
                }
                n += 1
            }
        }
        intl.event = event
        if let job = intl.job { intl.target = boardTarget(job, event: event) }
        let hostName = event.host.flatMap { h in intl.nations.first { $0.code == h }?.name } ?? ""
        addNews(.season, "🌍 International window: \(event.title)\(hostName.isEmpty ? "" : " in \(hostName)").")
    }

    private mutating func addIntlFixture(home: String, away: String, stage: Stage, pitch: Pitch, day: Int) {
        let f = Fixture(id: intl.nextFixtureId, home: nationTeamId(home), away: nationTeamId(away), stage: stage, pitch: pitch)
        intl.nextFixtureId += 1
        intl.fixtures.append(f)
        intl.days[f.id] = day
    }

    private mutating func addRoundRobin(_ codes: [String], stage: Stage, pitch: Pitch, startDay: Int, counter: inout Int) {
        for i in 0..<codes.count {
            for j in (i + 1)..<codes.count {
                addIntlFixture(home: codes[i], away: codes[j], stage: stage, pitch: pitch, day: startDay + counter / 4)
                counter += 1
            }
        }
    }

    func intlSide(_ teamId: Int) -> MatchEngine.Side {
        let code = nationCode(teamId: teamId) ?? "IND"
        let xi = nationXI(code).compactMap { enginePlayer($0) }
        return MatchEngine.Side(teamId: teamId, xi: xi, attack: nil, tactics: code == intl.job ? tactics : nil)
    }

    /// Plays one international. Returns the result and ball log.
    @discardableResult
    mutating func playIntl(_ fixtureId: Int) -> (MatchResult, [BallEvent])? {
        guard let fi = intl.fixtures.firstIndex(where: { $0.id == fixtureId }), !intl.fixtures[fi].played else { return nil }
        let f = intl.fixtures[fi]
        var engine = MatchEngine(rng: rng)
        var log: [BallEvent] = []
        let r = engine.play(intlSide(f.home), intlSide(f.away), stage: f.stage, pitch: f.pitch, log: &log)
        rng = engine.rng
        intl.results.append(r)
        intl.fixtures[fi].resultId = r.id
        for inn in r.innings.prefix(2) { for b in inn.batters { intl.caps[b.id, default: 0] += 1 } }
        // Ranking points.
        if let wa = nationCode(teamId: r.winnerId), let la = nationCode(teamId: r.loserId),
           let wi = nationIndex(wa), let li = nationIndex(la) {
            let expected = 1 / (1 + pow(10, (intl.nations[li].points - intl.nations[wi].points) / 400))
            let k = f.stage.isBigGame ? 32.0 : 20.0
            intl.nations[wi].points += k * (1 - expected)
            intl.nations[li].points -= k * (1 - expected)
            if isUserNationFixture(f) {
                let won = wa == intl.job
                addNews(.result, "🌍 \(won ? "Won" : "Lost") \(f.stage.label) vs \(won ? la : wa) — \(r.margin).")
                if won { gainXP(15, reason: nil) }
            }
        }
        advanceEvent()
        return (r, log)
    }

    /// Next World Cup stage when the current one is complete; closes the window at the end.
    private mutating func advanceEvent() {
        guard var e = intl.event, !e.finished, intl.fixtures.allSatisfy(\.played) else { return }
        let pitch = intl.nations.first { $0.code == e.host }?.homePitch ?? .indianFlat
        let start = (intl.days.values.max() ?? 100) + 2
        var n = 0
        func top2(_ codes: [String], _ stage: Stage) -> [String] {
            let ids = codes.map { nationTeamId($0) }
            return SeasonEngine.table(teamIds: ids, results: intl.results, stage: stage).prefix(2).compactMap { nationCode(teamId: $0.teamId) }
        }
        switch (e.kind, e.stage) {
        case (.worldCup, .group):
            let q = e.groups.map { top2($0, .group) }
            guard q.count == 4, q.allSatisfy({ $0.count == 2 }) else { break }
            e.superEight = [[q[0][0], q[1][1], q[2][0], q[3][1]], [q[1][0], q[0][1], q[3][0], q[2][1]]]
            e.stage = .superEight
            for g in e.superEight { addRoundRobin(g, stage: .superEight, pitch: pitch, startDay: start, counter: &n) }
            intl.event = e
            return
        case (.worldCup, .superEight):
            let a = top2(e.superEight[0], .superEight), b = top2(e.superEight[1], .superEight)
            e.stage = .semiFinal
            addIntlFixture(home: a[0], away: b[1], stage: .semiFinal, pitch: pitch, day: start)
            addIntlFixture(home: b[0], away: a[1], stage: .semiFinal, pitch: pitch, day: start + 1)
            intl.event = e
            return
        case (.worldCup, .semiFinal):
            let winners = intl.results.filter { $0.stage == .semiFinal }.compactMap { nationCode(teamId: $0.winnerId) }
            e.stage = .final
            addIntlFixture(home: winners[0], away: winners[1], stage: .final, pitch: pitch, day: start + 1)
            intl.event = e
            return
        case (.worldCup, .final):
            e.winner = intl.results.first { $0.stage == .final }.flatMap { nationCode(teamId: $0.winnerId) }
        default:
            break
        }
        e.finished = true
        intl.event = e
        closeEvent(e)
    }

    private mutating func closeEvent(_ e: IntlEvent) {
        intl.done.append(e.key)
        if intl.done.count > 12 { intl.done.removeFirst(intl.done.count - 12) }
        var userResult: String? = nil
        if let job = intl.job {
            let (met, summary) = evaluateBoard(job, event: e)
            userResult = summary
            if met {
                intl.strikes = 0
                gainXP(e.kind == .worldCup ? 150 : 60, reason: nil)
            } else {
                intl.strikes += 1
            }
            if e.winner == job {
                gainXP(400, reason: nil)
                gold += 300
                addNews(.season, "🏆🌍 WORLD CHAMPIONS! \(intl.nations.first { $0.code == job }?.name ?? job) win the T20 World Cup!")
            }
            addNews(.info, "🌍 Board verdict: \(summary). Target was: \(intl.target).\(met ? " ✅" : " ❌")")
            if intl.strikes >= 2 && intl.sacking {
                addNews(.info, "🌍 You've been sacked as \(job) coach after missing two targets in a row.")
                intl.job = nil
                intl.squad = []
                intl.strikes = 0
            }
        }
        if e.kind == .worldCup, let w = e.winner, intl.job != w {
            addNews(.season, "🌍 \(intl.nations.first { $0.code == w }?.name ?? w) win the T20 World Cup.")
        }
        intl.history.insert(IntlRecord(key: e.key, title: e.title, winner: e.winner, userNation: intl.job, userResult: userResult), at: 0)
        if intl.history.count > 30 { intl.history.removeLast(intl.history.count - 30) }
    }

    /// Simulates the window's matches. With `stopAtUser`, stops before the user's nation plays.
    @discardableResult
    mutating func simWindow(stopAtUser: Bool) -> Int {
        ensureWindow()
        var n = 0
        while let f = nextIntlFixture, n < 400 {
            if stopAtUser && isUserNationFixture(f) { break }
            playIntl(f.id)
            n += 1
        }
        return n
    }

    // MARK: Job and board

    var reputation: Int {
        manager.level * 2 + (info(userClubId)?.titles ?? 0) * 15 + intl.history.filter { $0.winner != nil && $0.winner == $0.userNation }.count * 20
    }

    func requiredReputation(_ code: String) -> Int {
        let r = rank(of: code)
        return r <= 5 ? 40 : (r <= 10 ? 24 : (r <= 14 ? 12 : 0))
    }

    /// National vacancies the user's reputation qualifies for (refreshed each off-season).
    mutating func generateJobOffers() {
        setUpInternational()
        guard intl.job == nil else { intl.offers = []; return }
        let eligible = rankings.map(\.code).filter { requiredReputation($0) <= reputation }
        var offers: [String] = []
        for code in eligible.shuffled(using: &rng) where offers.count < 2 { offers.append(code) }
        // Always at least one way in: the best eligible side.
        if let best = eligible.first, !offers.contains(best), !offers.isEmpty, rng.unit() < 0.5 { offers[offers.count - 1] = best }
        intl.offers = offers
        if !offers.isEmpty {
            addNews(.info, "🌍 National job offers: \(offers.compactMap { c in intl.nations.first { $0.code == c }?.name }.joined(separator: ", ")).")
        }
    }

    @discardableResult
    mutating func acceptJob(_ code: String) -> Bool {
        guard intl.job == nil, intl.offers.contains(code) else { return false }
        intl.job = code
        intl.offers = []
        intl.strikes = 0
        intl.squad = nationSquad(code)
        addNews(.info, "🌍 You are the new head coach of \(intl.nations.first { $0.code == code }?.name ?? code)!")
        return true
    }

    mutating func resignJob() {
        guard let job = intl.job else { return }
        addNews(.info, "🌍 You resigned as \(job) coach.")
        intl.job = nil
        intl.squad = []
    }

    mutating func setNationalSquad(_ ids: [String]) {
        guard let job = intl.job else { return }
        let eligible = Set(nationPlayers(job).map(\.id))
        intl.squad = Array(ids.filter { eligible.contains($0) }.prefix(15))
    }

    func boardTarget(_ code: String, event: IntlEvent) -> String {
        let r = rank(of: code)
        if event.kind == .worldCup { return r <= 4 ? "Reach the semi-finals" : (r <= 8 ? "Reach the Super 8" : "Win 2 group matches") }
        guard let opp = seriesOpponent(code) else { return "Win the series" }
        return rank(of: opp) > r ? "Win the series" : "Win at least one match"
    }

    func seriesOpponent(_ code: String) -> String? {
        let id = nationTeamId(code)
        guard let f = intl.fixtures.first(where: { $0.home == id || $0.away == id }) else { return nil }
        return nationCode(teamId: f.home == id ? f.away : f.home)
    }

    private func evaluateBoard(_ code: String, event: IntlEvent) -> (Bool, String) {
        let id = nationTeamId(code)
        let mine = intl.results.filter { $0.teamA == id || $0.teamB == id }
        let wins = mine.filter { $0.winnerId == id }.count
        if event.kind == .worldCup {
            let stages = mine.map(\.stage)
            let finish = event.winner == code ? "Champions" : (stages.contains(.final) ? "Runners-up"
                : (stages.contains(.semiFinal) ? "Semi-finals" : (stages.contains(.superEight) ? "Super 8" : "Group stage")))
            let met: Bool
            switch intl.target {
            case "Reach the semi-finals": met = stages.contains(.semiFinal)
            case "Reach the Super 8": met = stages.contains(.superEight)
            default: met = mine.filter { $0.stage == .group && $0.winnerId == id }.count >= 2
            }
            return (met, "\(finish) (\(wins) wins)")
        }
        let losses = mine.count - wins
        let met = intl.target == "Win the series" ? wins > losses : wins >= 1
        return (met, "Series \(wins)-\(losses)")
    }
}
