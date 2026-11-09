import Foundation

// Career › Club › Board: season objectives with rewards and board confidence, plus monthly awards
// (Player and Manager of the Month). Modelled on manager games' objective and award loops: a short
// list of goals each season that pays XP and gold, and a reason to care about every month.

struct Objective: Codable, Hashable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        /// Finish the league stage at or above this position.
        case finish
        /// Win this many home league matches.
        case homeWins
        /// Players aged 23 or under make this many league appearances.
        case youth
    }
    var id: Int { Objective.Kind.allCases.firstIndex(of: kind) ?? 0 }
    let kind: Kind
    let target: Int
    let xp: Int
    let gold: Int
    /// nil while the season runs; true or false once judged.
    var met: Bool? = nil

    var title: String {
        switch kind {
        case .finish: return target <= 1 ? "Top the league" : "Finish in the top \(target)"
        case .homeWins: return "Win \(target) home matches"
        case .youth: return "Give U23s \(target) appearances"
        }
    }
}

struct MonthAward: Codable, Hashable, Identifiable {
    var id: String { "\(year)-\(month)" }
    let year: Int
    let month: Int
    let playerId: String
    let playerName: String
    let playerClub: Int
    let line: String
    let managerClub: Int
    let managerWins: Int

    var monthName: String { CareerCalendar.monthNames[max(0, min(11, month))] }
}

struct BoardState: Codable, Hashable {
    var year = 0
    var objectives: [Objective] = []
    /// 0-100. Meeting objectives raises it, missing them lowers it.
    var confidence = 60
    var awards: [MonthAward] = []
}

extension Career {
    // MARK: Objectives

    /// The board sets this season's objectives from where the squad ranks in the league.
    mutating func setObjectives() {
        let ranked = clubs.map(\.id).sorted { strength($0) != strength($1) ? strength($0) > strength($1) : $0 < $1 }
        let rank = (ranked.firstIndex(of: userClubId) ?? 4) + 1
        let finish = rank <= 2 ? 2 : (rank <= 5 ? 4 : (rank <= 8 ? 6 : 8))
        let homeGames = leagueFixtures.filter { $0.home == userClubId }.count
        let homeWins = Int((Double(homeGames) * (rank <= 3 ? 0.6 : (rank <= 7 ? 0.5 : 0.4))).rounded())
        board.year = year
        board.objectives = [
            Objective(kind: .finish, target: finish, xp: 150, gold: 100),
            Objective(kind: .homeWins, target: max(1, homeWins), xp: 80, gold: 50),
            Objective(kind: .youth, target: 30, xp: 80, gold: 50),
        ]
    }

    /// Progress so far: current value and whether it's met (or on track, for the league finish).
    func progress(_ o: Objective) -> (value: Int, ok: Bool) {
        switch o.kind {
        case .finish:
            let pos = position(of: userClubId)
            return (pos, pos <= o.target)
        case .homeWins:
            let n = results.filter { r in
                r.stage == .league && r.winnerId == userClubId
                    && fixtures.first { $0.resultId == r.id }?.home == userClubId
            }.count
            return (n, n >= o.target)
        case .youth:
            var n = 0
            for r in results where r.stage == .league && (r.teamA == userClubId || r.teamB == userClubId) {
                guard let inn = r.innings.prefix(2).first(where: { $0.teamId == userClubId }) else { continue }
                n += inn.batters.filter { b in players[b.id].map { $0.age(in: year) <= 23 } ?? false }.count
            }
            return (n, n >= o.target)
        }
    }

    /// Judges the objectives at the end of the season and pays the rewards.
    mutating func judgeObjectives() {
        guard board.year == year, board.objectives.contains(where: { $0.met == nil }) else { return }
        var met = 0
        for i in board.objectives.indices {
            let o = board.objectives[i]
            let ok = progress(o).ok
            board.objectives[i].met = ok
            if ok {
                met += 1
                gold += o.gold
                gainXP(o.xp, reason: nil)
            }
        }
        let missed = board.objectives.count - met
        board.confidence = max(0, min(100, board.confidence + met * 10 - missed * 12))
        let mood = board.confidence >= 70 ? "delighted" : (board.confidence >= 45 ? "satisfied" : "worried")
        addNews(.season, "Board review: \(met) of \(board.objectives.count) objectives met. The board is \(mood) (confidence \(board.confidence)%).")
    }

    // MARK: Monthly awards

    /// After a league match: if it closed a calendar month, name the Player and Manager of the Month.
    mutating func checkMonthEnd(after f: Fixture) {
        guard f.stage == .league else { return }
        let month = CareerCalendar.monthDay(day(of: f)).month
        if let next = fixtures.first(where: { !$0.played && $0.stage == .league }),
           CareerCalendar.monthDay(day(of: next)).month == month { return }
        guard !board.awards.contains(where: { $0.year == year && $0.month == month }) else { return }
        let inMonth = fixtures.filter { $0.stage == .league && $0.played && CareerCalendar.monthDay(day(of: $0)).month == month }
            .compactMap { result($0.resultId) }
        guard !inMonth.isEmpty else { return }

        // Player: runs + 20 a wicket, across the month.
        var runs: [String: Int] = [:], wkts: [String: Int] = [:], team: [String: Int] = [:]
        var wins: [Int: Int] = [:]
        for r in inMonth {
            wins[r.winnerId, default: 0] += 1
            for inn in r.innings.prefix(2) {
                let bowlingTeam = inn.teamId == r.teamA ? r.teamB : r.teamA
                for b in inn.batters where b.batted { runs[b.id, default: 0] += b.runs; team[b.id] = inn.teamId }
                for w in inn.bowlers where w.balls > 0 { wkts[w.id, default: 0] += w.wickets; team[w.id] = bowlingTeam }
            }
        }
        let score = { (id: String) in (runs[id] ?? 0) + 20 * (wkts[id] ?? 0) }
        guard let best = team.keys.max(by: { score($0) != score($1) ? score($0) < score($1) : $0 > $1 }),
              let mgr = wins.keys.max(by: { wins[$0]! != wins[$1]! ? wins[$0]! < wins[$1]! : $0 > $1 }) else { return }
        let name = players[best]?.name ?? best
        var parts: [String] = []
        if let r = runs[best], r > 0 { parts.append("\(r) runs") }
        if let w = wkts[best], w > 0 { parts.append("\(w) wkts") }
        let award = MonthAward(year: year, month: month, playerId: best, playerName: name, playerClub: team[best] ?? 0,
                               line: parts.joined(separator: ", "), managerClub: mgr, managerWins: wins[mgr] ?? 0)
        board.awards.append(award)
        if board.awards.count > 40 { board.awards.removeFirst(board.awards.count - 40) }

        let mName = award.monthName
        addNews(.milestone, "🏅 Player of the Month (\(mName)): \(name), \(club(award.playerClub)?.short ?? "") · \(award.line).")
        if mgr == userClubId {
            gainXP(60, reason: nil)
            gold += 30
            addNews(.milestone, "🏅 You are Manager of the Month for \(mName): \(award.managerWins) wins. +60 XP, +30 gold.")
        } else {
            addNews(.info, "Manager of the Month (\(mName)): \(club(mgr)?.short ?? "") with \(award.managerWins) wins.")
        }
        if team[best] == userClubId, let form = players[best]?.form { players[best]?.form = min(tuning.formCap, form + 2) }
    }
}
