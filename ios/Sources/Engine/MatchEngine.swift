import Foundation

// MARK: - Results

enum Stage: String, Codable, CaseIterable {
    case league, qualifier1, eliminator, qualifier2, final

    var label: String {
        switch self {
        case .league: return "League"
        case .qualifier1: return "Qualifier 1"
        case .eliminator: return "Eliminator"
        case .qualifier2: return "Qualifier 2"
        case .final: return "FINAL"
        }
    }
}

struct BatterCard: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    var runs = 0
    var balls = 0
    var fours = 0
    var sixes = 0
    var dismissal: String? = nil
    var batted = false

    var strikeRate: Double { balls == 0 ? 0 : Double(runs) * 100 / Double(balls) }
}

struct BowlerCard: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    var balls = 0
    var runs = 0
    var wickets = 0

    var overs: String { "\(balls / 6)" + (balls % 6 == 0 ? "" : ".\(balls % 6)") }
    var economy: Double { balls == 0 ? 0 : Double(runs) * 6 / Double(balls) }
}

struct InningsCard: Codable, Hashable {
    let teamId: Int
    var runs = 0
    var wickets = 0
    var balls = 0
    var extras = 0
    var batters: [BatterCard] = []
    var bowlers: [BowlerCard] = []
    /// Cumulative score at the end of each over (for the worm chart).
    var overRuns: [Int] = []
    var allOut = false
    var maxBalls = 120

    var overs: String { "\(balls / 6)" + (balls % 6 == 0 ? "" : ".\(balls % 6)") }
    var score: String { "\(runs)/\(wickets)" }
}

struct MatchResult: Codable, Hashable, Identifiable {
    let id: UUID
    let stage: Stage
    let teamA: Int
    let teamB: Int
    let pitch: Pitch
    let tossWinner: Int
    let innings: [InningsCard]
    let winnerId: Int
    let margin: String
    let superOver: Bool
    let potmId: String
    let potmName: String
    let potmTeam: Int

    var loserId: Int { winnerId == teamA ? teamB : teamA }
}

struct LiveBatter: Hashable {
    let name: String
    let runs: Int
    let balls: Int
    let fours: Int
    let sixes: Int
    let onStrike: Bool
}

struct LiveBowler: Hashable {
    let name: String
    let balls: Int
    let runs: Int
    let wickets: Int
    var overs: String { "\(balls / 6)" + (balls % 6 == 0 ? "" : ".\(balls % 6)") }
}

/// One delivery, for the live ticker (not saved).
struct BallEvent: Hashable {
    let innings: Int
    let over: Int        // 0-based
    let ballInOver: Int  // legal balls so far in the over, after this delivery
    let label: String    // "0", "1", "4", "6", "W", "wd"
    let text: String
    let score: Int
    let wickets: Int
    /// The two batters at the crease after this ball, and the bowler's figures.
    let batters: [LiveBatter]
    let bowler: LiveBowler
}

// MARK: - Engine

struct MatchEngine {
    var rng: SeededRNG

    struct Side {
        let teamId: Int
        let xi: [Player]   // batting order
    }

    /// Simulates a full T20 between two XIs.
    mutating func play(_ a: Side, _ b: Side, stage: Stage, pitch: Pitch, log: inout [BallEvent]) -> MatchResult {
        let tossWinner = rng.unit() < 0.5 ? a : b
        let other = tossWinner.teamId == a.teamId ? b : a
        // Captains bowl first more often when the pitch helps bowlers early.
        let bowlFirstChance = pitch == .englishSeam ? 0.75 : (pitch == .indianFlat ? 0.6 : 0.5)
        let batFirst = rng.unit() < bowlFirstChance ? other : tossWinner
        let bowlFirst = batFirst.teamId == a.teamId ? b : a

        let first = innings(batting: batFirst, bowling: bowlFirst, target: nil, maxOvers: 20, index: 0, pitch: pitch, log: &log)
        let second = innings(batting: bowlFirst, bowling: batFirst, target: first.runs + 1, maxOvers: 20, index: 1, pitch: pitch, log: &log)

        var winner: Side
        var margin: String
        var superOver = false
        if second.runs > first.runs {
            winner = bowlFirst
            let wkts = (bowlFirst.xi.count - 1) - second.wickets
            let left = second.maxBalls - second.balls
            margin = "won by \(wkts) wicket\(wkts == 1 ? "" : "s")" + (left > 0 ? " (\(left) ball\(left == 1 ? "" : "s") left)" : "")
        } else if first.runs > second.runs {
            winner = batFirst
            let r = first.runs - second.runs
            margin = "won by \(r) run\(r == 1 ? "" : "s")"
        } else {
            superOver = true
            winner = decideSuperOver(batFirst, bowlFirst, pitch: pitch)
            margin = "won the Super Over"
        }

        let potm = playerOfTheMatch([first, second], winnerId: winner.teamId, sides: [a, b])
        return MatchResult(id: UUID(uuid: uuid()), stage: stage, teamA: a.teamId, teamB: b.teamId, pitch: pitch,
                           tossWinner: tossWinner.teamId, innings: [first, second], winnerId: winner.teamId,
                           margin: margin, superOver: superOver, potmId: potm.0.id, potmName: potm.0.name,
                           potmTeam: potm.1)
    }

    private mutating func uuid() -> uuid_t {
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 { bytes[i] = UInt8.random(in: 0...255, using: &rng) }
        return (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
    }

    private mutating func decideSuperOver(_ x: Side, _ y: Side, pitch: Pitch) -> Side {
        for _ in 0..<5 {
            var discard: [BallEvent] = []
            let top = { (s: Side) in Side(teamId: s.teamId, xi: Array(s.xi.prefix(3))) }
            let i1 = innings(batting: top(x), bowling: y, target: nil, maxOvers: 1, index: 2, pitch: pitch, log: &discard)
            let i2 = innings(batting: top(y), bowling: x, target: i1.runs + 1, maxOvers: 1, index: 3, pitch: pitch, log: &discard)
            if i1.runs != i2.runs { return i1.runs > i2.runs ? x : y }
        }
        return rng.unit() < 0.5 ? x : y
    }

    // MARK: Innings

    /// Bowling plan for 20 overs: five bowlers x 4 overs, best two up front and at the death.
    static let overPlan = [0, 1, 0, 1, 2, 3, 4, 2, 3, 4, 2, 3, 4, 2, 1, 3, 0, 4, 0, 1]

    /// Bowling skill on this pitch.
    static func effectiveBowl(_ p: Player, pitch: Pitch) -> Int {
        p.bowl >= 25 ? p.bowl + pitch.bonus(for: p.bowlType) : p.bowl
    }

    mutating func innings(batting: Side, bowling: Side, target: Int?, maxOvers: Int, index: Int, pitch: Pitch,
                          log: inout [BallEvent]) -> InningsCard {
        var card = InningsCard(teamId: batting.teamId)
        card.maxBalls = maxOvers * 6
        card.batters = batting.xi.map { BatterCard(id: $0.id, name: $0.name) }
        // Captains pick the attack that suits the pitch; new-ball swing bowlers open.
        var attack = Array(bowling.xi.sorted { MatchEngine.effectiveBowl($0, pitch: pitch) > MatchEngine.effectiveBowl($1, pitch: pitch) }
            .prefix(maxOvers == 20 ? 5 : 1))
        if maxOvers == 20, let swinger = attack.firstIndex(where: { $0.has(.newBallSwing) }), swinger > 1 {
            attack.swapAt(1, swinger)
        }
        if maxOvers == 20, let death = attack.firstIndex(where: { $0.has(.deathSpecialist) }), death > 1 {
            attack.swapAt(0, death)   // slot 0 bowls overs 1, 3, 17 and 19
        }
        card.bowlers = attack.map { BowlerCard(id: $0.id, name: $0.name) }
        let maxWickets = max(1, batting.xi.count - 1)
        let fielders = bowling.xi
        let keeper = bowling.xi.first { $0.role == .WK }

        var striker = 0, nonStriker = 1, nextIn = 2
        card.batters[0].batted = true
        if card.batters.count > 1 { card.batters[1].batted = true }

        func snapshot(_ bi: Int) -> ([LiveBatter], LiveBowler) {
            let order = [striker, nonStriker].filter { $0 < card.batters.count }
            let bats = order.map { i -> LiveBatter in
                let b = card.batters[i]
                return LiveBatter(name: b.name, runs: b.runs, balls: b.balls, fours: b.fours, sixes: b.sixes, onStrike: i == striker)
            }
            let bw = card.bowlers[bi]
            return (bats, LiveBowler(name: bw.name, balls: bw.balls, runs: bw.runs, wickets: bw.wickets))
        }

        overs: for over in 0..<maxOvers {
            let bi = maxOvers == 20 ? MatchEngine.overPlan[over] % attack.count : 0
            let bowler = attack[bi]
            var legal = 0
            while legal < 6 {
                if let t = target, card.runs >= t { break overs }

                // Wides
                if rng.unit() < 0.035 {
                    card.runs += 1; card.extras += 1
                    card.bowlers[bi].runs += 1
                    let snap = snapshot(bi)
                    log.append(BallEvent(innings: index, over: over, ballInOver: legal, label: "wd",
                                         text: "Wide", score: card.runs, wickets: card.wickets,
                                         batters: snap.0, bowler: snap.1))
                    continue
                }

                let batter = batting.xi[striker]
                let (outcome, batTrait, bowlTrait) = ball(batter: batter, bowler: bowler, over: over, maxOvers: maxOvers,
                                                          card: card, target: target, maxWickets: maxWickets, pitch: pitch)
                legal += 1
                card.balls += 1
                card.bowlers[bi].balls += 1
                card.batters[striker].balls += 1

                var text: String
                var label: String
                if outcome == -1 {
                    let (how, bowlerCredit, runOutNonStriker) = dismissal(batter: batter, bowler: bowler,
                                                                          fielders: fielders, keeper: keeper)
                    let outIndex = runOutNonStriker ? nonStriker : striker
                    let out = card.batters[outIndex]
                    card.batters[outIndex].dismissal = how
                    card.wickets += 1
                    if bowlerCredit { card.bowlers[bi].wickets += 1 }
                    text = "OUT! \(out.name) \(how) — \(out.runs) (\(out.balls))"
                    if bowlerCredit, let t = bowlTrait { text += " · \(t.icon) \(t.label)" }
                    label = "W"
                    if card.wickets >= maxWickets || nextIn >= batting.xi.count {
                        card.allOut = true
                        let snap = snapshot(bi)
                        log.append(BallEvent(innings: index, over: over, ballInOver: legal, label: label, text: text,
                                             score: card.runs, wickets: card.wickets, batters: snap.0, bowler: snap.1))
                        break overs
                    }
                    card.batters[nextIn].batted = true
                    if runOutNonStriker { nonStriker = nextIn } else { striker = nextIn }
                    nextIn += 1
                } else {
                    card.runs += outcome
                    card.batters[striker].runs += outcome
                    card.bowlers[bi].runs += outcome
                    if outcome == 4 { card.batters[striker].fours += 1 }
                    if outcome == 6 { card.batters[striker].sixes += 1 }
                    switch outcome {
                    case 6: text = "SIX! \(batter.name) off \(bowler.name)"
                    case 4: text = "FOUR! \(batter.name)"
                    case 0: text = "Dot ball"
                    default: text = "\(outcome) run\(outcome == 1 ? "" : "s")"
                    }
                    if outcome >= 4, let t = batTrait { text += " · \(t.icon) \(t.label)" }
                    let r = card.batters[striker].runs
                    if r - outcome < 50 && r >= 50 { text += " — FIFTY for \(batter.name)!" }
                    if r - outcome < 100 && r >= 100 { text += " — HUNDRED for \(batter.name)!" }
                    label = "\(outcome)"
                    if outcome % 2 == 1 { swap(&striker, &nonStriker) }
                }
                let snap = snapshot(bi)
                log.append(BallEvent(innings: index, over: over, ballInOver: legal, label: label, text: text,
                                     score: card.runs, wickets: card.wickets, batters: snap.0, bowler: snap.1))
            }
            card.overRuns.append(card.runs)
            swap(&striker, &nonStriker)
        }
        if card.overRuns.count < (card.balls + 5) / 6 { card.overRuns.append(card.runs) }
        return card
    }

    // MARK: Ball outcome

    /// Returns runs (0,1,2,3,4,6) or -1 for a wicket, plus the traits that shaped the ball.
    mutating func ball(batter: Player, bowler: Player, over: Int, maxOvers: Int, card: InningsCard,
                       target: Int?, maxWickets: Int, pitch: Pitch) -> (Int, Trait?, Trait?) {
        // Weights for [0, 1, 2, 3, 4, 6, W] by phase.
        var w: [Double]
        let powerplay = over < 6 && maxOvers == 20
        let death = over >= maxOvers - 4 || maxOvers == 1
        if powerplay {
            w = [39, 31, 7, 1, 14.5, 5.6, 5.6]
        } else if !death {
            w = [35, 39, 9, 1, 9.3, 4.8, 4.9]
        } else {
            w = [29, 31, 8, 1, 13.5, 10, 8.6]
        }

        // Pitch.
        w[4] *= pitch.fourMult
        w[5] *= pitch.sixMult
        w[6] *= pitch.wicketMult

        // Skill: batter vs bowler (bowler adjusted for the pitch), plus match-up traits.
        var batSkill = Double(batter.bat)
        let spin = bowler.bowlType == .spin
        var batTrait: Trait? = nil
        var bowlTrait: Trait? = nil
        if batter.has(.spinBasher) && spin { batSkill += 18; batTrait = .spinBasher }
        if batter.has(.paceBasher) && !spin { batSkill += 18; batTrait = .paceBasher }
        if batter.has(.threeSixty) { batSkill += 10; batTrait = .threeSixty }
        let bowlSkill = Double(MatchEngine.effectiveBowl(bowler, pitch: pitch))
        let d = max(-1.6, min(1.6, (batSkill - bowlSkill) / 50))
        let boost = exp(0.42 * d)
        w[0] /= boost
        w[4] *= boost
        w[5] *= pow(boost, 1.5)
        w[6] /= pow(boost, 1.8)

        // Batting traits.
        let chasing = target != nil
        if batter.has(.powerHitter) { w[5] *= 1.4; w[6] *= 1.05; batTrait = batTrait ?? .powerHitter }
        if batter.has(.anchor) { w[6] *= 0.75; w[5] *= 0.8; w[1] *= 1.1; batTrait = batTrait ?? .anchor }
        if batter.has(.finisher) && death { w[4] *= 1.25; w[5] *= 1.4; w[6] *= 0.85; batTrait = .finisher }
        if batter.has(.powerplayBlitz) && powerplay { w[4] *= 1.35; w[5] *= 1.3; w[6] *= 1.05; batTrait = .powerplayBlitz }
        if batter.has(.chaseMaster) && chasing { w[6] *= 0.8; w[4] *= 1.1; w[5] *= 1.1; batTrait = batTrait ?? .chaseMaster }

        // Bowling traits.
        let readsSpin = batter.has(.spinBasher) || batter.has(.threeSixty)
        if bowler.has(.mysterySpin) && !readsSpin { w[6] *= 1.3; w[0] *= 1.1; bowlTrait = .mysterySpin }
        if bowler.has(.newBallSwing) && powerplay {
            let m = pitch.swings ? 1.6 : 1.35
            w[6] *= m; w[4] *= 0.85; bowlTrait = .newBallSwing
        }
        if bowler.has(.deathSpecialist) && death { w[4] *= 0.8; w[5] *= 0.7; w[6] *= 1.15; bowlTrait = .deathSpecialist }
        if bowler.has(.economical) { w[4] *= 0.85; w[5] *= 0.85; w[1] *= 1.05; bowlTrait = bowlTrait ?? .economical }
        if bowler.has(.wicketTaker) { w[6] *= 1.25; w[4] *= 1.08; w[5] *= 1.08; bowlTrait = bowlTrait ?? .wicketTaker }
        if bowler.has(.expressPace) {
            w[6] *= 1.2; w[4] *= 1.12
            if batter.has(.paceBasher) { w[4] *= 1.15; w[5] *= 1.15 }
            bowlTrait = bowlTrait ?? .expressPace
        }

        // Situation: chase pressure or consolidation.
        let ballsLeft = maxOvers * 6 - card.balls
        let wicketsLeft = maxWickets - card.wickets
        var aggression = 0.0
        if let t = target {
            let need = Double(t - card.runs)
            let rrr = need / Double(max(ballsLeft, 1)) * 6
            aggression = max(-0.45, min(1.0, (rrr - 8.5) / 6))
        } else if death && wicketsLeft >= 5 {
            aggression = 0.25
        }
        if wicketsLeft <= 3 && ballsLeft > 24 { aggression = min(aggression, -0.3) }

        if aggression > 0 {
            w[4] *= 1 + 0.5 * aggression
            w[5] *= 1 + aggression
            w[6] *= 1 + 0.8 * aggression
            w[0] *= 1 + 0.2 * aggression
        } else if aggression < 0 {
            w[5] *= 1 + aggression
            w[6] *= 1 + 0.7 * aggression
            w[4] *= 1 + 0.4 * aggression
            w[1] *= 1 - 0.4 * aggression
        }

        let outcomes = [0, 1, 2, 3, 4, 6, -1]
        return (outcomes[rng.weighted(w)], batTrait, bowlTrait)
    }

    /// Returns (text, credited to bowler, non-striker run out).
    mutating func dismissal(batter: Player, bowler: Player, fielders: [Player], keeper: Player?) -> (String, Bool, Bool) {
        let kind = rng.weighted([56, 20, 13, 7, 4])
        switch kind {
        case 0:
            let r = rng.unit()
            if r < 0.08 { return ("c & b \(bowler.name)", true, false) }
            if r < 0.28, let k = keeper { return ("c †\(k.name) b \(bowler.name)", true, false) }
            let f = fielders.filter { $0.id != bowler.id }.randomElement(using: &rng) ?? bowler
            return ("c \(f.name) b \(bowler.name)", true, false)
        case 1: return ("b \(bowler.name)", true, false)
        case 2: return ("lbw b \(bowler.name)", true, false)
        case 3:
            let f = fielders.randomElement(using: &rng) ?? bowler
            return ("run out (\(f.name))", false, rng.unit() < 0.4)
        default:
            if let k = keeper { return ("st †\(k.name) b \(bowler.name)", true, false) }
            return ("b \(bowler.name)", true, false)
        }
    }

    // MARK: Player of the match

    private func playerOfTheMatch(_ inns: [InningsCard], winnerId: Int, sides: [Side]) -> (Player, Int) {
        var best: (Player, Int)? = nil
        var bestScore = -Double.infinity
        for side in sides {
            for p in side.xi {
                var s = 0.0
                for c in inns {
                    if let b = c.batters.first(where: { $0.id == p.id }), b.batted {
                        s += Double(b.runs) + Double(b.sixes) * 2 + (b.balls >= 10 ? (b.strikeRate - 130) / 10 : 0)
                    }
                    if let bw = c.bowlers.first(where: { $0.id == p.id }), bw.balls > 0 {
                        s += Double(bw.wickets) * 25 + (8 - bw.economy) * Double(bw.balls) / 6 * 2
                    }
                }
                if side.teamId == winnerId { s += 10 }
                if s > bestScore { bestScore = s; best = (p, side.teamId) }
            }
        }
        return best ?? (sides[0].xi[0], sides[0].teamId)
    }
}
