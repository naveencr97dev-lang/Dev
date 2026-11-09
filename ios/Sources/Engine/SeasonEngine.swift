import Foundation

struct Fixture: Codable, Hashable, Identifiable {
    let id: Int
    let home: Int
    let away: Int
    let stage: Stage
    var pitch: Pitch = .indianFlat
    var resultId: UUID? = nil

    var played: Bool { resultId != nil }
    func involves(_ team: Int) -> Bool { home == team || away == team }
}

struct TableRow: Hashable, Identifiable {
    var id: Int { teamId }
    let teamId: Int
    var played = 0
    var won = 0
    var lost = 0
    var points = 0
    var runsFor = 0
    var ballsFaced = 0
    var runsAgainst = 0
    var ballsBowled = 0

    var nrr: Double {
        guard ballsFaced > 0, ballsBowled > 0 else { return 0 }
        return Double(runsFor) * 6 / Double(ballsFaced) - Double(runsAgainst) * 6 / Double(ballsBowled)
    }
}

struct PlayerSeason: Hashable, Identifiable {
    let id: String
    var teamId: Int
    var matches = 0
    var runs = 0
    var ballsFaced = 0
    var fours = 0
    var sixes = 0
    var highScore = 0
    var wickets = 0
    var ballsBowled = 0
    var runsConceded = 0
    var potm = 0

    /// Simple impact score for MVP.
    var mvpPoints: Double {
        Double(runs) + Double(sixes) * 2 + Double(fours) + Double(wickets) * 25 + Double(potm) * 15
    }
    var economy: Double { ballsBowled == 0 ? 0 : Double(runsConceded) * 6 / Double(ballsBowled) }
}

enum SeasonEngine {
    /// Round-robin (circle method), rounds shuffled.
    static func leagueFixtures(teamIds: [Int], double: Bool, rng: inout SeededRNG) -> [Fixture] {
        var ids = teamIds.shuffled(using: &rng)
        if ids.count % 2 == 1 { ids.append(-1) }   // bye
        let n = ids.count
        var rounds: [[(Int, Int)]] = []
        for r in 0..<(n - 1) {
            var pairs: [(Int, Int)] = []
            for i in 0..<(n / 2) {
                let a = ids[i], b = ids[n - 1 - i]
                if a != -1 && b != -1 { pairs.append(r % 2 == 0 ? (a, b) : (b, a)) }
            }
            rounds.append(pairs)
            // rotate all but the first
            let last = ids.removeLast()
            ids.insert(last, at: 1)
        }
        if double { rounds += rounds.map { $0.map { ($0.1, $0.0) } } }
        var fixtures: [Fixture] = []
        for round in rounds {
            for (h, a) in round {
                fixtures.append(Fixture(id: fixtures.count + 1, home: h, away: a, stage: .league))
            }
        }
        return fixtures
    }

    static func table(teamIds: [Int], results: [MatchResult], stage: Stage = .league) -> [TableRow] {
        var rows = Dictionary(uniqueKeysWithValues: teamIds.map { ($0, TableRow(teamId: $0)) })
        let ids = Set(teamIds)
        for r in results where r.stage == stage && ids.contains(r.teamA) && ids.contains(r.teamB) {
            for (bat, inn) in r.innings.prefix(2).enumerated() {
                let other = r.innings[1 - bat]
                let faced = inn.allOut ? inn.maxBalls : inn.balls
                rows[inn.teamId]?.runsFor += inn.runs
                rows[inn.teamId]?.ballsFaced += faced
                rows[other.teamId]?.runsAgainst += inn.runs
                rows[other.teamId]?.ballsBowled += faced
            }
            rows[r.winnerId]?.played += 1
            rows[r.winnerId]?.won += 1
            rows[r.winnerId]?.points += 2
            rows[r.loserId]?.played += 1
            rows[r.loserId]?.lost += 1
        }
        return rows.values.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            if $0.nrr != $1.nrr { return $0.nrr > $1.nrr }
            return $0.teamId < $1.teamId
        }
    }

    static func playerStats(results: [MatchResult]) -> [String: PlayerSeason] {
        var stats: [String: PlayerSeason] = [:]
        for r in results {
            var seen = Set<String>()
            for inn in r.innings.prefix(2) {
                let bowlTeam = inn.teamId == r.teamA ? r.teamB : r.teamA
                for b in inn.batters {
                    var s = stats[b.id] ?? PlayerSeason(id: b.id, teamId: inn.teamId)
                    if !seen.contains(b.id) { s.matches += 1; seen.insert(b.id) }
                    if b.batted {
                        s.runs += b.runs; s.ballsFaced += b.balls
                        s.fours += b.fours; s.sixes += b.sixes
                        s.highScore = max(s.highScore, b.runs)
                    }
                    stats[b.id] = s
                }
                for bw in inn.bowlers where bw.balls > 0 {
                    var s = stats[bw.id] ?? PlayerSeason(id: bw.id, teamId: bowlTeam)
                    s.wickets += bw.wickets; s.ballsBowled += bw.balls; s.runsConceded += bw.runs
                    stats[bw.id] = s
                }
            }
            stats[r.potmId]?.potm += 1
        }
        return stats
    }

    /// The next playoff fixture, given the final table and playoff results so far. nil = season over.
    static func nextPlayoff(table: [TableRow], playoffResults: [MatchResult], nextId: Int) -> Fixture? {
        let t = table.map(\.teamId)
        func result(_ s: Stage) -> MatchResult? { playoffResults.first { $0.stage == s } }
        if t.count < 4 {
            if result(.final) == nil { return Fixture(id: nextId, home: t[0], away: t[1], stage: .final) }
            return nil
        }
        guard let q1 = result(.qualifier1) else { return Fixture(id: nextId, home: t[0], away: t[1], stage: .qualifier1) }
        guard let el = result(.eliminator) else { return Fixture(id: nextId, home: t[2], away: t[3], stage: .eliminator) }
        guard let q2 = result(.qualifier2) else { return Fixture(id: nextId, home: q1.loserId, away: el.winnerId, stage: .qualifier2) }
        if result(.final) == nil { return Fixture(id: nextId, home: q1.winnerId, away: q2.winnerId, stage: .final) }
        return nil
    }
}
