import Foundation

// Career › Squad › Roles and morale. Modelled on manager games' squad status: every player in the
// user's squad has a role (a promise of playing time). Playing less than the role promises lowers
// morale; very unhappy players ask to leave. Promising a bigger role when signing lowers the wage a
// player asks for. Small match effect (+1 happy, -2 miserable) so balance stays where it is.

enum SquadRole: String, Codable, CaseIterable, Identifiable {
    case key, firstTeam, rotation, backup, notNeeded
    var id: String { rawValue }

    var label: String {
        switch self {
        case .key: return "Key Player"
        case .firstTeam: return "First Team"
        case .rotation: return "Rotation"
        case .backup: return "Backup"
        case .notNeeded: return "Not Needed"
        }
    }

    /// Share of matches the player expects to play.
    var expectedShare: Double {
        switch self {
        // Cricket XIs barely change, so only the first two roles expect regular cricket.
        case .key: return 0.9
        case .firstTeam: return 0.7
        case .rotation: return 0.2
        case .backup: return 0
        case .notNeeded: return 0
        }
    }

    /// Wage multiplier when this role is promised at signing (a bigger role buys a cheaper deal).
    var wageFactor: Double {
        switch self {
        case .key: return 0.85
        case .firstTeam: return 0.93
        case .rotation: return 1.0
        case .backup: return 1.1
        case .notNeeded: return 1.25
        }
    }

    var rank: Int { SquadRole.allCases.firstIndex(of: self) ?? 2 }
}

struct SquadReport {
    var averageRating = 0
    var averageAge = 0.0
    var totalValue = 0
    var stars: [CareerPlayer] = []
    var strengths: [String] = []
    var weaknesses: [String] = []
}

extension Career {
    static let defaultMorale = 70

    func morale(_ p: CareerPlayer) -> Int { p.morale ?? Career.defaultMorale }

    func squadRole(_ p: CareerPlayer) -> SquadRole { p.squadRole ?? .rotation }

    /// "Future" line for the profile.
    func future(_ p: CareerPlayer) -> String {
        switch morale(p) {
        case 70...: return "Happy at the club"
        case 45..<70: return "Settled"
        case 25..<45: return "Unhappy with his role"
        default: return "Wants to leave"
        }
    }

    /// Roles from the best XI (panel round 4: rating rank put a second keeper in "First Team", who
    /// then never played and asked to leave). The best three in the XI are key players, the rest of
    /// the XI first team, the next three rotation, everyone else backup. Promised roles are kept.
    /// `refresh` re-derives every unpromised role (each season start); otherwise only missing ones.
    mutating func assignDefaultRoles(refresh: Bool = false) {
        var probe = self
        probe.autoPickXI(clubIndex: probe.userClubIndex)
        let xi = probe.userClub.xi
        let byRating = { (a: CareerPlayer, b: CareerPlayer) in a.rating != b.rating ? a.rating > b.rating : a.id < b.id }
        let inXI = squad(userClubId).filter { xi.contains($0.id) }.sorted(by: byRating)
        let bench = squad(userClubId).filter { !xi.contains($0.id) }.sorted(by: byRating)
        var role: [String: SquadRole] = [:]
        for (i, p) in inXI.enumerated() { role[p.id] = i < 3 ? .key : .firstTeam }
        for (i, p) in bench.enumerated() { role[p.id] = i < 3 ? .rotation : .backup }
        for p in squad(userClubId) {
            if p.morale == nil { players[p.id]?.morale = Career.defaultMorale }
            guard p.rolePromised != true, refresh || p.squadRole == nil, let r = role[p.id] else { continue }
            players[p.id]?.squadRole = r
        }
    }

    /// The user changes a player's role. A demotion hurts (10 morale a step); a promotion pleases.
    mutating func setSquadRole(_ playerId: String, _ role: SquadRole) {
        guard let p = players[playerId], p.clubId == userClubId else { return }
        let old = squadRole(p)
        let steps = role.rank - old.rank
        var m = morale(p)
        if steps > 0 { m -= 10 * steps } else if steps < 0 { m += 5 * -steps }
        players[playerId]?.squadRole = role
        players[playerId]?.rolePromised = true
        players[playerId]?.morale = max(0, min(100, m))
    }

    /// How often the player made the XI in the user's last league matches this season.
    func playedShare(_ playerId: String, last n: Int = 8) -> Double? {
        let mine = results.filter { $0.stage == .league && ($0.teamA == userClubId || $0.teamB == userClubId) }.suffix(n)
        guard mine.count >= 3 else { return nil }
        let played = mine.filter { r in
            r.innings.prefix(2).contains { $0.teamId == userClubId && $0.batters.contains { $0.id == playerId } }
        }.count
        return Double(played) / Double(mine.count)
    }

    /// After each of the user's matches: morale follows playing time against the promised role.
    mutating func moraleTick(after r: MatchResult) {
        guard r.teamA == userClubId || r.teamB == userClubId else { return }
        let won = r.winnerId == userClubId
        let xi = Set(r.innings.prefix(2).first { $0.teamId == userClubId }?.batters.map(\.id) ?? [])
        for p in squad(userClubId).sorted(by: { $0.id < $1.id }) {
            var m = morale(p)
            let role = squadRole(p)
            if let share = playedShare(p.id) {
                let gap = role.expectedShare - share
                // Promises cut deeper than the default pecking order (panel round 4).
                let rate = p.rolePromised == true ? 8.0 : 4.0
                if gap <= 0.1 { m += 2 } else { m -= min(p.rolePromised == true ? 6 : 3, Int((gap * rate).rounded(.up))) }
            }
            if xi.contains(p.id) { m += won ? 1 : -1 }
            m = max(0, min(100, m))
            let before = morale(p)
            players[p.id]?.morale = m
            // Crossing lines tells the manager, once each.
            if before >= 25 && m < 25 && role != .notNeeded {
                addNews(.squad, "😠 \(p.name) is unhappy: he was promised \(role.label.lowercased()) cricket and isn't getting it.")
            }
            // Only a broken promise ends in a transfer request: casual managers aren't punished.
            if before >= 12 && m < 12 && role != .notNeeded && p.rolePromised == true && market.listed[p.id] == nil {
                market.listed[p.id] = p.value(in: year)
                addNews(.squad, "📝 \(p.name) has handed in a transfer request. He's on the transfer list at \(Money.format(p.value(in: year))).")
            }
        }
    }

    /// Match effect: happy players lift a little, miserable ones drop.
    func moraleBoost(_ playerId: String) -> Int {
        guard let p = players[playerId], p.clubId == userClubId else { return 0 }
        let m = morale(p)
        return m >= 80 ? 1 : (m < 30 ? -2 : 0)
    }

    /// Wage the player asks for with this role promised.
    func wageDemand(_ p: CareerPlayer, promising role: SquadRole) -> Int {
        max(tuning.minWage, Career.round5(Double(userWageDemand(p)) * role.wageFactor))
    }

    /// The role a new signing would expect: does he walk into the XI, and how high?
    func expectedRole(_ p: CareerPlayer) -> SquadRole {
        let advice = scoutAdvice(p).text
        let better = squad(userClubId).filter { $0.rating > p.rating }.count
        if advice.hasPrefix("Walks into") { return better < 3 ? .key : .firstTeam }
        return advice.hasPrefix("Fills a gap") ? .rotation : .backup
    }

    /// Key players already promised: more than the XI can satisfy breaks promises.
    var keyPlayerCount: Int { squad(userClubId).filter { squadRole($0) == .key }.count }

    /// 0…1: how happy the player would be with this offer (the negotiation bar).
    func offerMood(_ p: CareerPlayer, wage: Int, role: SquadRole) -> Double {
        let demand = Double(wageDemand(p, promising: role))
        guard demand > 0, Double(wage) < demand else { return 1 }   // meeting the demand is a full bar
        return max(0, min(0.99, (Double(wage) / demand - 0.8) / 0.2))
    }

    // MARK: Squad report (Reports › Overview)

    func squadReport() -> SquadReport {
        var r = SquadReport()
        let s = squad(userClubId)
        guard !s.isEmpty else { return r }
        r.averageRating = s.map(\.rating).reduce(0, +) / s.count
        r.averageAge = Double(s.map { $0.age(in: year) }.reduce(0, +)) / Double(s.count)
        r.totalValue = s.map { $0.value(in: year) }.reduce(0, +)
        r.stars = Array(s.sorted { $0.rating != $1.rating ? $0.rating > $1.rating : $0.id < $1.id }.prefix(3))

        let ranked = clubs.map(\.id).sorted { strength($0) > strength($1) }
        let pos = (ranked.firstIndex(of: userClubId) ?? 5) + 1
        if pos <= 3 { r.strengths.append("The XI is one of the strongest in the league (\(Career.ordinal(pos))).") }
        if pos >= clubs.count - 2 { r.weaknesses.append("The XI is one of the weakest in the league (\(Career.ordinal(pos))).") }

        // Batting and bowling against the league.
        func topBat(_ id: Int) -> Int {
            let xs = squad(id).map(\.bat).sorted(by: >).prefix(7)
            return xs.isEmpty ? 0 : xs.reduce(0, +) / xs.count
        }
        func topBowl(_ id: Int) -> Int {
            let xs = squad(id).map(\.bowl).sorted(by: >).prefix(5)
            return xs.isEmpty ? 0 : xs.reduce(0, +) / xs.count
        }
        let leagueBat = clubs.map { topBat($0.id) }.reduce(0, +) / max(1, clubs.count)
        let leagueBowl = clubs.map { topBowl($0.id) }.reduce(0, +) / max(1, clubs.count)
        let (bat, bowl) = (topBat(userClubId), topBowl(userClubId))
        if bat >= leagueBat + 2 { r.strengths.append("Batting is a strength (top seven average \(bat), league \(leagueBat)).") }
        if bat <= leagueBat - 2 { r.weaknesses.append("Batting is a weak area (top seven average \(bat), league \(leagueBat)).") }
        if bowl >= leagueBowl + 2 { r.strengths.append("The bowling attack is a strength (best five average \(bowl), league \(leagueBowl)).") }
        if bowl <= leagueBowl - 2 { r.weaknesses.append("The bowling attack is a weak area (best five average \(bowl), league \(leagueBowl)).") }

        // Conditions: spin and pace options for the home pitch.
        let spinners = s.filter { $0.bowlType == .spin && $0.bowl >= 60 }.count
        let seamers = s.filter { $0.bowlType == .pace && $0.bowl >= 60 }.count
        let home = info(userClubId)?.homePitch ?? .indianFlat
        if spinners < 2 { r.weaknesses.append("Only \(spinners) spinner\(spinners == 1 ? "" : "s") of quality\(home == .dustyTurner || home == .caribbeanSlow ? ", on a home pitch that turns" : "").") }
        if seamers < 3 { r.weaknesses.append("Only \(seamers) seamer\(seamers == 1 ? "" : "s") of quality\(home == .englishSeam || home == .aussieBounce ? ", on a home pitch for pace" : "").") }
        if spinners >= 3 && seamers >= 4 { r.strengths.append("Bowling options for every surface.") }

        // Shape, age, size, mood.
        if s.filter({ $0.role == .WK }).count < 2 { r.weaknesses.append("No backup wicket-keeper.") }
        if r.averageAge >= 30 { r.weaknesses.append("An ageing squad (average \(String(format: "%.1f", r.averageAge))). Plan for retirements.") }
        else if r.averageAge <= 25.5 { r.strengths.append("A young squad with room to grow (average \(String(format: "%.1f", r.averageAge))).") }
        else { r.strengths.append("A good mix of youth and experience.") }
        if s.count <= tuning.minSquad + 1 { r.weaknesses.append("A thin squad (\(s.count)): one injury crisis from trouble.") }
        else if s.count <= tuning.maxSquad - 2 { r.strengths.append("The squad is a manageable size (\(s.count)).") }
        let unhappy = s.filter { morale($0) < 45 }
        if !unhappy.isEmpty { r.weaknesses.append("\(unhappy.count) unhappy with their role: \(unhappy.prefix(3).map(\.name).joined(separator: ", ")).") }
        else { r.strengths.append("The dressing room is happy.") }
        return r
    }
}
