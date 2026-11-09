import Foundation

// Career › Club › Assistant manager: explains losing runs and warns about retirements before they
// happen. Panel round 2: players lost 6-9 in a row "and the game never told me why", and casual
// players only noticed retirements in the news after the fact.

extension Career {
    /// League results of the user's club, newest last.
    private var userLeagueResults: [MatchResult] {
        results.filter { $0.stage == .league && ($0.teamA == userClubId || $0.teamB == userClubId) }
    }

    /// Current run of defeats in the league.
    var losingRun: Int {
        var n = 0
        for r in userLeagueResults.reversed() {
            if r.winnerId == userClubId { break }
            n += 1
        }
        return n
    }

    /// Would Auto-pick field a clearly stronger side (≥2 points)?
    var strongerXIOnBench: Bool {
        var copy = self
        copy.autoPickXI(clubIndex: copy.userClubIndex)
        return copy.strength(userClubId) - strength(userClubId) >= 2
    }

    /// The assistant's read on the last few defeats, and what to try. nil when there's nothing to say.
    func assistantReport() -> (diagnosis: String, advice: [String])? {
        let run = losingRun
        guard run >= 3 else { return nil }
        let recent = Array(userLeagueResults.suffix(run))
        let league = results.filter { $0.stage == .league }
        let par = league.isEmpty ? 160 : league.map { $0.innings[0].runs }.reduce(0, +) / league.count
        var scored = 0, conceded = 0, oppStrength = 0
        for r in recent {
            for inn in r.innings.prefix(2) {
                if inn.teamId == userClubId { scored += inn.runs } else { conceded += inn.runs }
            }
            oppStrength += strength(r.teamA == userClubId ? r.teamB : r.teamA)
        }
        scored /= recent.count; conceded /= recent.count; oppStrength /= recent.count
        let mine = strength(userClubId)

        var causes: [String] = []
        var advice: [String] = []
        if scored < par - 12 {
            causes.append("the batting (\(scored) a game, league par \(par))")
            advice.append(tactics.intent.first == .attack ? "Run a Power Hitting session in Training" : "Set the powerplay intent to Attack in Tactics")
        }
        if conceded > par + 12 {
            causes.append("the bowling (\(conceded) conceded a game)")
            advice.append(tactics.field.last == .defend ? "Change the bowling plan: your death bowlers are leaking" : "Set the death-overs field to Defend in Tactics")
        }
        // A batter out of position (a bowler in the top order) is the costliest mistake there is.
        let order = userClub.xi.compactMap { player($0) }
        if let i = order.indices.first(where: { order[$0].isExposed(atPosition: $0) }) {
            causes.insert("the batting order: \(order[i].name) bats at \(i + 1)", at: 0)
            advice.insert("Fix the order (Squad › Order, or Auto-pick)", at: 0)
        }
        let cold = userClub.xi.compactMap { players[$0] }.filter { $0.form <= -4 }.sorted { $0.form < $1.form }
        if !cold.isEmpty {
            causes.append("form: \(cold.prefix(2).map { "\($0.name) (\($0.form))" }.joined(separator: ", "))")
            // Only suggest a rest when a reserve of the same role is as good as the cold player plays now.
            let xi = Set(userClub.xi)
            if let c = cold.first, let sub = squad(userClubId).filter({ !xi.contains($0.id) && $0.role == c.role })
                .max(by: { $0.rating < $1.rating }), sub.rating >= c.rating + c.form / 3 - 1 {
                advice.append("Rest \(c.name); \(sub.name) is in better shape")
            }
        }
        if strongerXIOnBench { advice.append("Auto-pick in Squad fields a stronger XI") }
        if oppStrength - mine >= 3 { causes.append("a tough run: opponents rated \(oppStrength) to your \(mine)") }
        if causes.isEmpty { causes.append("fine margins, nothing structural") }
        if advice.isEmpty { advice.append("Stay the course: the numbers say the luck will turn") }
        return ("\(run) defeats in a row. The problem is \(causes.joined(separator: "; ")).", Array(advice.prefix(2)))
    }

    /// After each of the user's league matches: speak up on the 3rd and 6th defeat in a row.
    mutating func assistantAfterMatch(_ r: MatchResult) {
        guard r.stage == .league, r.teamA == userClubId || r.teamB == userClubId,
              [3, 6, 9].contains(losingRun), let report = assistantReport() else { return }
        addNews(.info, "📋 Assistant: \(report.diagnosis) Try: \(report.advice.joined(separator: "; ")).")
    }

    /// Users' players likely to retire after this season (chance ≥ 30%), most likely first.
    var retirementWatch: [CareerPlayer] {
        var chance: [String: Double] = [:]
        for p in squad(userClubId) { chance[p.id] = retireChance(p, age: p.age(in: year + 1)) }
        let likely = squad(userClubId).filter { (chance[$0.id] ?? 0) >= 0.3 }
        return likely.sorted { a, b in
            let ca = chance[a.id] ?? 0, cb = chance[b.id] ?? 0
            return ca != cb ? ca > cb : a.id < b.id
        }
    }

    /// Season start: name the likely retirees so nobody vanishes unannounced.
    mutating func announceRetirementWatch() {
        let watch = retirementWatch
        guard !watch.isEmpty else { return }
        let names = watch.prefix(4).map { "\($0.name) (\($0.age(in: year)))" }.joined(separator: ", ")
        addNews(.squad, "🕰️ Retirement watch: \(names) may retire after this season. Plan replacements.")
    }
}
