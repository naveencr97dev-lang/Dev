import Foundation

// The match centre's live reads (Soccer Manager's in-match Overview and Ratings, for cricket):
// match ratings so far, the key numbers of the innings in progress, and the assistant's advice.
// Pure functions of the scorecard and the ball log up to the paused ball, so they work in the
// quick game and in a career, and the end-of-match rating uses the same formula.

enum LiveReport {
    // MARK: Ratings

    /// Match rating, 3 to 10, from the scorecards so far. The result and player-of-the-match bonuses
    /// apply only once they're known (`winnerId`, `potmId`). nil for a player not in either XI.
    static func rating(_ id: String, cards: [InningsCard], winnerId: Int? = nil, potmId: String? = nil) -> Double? {
        let inns = Array(cards.prefix(2))
        guard let batInn = inns.first(where: { $0.batters.contains { $0.id == id } }),
              let card = batInn.batters.first(where: { $0.id == id }) else { return nil }
        var x = 6.0
        if card.batted {
            x += Double(card.runs - 18) / 20
            if card.balls >= 8 { x += (card.strikeRate - 135) / 110 }
            if card.runs == 0 && card.dismissal != nil { x -= 0.8 }
            if card.runs >= 50 { x += 0.3 }
            if card.runs >= 100 { x += 0.4 }
        }
        if let bowl = inns.first(where: { $0.teamId != batInn.teamId })?.bowlers.first(where: { $0.id == id }), bowl.balls > 0 {
            x += Double(bowl.wickets) * 0.5
            if bowl.balls >= 12 { x += (8.5 - bowl.economy) / 3.5 }
        }
        if let winnerId, winnerId == batInn.teamId { x += 0.3 }
        if let potmId, potmId == id { x += 0.3 }
        // Soft edges: big days still stand out, but a 9 or 10 is rare and a 3 rarer.
        if x > 8 { x = 8 + (x - 8) * 0.45 }
        if x < 5 { x = 5 - (5 - x) * 0.6 }
        return (max(3, min(10, x)) * 10).rounded() / 10
    }

    /// Has the player done anything yet (batted or bowled)? Ratings of the others read "–".
    static func involved(_ id: String, cards: [InningsCard]) -> Bool {
        cards.prefix(2).contains { inn in
            inn.batters.contains { $0.id == id && $0.batted } || inn.bowlers.contains { $0.id == id && $0.balls > 0 }
        }
    }

    // MARK: Key numbers

    struct Numbers: Equatable {
        var innings = 0
        var battingTeam = 0
        var runs = 0
        var wickets = 0
        var balls = 0
        var maxBalls = 120
        var runRate = 0.0
        /// Chasing only.
        var target: Int? = nil
        var requiredRate: Double? = nil
        /// Batting first only: the current rate over the full innings.
        var projected: Int? = nil
        var fours = 0
        var sixes = 0
        var extras = 0
        var dotPercent = 0
        var partnershipRuns = 0
        var partnershipBalls = 0
        /// Runs in the last five overs (or fewer, early on).
        var lastFive = 0

        var ballsLeft: Int { max(0, maxBalls - balls) }
        var runsNeeded: Int? { target.map { max(0, $0 - runs) } }
    }

    private static func isLegal(_ e: BallEvent) -> Bool { e.label != "wd" && e.label != "nb" }

    /// The innings in progress at ball `shown` (nil before the first ball).
    static func numbers(cards: [InningsCard], log: [BallEvent], upTo shown: Int) -> Numbers? {
        let shown = max(0, min(shown, log.count))
        guard shown > 0 else { return nil }
        let now = log[shown - 1]
        let idx = now.innings
        guard let card = cards.indices.contains(idx) ? cards[idx] : cards.last else { return nil }
        let events = log.prefix(shown).filter { $0.innings == idx }
        var n = Numbers()
        n.innings = idx
        n.battingTeam = card.teamId
        n.runs = now.score
        n.wickets = now.wickets
        n.balls = events.filter(isLegal).count
        n.maxBalls = idx < 2 ? 120 : 6
        n.runRate = n.balls > 0 ? Double(n.runs) * 6 / Double(n.balls) : 0
        if idx % 2 == 1, cards.indices.contains(idx - 1) {
            let target = cards[idx - 1].runs + 1
            n.target = target
            n.requiredRate = n.ballsLeft > 0 ? Double(max(0, target - n.runs)) * 6 / Double(n.ballsLeft) : nil
        } else {
            n.projected = n.balls >= 6 ? Int((Double(n.runs) + n.runRate * Double(n.ballsLeft) / 6).rounded()) : nil
        }
        n.fours = card.batters.map(\.fours).reduce(0, +)
        n.sixes = card.batters.map(\.sixes).reduce(0, +)
        n.extras = card.extras
        n.dotPercent = n.balls > 0 ? events.filter { $0.label == "0" }.count * 100 / n.balls : 0
        // Partnership: since the last wicket.
        if let w = events.lastIndex(where: { $0.label == "W" || $0.outId != nil }) {
            let base = events[w].score
            n.partnershipRuns = n.runs - base
            n.partnershipBalls = events[(w + 1)...].filter(isLegal).count
        } else {
            n.partnershipRuns = n.runs
            n.partnershipBalls = n.balls
        }
        let base = events.last { $0.over <= now.over - 5 && isLegal($0) && $0.ballInOver == 6 }?.score ?? 0
        n.lastFive = n.runs - (now.over >= 5 ? base : 0)
        return n
    }

    // MARK: Assistant

    /// One to three things the assistant would say now, most urgent first, for `userTeam`. Advice
    /// that matches the current setting (already attacking, say) is left out.
    static func advice(cards: [InningsCard], log: [BallEvent], upTo shown: Int, userTeam: Int,
                       intent: BatIntent? = nil, field: FieldSetting? = nil) -> [String] {
        guard let n = numbers(cards: cards, log: log, upTo: shown) else {
            return ["The players are walking out. Settings take effect from the first ball."]
        }
        let shown = max(0, min(shown, log.count))
        let now = log[shown - 1]
        let card = cards.indices.contains(n.innings) ? cards[n.innings] : cards.last
        let f1 = { (x: Double) in String(format: "%.1f", x) }
        var out: [String] = []
        let batting = n.battingTeam == userTeam
        let pair = now.batters.map(\.name)

        if batting {
            if let rrr = n.requiredRate, let need = n.runsNeeded, need > 0 {
                if rrr >= n.runRate + 2, rrr >= 9, intent != .attack {
                    out.append("We need \(need) off \(n.ballsLeft) (\(f1(rrr)) an over) and we're scoring \(f1(n.runRate)). Switch batting to Attack.")
                } else if rrr <= 7, n.wickets <= 5, intent == .attack {
                    out.append("Only \(f1(rrr)) an over needed with \(10 - n.wickets) wickets left. Rotate and see it home.")
                }
            }
            if n.wickets >= 3, now.over < 6, intent != .block {
                out.append("\(n.wickets) down in the powerplay. Block for a few overs and rebuild.")
            }
            if n.balls >= 18, n.dotPercent >= 45, intent == .block {
                out.append("\(n.dotPercent)% dot balls. Rotate the strike or the rate will run away.")
            }
            if n.partnershipRuns >= 50, pair.count == 2 {
                out.append("\(pair[0]) and \(pair[1]) have added \(n.partnershipRuns) off \(n.partnershipBalls). Keep them going.")
            }
            // The opposition's bowlers: see off the best, go after the worst.
            let bowlers = (card?.bowlers ?? []).filter { $0.balls >= 12 && $0.balls < 24 }
            if let best = bowlers.min(by: { $0.economy < $1.economy }), best.economy <= 6.5 {
                out.append("\(best.name) has gone for \(f1(best.economy)) an over. See him off and attack the others.")
            } else if let worst = bowlers.max(by: { $0.economy < $1.economy }), worst.economy >= 10 {
                out.append("\(worst.name) is going at \(f1(worst.economy)) an over. Target him.")
            }
        } else {
            let mine = (card?.bowlers ?? []).filter { $0.balls >= 12 }
            if let costly = mine.filter({ $0.balls < 24 }).max(by: { $0.economy < $1.economy }), costly.economy >= 10 {
                out.append("\(costly.name) is going at \(f1(costly.economy)) an over. Change the next bowler in the Bowling tab.")
            }
            if let star = mine.filter({ $0.balls < 24 && $0.wickets >= 2 }).max(by: { $0.wickets < $1.wickets }) {
                out.append("\(star.name) has \(star.wickets) for \(star.runs) with overs left. Keep him on.")
            }
            if n.partnershipRuns >= 40, field != .attack, pair.count == 2 {
                out.append("\(pair[0]) and \(pair[1]) have added \(n.partnershipRuns). Set the field to Aggressive for a wicket.")
            }
            if let rrr = n.requiredRate, rrr >= 11, field != .defend {
                out.append("They need \(f1(rrr)) an over. Set the field to Defensive and squeeze them.")
            } else if n.target == nil, now.over >= 15, n.runRate >= 10, field != .defend {
                out.append("They're scoring \(f1(n.runRate)) an over at the death. Set the field to Defensive.")
            }
        }
        if out.isEmpty { out.append("Everything is going to plan. No changes needed.") }
        return Array(out.prefix(3))
    }

    // MARK: Innings break

    /// Median first-innings totals in career matches (probe, 400 matches a pitch).
    static func par(_ pitch: Pitch) -> Int {
        switch pitch {
        case .indianFlat: return 190
        case .englishSeam: return 140
        case .aussieBounce: return 170
        case .dustyTurner: return 160
        case .caribbeanSlow: return 160
        }
    }

    /// The assistant at the innings break (owner's request): what the first innings means for
    /// `userTeam` and how to play the second, most important first. `tactics` are the user's now.
    static func breakAdvice(first: InningsCard, pitch: Pitch, userTeam: Int, tactics: Tactics) -> [String] {
        let total = first.runs
        let par = par(pitch)
        let diff = total - par
        let suits = GamePlan.suggested(for: pitch)
        var out: [String] = []
        if first.teamId == userTeam {
            // Defending.
            if diff >= 15 {
                out.append("\(total) is \(diff) above par (about \(par)) on a \(pitch.label.lowercased()). Make them take risks: keep it tight and squeeze at the death.")
            } else if diff <= -15 {
                out.append("\(total) is \(-diff) below par (about \(par)). You need wickets: set an Aggressive field in the powerplay.")
            } else {
                out.append("\(total) is about par for a \(pitch.label.lowercased()) (\(par)). Early wickets win this.")
            }
        } else {
            // Chasing.
            let rate = Double(total + 1) / 20
            let r = String(format: "%.2f", rate)
            if diff >= 15 {
                out.append("We need \(total + 1) at \(r) an over, \(diff) above par. Go hard in the powerplay: Attack, or the Powerplay blitz plan.")
            } else if diff <= -15 {
                out.append("\(total + 1) to win at \(r) an over, below par. Keep wickets in hand: Rotate, then attack at the death.")
            } else {
                out.append("\(total + 1) to win at \(r) an over, a par chase. Don't lose early wickets.")
            }
        }
        if tactics.matchingPlan != suits {
            out.append("\(suits.label) is the plan that suits a \(pitch.label.lowercased()). You're on \(tactics.matchingPlan?.label ?? "custom tactics").")
        }
        return out
    }
}
