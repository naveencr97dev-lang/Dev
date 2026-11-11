import Foundation

// MARK: - Results

enum Stage: String, Codable, CaseIterable {
    case league, qualifier1, eliminator, qualifier2, final
    // International (career mode)
    case series, group, superEight, semiFinal

    /// Knockout and playoff matches: Big-Match players lift.
    var isBigGame: Bool { ![.league, .series, .group].contains(self) }

    var label: String {
        switch self {
        case .league: return "League"
        case .qualifier1: return "Qualifier 1"
        case .eliminator: return "Eliminator"
        case .qualifier2: return "Qualifier 2"
        case .final: return "FINAL"
        case .series: return "T20I"
        case .group: return "Group stage"
        case .superEight: return "Super 8"
        case .semiFinal: return "Semi-final"
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
    /// Cumulative wickets at the end of each over (optional so older saves still load).
    var overWickets: [Int]? = nil

    /// Runs and wickets in each over (Manhattan chart).
    var perOver: [(runs: Int, wickets: Int)] {
        let wk = overWickets ?? []
        return overRuns.indices.map { i in
            (overRuns[i] - (i > 0 ? overRuns[i - 1] : 0),
             i < wk.count ? wk[i] - (i > 0 && i - 1 < wk.count ? wk[i - 1] : 0) : 0)
        }
    }
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
    /// Key moments, in match order (optional so older saves still load).
    var highlights: [Highlight]? = nil
    /// Super-over innings in order (pairs; more than one pair if a super over was tied too).
    var superOvers: [InningsCard]? = nil

    var loserId: Int { winnerId == teamA ? teamB : teamA }

    /// Innings by log index: 0-1 the match, 2+ the super overs.
    func card(_ index: Int) -> InningsCard {
        if index < innings.count { return innings[index] }
        let so = superOvers ?? []
        let i = index - innings.count
        return i < so.count ? so[i] : innings[innings.count - 1]
    }

    /// The team not batting in innings `index`.
    func fieldingTeam(_ index: Int) -> Int { card(index).teamId == teamA ? teamB : teamA }

    /// Target in a chase (innings 1, 3, 5…), else nil.
    func target(forInnings index: Int) -> Int? { index % 2 == 1 ? card(index - 1).runs + 1 : nil }

    /// Balls available in innings `index` (120, or 6 in a super over).
    func maxBalls(_ index: Int) -> Int { index < 2 ? card(index).maxBalls : 6 }
}

/// A key moment kept with the result for the post-match highlights reel.
struct Highlight: Codable, Hashable {
    enum Kind: String, Codable {
        case six, four, wicket, fifty, hundred, bigOver, winningRuns, defended, superOver
    }
    let kind: Kind
    let innings: Int
    let over: String      // "17.3"
    let teamId: Int       // batting team at the time
    let text: String
    let score: String     // "165/4"
    let priority: Int
    let seq: Int
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
    // Who did what (for the scorecard-so-far while paused).
    var strikerId = ""
    var nonStrikerId = ""
    var bowlerId = ""
    var runsOffBat = 0
    var outId: String? = nil
    var how: String? = nil
}

/// A change made during a live match (career): applies from innings `innings`, legal ball
/// `fromBall` onwards, to team `teamId` (its batting or its bowling, whichever applies).
/// Re-simulating with the same seed reproduces every earlier ball exactly.
struct LiveChange: Codable, Hashable {
    let innings: Int
    let fromBall: Int
    let teamId: Int
    var tactics: Tactics? = nil
    /// Full batting order (ids); only batters not yet in are moved.
    var battingOrder: [String]? = nil
    /// Five bowlers in plan order (slots 1-2 new ball and death).
    var bowlingPlan: [String]? = nil
    /// Who bowls the next over (once).
    var nextOverBowler: String? = nil
    /// Bowlers taken off for the rest of the innings (owner's request: one going for 20 an over
    /// shouldn't bowl again). Their overs go to the rest of the plan, then other bowling options.
    var restBowlers: [String]? = nil

    func applies(innings i: Int, ball: Int) -> Bool { i > innings || (i == innings && ball >= fromBall) }
}

// MARK: - Tactics

enum FieldSetting: String, Codable, CaseIterable {
    case attack, balanced, defend
    var label: String { self == .attack ? "Aggressive" : (self == .defend ? "Defensive" : "Balanced") }
    var blurb: String {
        switch self {
        case .attack: return "Catchers in: more wickets, more boundaries"
        case .balanced: return "Standard field"
        case .defend: return "Sweepers out: fewer boundaries, fewer wickets"
        }
    }
}

enum BatIntent: String, Codable, CaseIterable {
    case block, rotate, attack
    var label: String { rawValue.capitalized }
    var blurb: String {
        switch self {
        case .block: return "See it off: fewer wickets, fewer runs"
        case .rotate: return "Normal game"
        case .attack: return "Go hard: more sixes, more risk"
        }
    }
}

/// What to do on winning the toss.
enum TossCall: String, Codable, CaseIterable {
    case batFirst, bowlFirst
    var label: String { self == .batFirst ? "Bat first" : "Bowl first" }
}

/// A batter's individual brief, on top of the phase intent.
enum BatRole: String, Codable, CaseIterable {
    case anchor, normal, hitter
    var label: String { rawValue.capitalized }
    var blurb: String {
        switch self {
        case .anchor: return "Bats through the innings: fewer risks, fewer sixes"
        case .normal: return "Plays to the phase plan"
        case .hitter: return "Swings from ball one: more sixes, more risk"
        }
    }
}

/// Per phase (powerplay, middle, death), plus the toss call, captain and batting roles (career).
struct Tactics: Codable, Hashable {
    var field: [FieldSetting] = [.balanced, .balanced, .balanced]
    var intent: [BatIntent] = [.rotate, .rotate, .rotate]
    /// nil = the captain reads the pitch (the old behaviour). Optional fields so old saves load.
    var toss: TossCall? = nil
    var captain: String? = nil
    var roles: [String: BatRole]? = nil
    /// The game plan last applied (nil = custom).
    var plan: String? = nil
    static let phases = ["Powerplay (1-6)", "Middle (7-16)", "Death (17-20)"]
}

// MARK: - Engine

struct MatchEngine {
    var rng: SeededRNG
    /// Candidate moments collected while simulating; the best are kept.
    var moments: [Highlight] = []

    init(rng: SeededRNG) { self.rng = rng }

    static let maxHighlights = 12

    private mutating func moment(_ kind: Highlight.Kind, _ innings: Int, balls: Int, team: Int, _ text: String,
                                 score: String, priority: Int) {
        guard innings < 2 else { return }   // super-over balls are summarised separately
        moments.append(Highlight(kind: kind, innings: innings, over: "\(balls / 6).\(balls % 6)", teamId: team,
                                 text: text, score: score, priority: priority, seq: moments.count))
    }

    struct Side {
        let teamId: Int
        let xi: [Player]   // batting order
        /// Custom bowling plan (5 bowlers); nil = captain picks for the pitch.
        var attack: [Player]? = nil
        /// Field settings and batting intent per phase (career mode); nil = neutral.
        var tactics: Tactics? = nil
    }

    /// Tactics of the sides in the current innings.
    var battingTactics: Tactics? = nil
    var bowlingTactics: Tactics? = nil
    /// Changes made during a live match, in time order (empty = the normal simulation).
    var liveChanges: [LiveChange] = []

    /// Playoff match: Big-Match players lift.
    var bigGame = false
    /// Career mode: chases pace like real ones (no risk-free cruising, fewer suicidal collapses).
    /// Off by default, so the quick game's calibrated numbers stay unchanged.
    var realisticChase = false

    /// Simulates a full T20 between two XIs.
    mutating func play(_ a: Side, _ b: Side, stage: Stage, pitch: Pitch, log: inout [BallEvent]) -> MatchResult {
        moments = []
        bigGame = stage.isBigGame
        let tossWinner = rng.unit() < 0.5 ? a : b
        let other = tossWinner.teamId == a.teamId ? b : a
        // Captains bowl first more often when the pitch helps bowlers early.
        let bowlFirstChance = pitch == .englishSeam ? 0.75 : (pitch == .indianFlat ? 0.6 : 0.5)
        var batFirst = rng.unit() < bowlFirstChance ? other : tossWinner
        // A manager's toss call overrides the captain (the draw above is still made, so nothing else moves).
        if let call = tossWinner.tactics?.toss { batFirst = call == .batFirst ? tossWinner : other }
        let bowlFirst = batFirst.teamId == a.teamId ? b : a

        let first = innings(batting: batFirst, bowling: bowlFirst, target: nil, maxOvers: 20, index: 0, pitch: pitch, log: &log)
        let second = innings(batting: bowlFirst, bowling: batFirst, target: first.runs + 1, maxOvers: 20, index: 1, pitch: pitch, log: &log)

        var winner: Side
        var margin: String
        var superOver = false
        var superOvers: [InningsCard] = []
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
            let so = decideSuperOver(batFirst, bowlFirst, pitch: pitch, log: &log)
            winner = so.0
            superOvers = so.1
            if superOvers.count >= 2 {
                let a = superOvers[superOvers.count - 2], b = superOvers[superOvers.count - 1]
                margin = "won the Super Over (\(a.score) v \(b.score))"
            } else {
                margin = "won the Super Over"
            }
        }

        if superOver {
            moment(.superOver, 1, balls: second.balls, team: winner.teamId, "Scores level — decided in a Super Over",
                   score: second.score, priority: 100)
        } else if winner.teamId == batFirst.teamId {
            moment(.defended, 1, balls: second.balls, team: batFirst.teamId, "\(first.runs) defended — \(margin)",
                   score: second.score, priority: 100)
        }
        let picked = moments.sorted { $0.priority > $1.priority }.prefix(MatchEngine.maxHighlights)
            .sorted { $0.seq < $1.seq }

        let potm = playerOfTheMatch([first, second], winnerId: winner.teamId, sides: [a, b])
        var result = MatchResult(id: UUID(uuid: uuid()), stage: stage, teamA: a.teamId, teamB: b.teamId, pitch: pitch,
                           tossWinner: tossWinner.teamId, innings: [first, second], winnerId: winner.teamId,
                           margin: margin, superOver: superOver, potmId: potm.0.id, potmName: potm.0.name,
                           potmTeam: potm.1)
        result.highlights = Array(picked)
        result.superOvers = superOvers.isEmpty ? nil : superOvers
        return result
    }

    private mutating func uuid() -> uuid_t {
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 { bytes[i] = UInt8.random(in: 0...255, using: &rng) }
        return (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
    }

    /// Plays super overs (the side that batted second bats first) until one is decided.
    /// Their balls go into the log as innings 2, 3, 4… so the live view can show them.
    private mutating func decideSuperOver(_ x: Side, _ y: Side, pitch: Pitch,
                                          log: inout [BallEvent]) -> (Side, [InningsCard]) {
        var cards: [InningsCard] = []
        let top = { (s: Side) in Side(teamId: s.teamId, xi: Array(s.xi.prefix(3))) }
        for round in 0..<5 {
            let i1 = innings(batting: top(y), bowling: x, target: nil, maxOvers: 1, index: 2 + round * 2, pitch: pitch, log: &log)
            let i2 = innings(batting: top(x), bowling: y, target: i1.runs + 1, maxOvers: 1, index: 3 + round * 2, pitch: pitch, log: &log)
            cards += [i1, i2]
            if i1.runs != i2.runs { return (i1.runs > i2.runs ? y : x, cards) }
        }
        return (rng.unit() < 0.5 ? x : y, cards)
    }

    // MARK: Innings

    /// Bowling plan for 20 overs: five bowlers x 4 overs, best two up front and at the death.
    static let overPlan = [0, 1, 0, 1, 2, 3, 4, 2, 3, 4, 2, 3, 4, 2, 1, 3, 0, 4, 0, 1]

    /// Bowling skill on this pitch (type suits the surface, home conditions).
    static func effectiveBowl(_ p: Player, pitch: Pitch) -> Int {
        p.bowl >= 25 ? p.bowl + pitch.bonus(for: p.bowlType) + pitch.homeBonus(p) : p.bowl
    }

    /// Overs each plan slot bowls (1-based), from `overPlan`.
    static func overs(forSlot slot: Int) -> [Int] {
        overPlan.enumerated().filter { $0.element == slot }.map { $0.offset + 1 }
    }

    /// Skill adjustment for a bowler in a phase: swing up front, specialists at the death,
    /// spin through the middle.
    static func phaseFit(_ p: Player, _ phase: BowlPhase, pitch: Pitch?) -> Int {
        let spin = p.bowlType == .spin
        switch phase {
        case .powerplay:
            return (p.has(.newBallSwing) ? 6 : 0) + (spin && pitch != .dustyTurner ? -4 : 0)
        case .middle:
            return (spin ? 3 : 0) + (p.has(.middleOversBoss) ? 4 : 0) + (!spin && pitch == .dustyTurner ? -3 : 0)
        case .death:
            return (p.has(.deathSpecialist) ? 6 : 0) + (p.has(.slowerBallMaster) ? 3 : 0) + (spin ? -5 : 0)
        }
    }

    /// Fit for a bowling-plan slot (0-1 new ball + death, 2-4 middle overs), from traits alone.
    /// Above 3 "suits", below 0 "poor" (Bowling plan › JOB FIT).
    static func slotFit(_ p: Player, slot: Int) -> Int {
        slot < 2 ? phaseFit(p, .powerplay, pitch: nil) + phaseFit(p, .death, pitch: nil) : phaseFit(p, .middle, pitch: nil)
    }
    static let slotSuits = 3

    /// Captain's choice: best five for the pitch, with the new-ball/death slots (overs 1-4 and 15-20)
    /// going to the bowlers who suit those phases best.
    static func autoAttack(_ xi: [Player], pitch: Pitch?) -> [Player] {
        let eff = { (p: Player) in pitch.map { effectiveBowl(p, pitch: $0) } ?? p.bowl }
        let five = Array(xi.sorted { eff($0) > eff($1) }.prefix(5))
        let edge = { (p: Player) in eff(p) + phaseFit(p, .powerplay, pitch: pitch) + phaseFit(p, .death, pitch: pitch) }
        let ends = Array(five.sorted { edge($0) > edge($1) }.prefix(2))
        let middle = five.filter { p in !ends.contains(p) }.sorted { eff($0) + phaseFit($0, .middle, pitch: pitch) > eff($1) + phaseFit($1, .middle, pitch: pitch) }
        return ends + middle
    }

    mutating func innings(batting: Side, bowling: Side, target: Int?, maxOvers: Int, index: Int, pitch: Pitch,
                          log: inout [BallEvent]) -> InningsCard {
        var card = InningsCard(teamId: batting.teamId)
        card.maxBalls = maxOvers * 6
        battingTactics = batting.tactics
        bowlingTactics = bowling.tactics
        card.batters = batting.xi.map { BatterCard(id: $0.id, name: $0.name) }
        let attack: [Player]
        if maxOvers == 20, let plan = bowling.attack, plan.count == 5 {
            attack = plan
        } else if maxOvers == 20 {
            attack = MatchEngine.autoAttack(bowling.xi, pitch: pitch)
        } else {
            attack = Array(bowling.xi.sorted { MatchEngine.effectiveBowl($0, pitch: pitch) > MatchEngine.effectiveBowl($1, pitch: pitch) }.prefix(1))
        }
        card.bowlers = attack.map { BowlerCard(id: $0.id, name: $0.name) }
        // Live changes can reorder the batting still to come and the bowling plan.
        var order = batting.xi
        var attackList = attack
        var applied = Set<Int>()
        var usedNextOver = Set<Int>()
        var rested = Set<String>()
        var lastOverBowler: String? = nil
        /// Deliveries bowled so far this innings (before the first, even the openers can change).
        var delivered = 0
        let liveOK = maxOvers == 20 && !liveChanges.isEmpty
        func applyChanges() {
            guard liveOK else { return }
            for (k, ch) in liveChanges.enumerated() where !applied.contains(k) && ch.applies(innings: index, ball: card.balls) {
                applied.insert(k)
                if let t = ch.tactics {
                    if ch.teamId == batting.teamId { battingTactics = t }
                    if ch.teamId == bowling.teamId { bowlingTactics = t }
                }
                if ch.teamId == batting.teamId, let ids = ch.battingOrder {
                    let keep = delivered == 0 ? 0 : nextIn
                    let fixed = Array(order.prefix(keep))
                    let rest = order.dropFirst(keep).sorted { (ids.firstIndex(of: $0.id) ?? 99) < (ids.firstIndex(of: $1.id) ?? 99) }
                    order = fixed + rest
                    let byId = Dictionary(uniqueKeysWithValues: card.batters.map { ($0.id, $0) })
                    card.batters = order.compactMap { byId[$0.id] }
                    if keep == 0 {
                        for i in card.batters.indices { card.batters[i].batted = i < 2 }
                    }
                }
                if ch.teamId == bowling.teamId, let ids = ch.restBowlers { rested.formUnion(ids) }
                if ch.teamId == bowling.teamId, let ids = ch.bowlingPlan {
                    let plan = ids.compactMap { id in bowling.xi.first { $0.id == id } }
                    if plan.count == 5 && Set(plan.map(\.id)).count == 5 { attackList = plan }
                }
            }
        }
        /// Index into card.bowlers for this over's bowler (adds a card for a new bowler).
        func bowlerIndex(over: Int) -> Int {
            guard maxOvers == 20 else { return 0 }
            let can = { (p: Player) -> Bool in
                (card.bowlers.first { $0.id == p.id }?.balls ?? 0) < 24 && p.id != lastOverBowler && !rested.contains(p.id)
            }
            var pick = attackList[MatchEngine.overPlan[over] % attackList.count]
            if liveOK {
                for (k, ch) in liveChanges.enumerated() where ch.teamId == bowling.teamId && !usedNextOver.contains(k)
                    && ch.applies(innings: index, ball: card.balls) {
                    guard let id = ch.nextOverBowler else { continue }
                    usedNextOver.insert(k)
                    if let p = bowling.xi.first(where: { $0.id == id }), can(p) { pick = p }
                }
                if !can(pick) {
                    // The rest of the plan first, then the XI's best other bowlers; part-timers last.
                    let others = bowling.xi.filter { o in !attackList.contains { $0.id == o.id } }
                        .sorted { MatchEngine.effectiveBowl($0, pitch: pitch) > MatchEngine.effectiveBowl($1, pitch: pitch) }
                    if let alt = (attackList + others).first(where: can) { pick = alt }
                    // Nobody legal left (everyone rested or bowled out): ignore the rests, never the laws.
                    else if let alt = (attackList + others).first(where: { p in
                        (card.bowlers.first { $0.id == p.id }?.balls ?? 0) < 24 && p.id != lastOverBowler }) { pick = alt }
                }
            }
            if let i = card.bowlers.firstIndex(where: { $0.id == pick.id }) { return i }
            card.bowlers.append(BowlerCard(id: pick.id, name: pick.name))
            return card.bowlers.count - 1
        }
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

        /// Records who did what on the ball just logged.
        func tag(striker s: String, runs: Int, outId: String? = nil, how: String? = nil, bowlerId: String) {
            guard !log.isEmpty else { return }
            log[log.count - 1].strikerId = s
            log[log.count - 1].nonStrikerId = nonStriker < order.count ? order[nonStriker].id : ""
            log[log.count - 1].bowlerId = bowlerId
            log[log.count - 1].runsOffBat = runs
            log[log.count - 1].outId = outId
            log[log.count - 1].how = how
        }

        overs: for over in 0..<maxOvers {
            applyChanges()
            let bi = bowlerIndex(over: over)
            let bowler = maxOvers == 20 ? (bowling.xi.first { $0.id == card.bowlers[bi].id } ?? attack[0]) : attack[0]
            lastOverBowler = bowler.id
            let runsAtOverStart = card.runs
            let deathOvers = over >= maxOvers - 4
            var legal = 0
            while legal < 6 {
                if let t = target, card.runs >= t { break overs }
                applyChanges()

                // Wides
                if rng.unit() < 0.035 {
                    card.runs += 1; card.extras += 1
                    card.bowlers[bi].runs += 1
                    let snap = snapshot(bi)
                    log.append(BallEvent(innings: index, over: over, ballInOver: legal, label: "wd",
                                         text: "Wide", score: card.runs, wickets: card.wickets,
                                         batters: snap.0, bowler: snap.1))
                    tag(striker: order[striker].id, runs: 0, bowlerId: bowler.id)
                    delivered += 1
                    if index == 1, let t = target, card.runs >= t {
                        moment(.winningRuns, index, balls: card.balls, team: batting.teamId,
                               "A wide from \(bowler.name) seals it!", score: card.score, priority: 100)
                    }
                    continue
                }

                let batter = order[striker]
                let (outcome, batTrait, bowlTrait) = ball(batter: batter, bowler: bowler, over: over, maxOvers: maxOvers,
                                                          card: card, target: target, maxWickets: maxWickets, pitch: pitch,
                                                          position: striker, faced: card.batters[striker].balls)
                legal += 1
                delivered += 1
                card.balls += 1
                card.bowlers[bi].balls += 1
                card.batters[striker].balls += 1

                var text: String
                var label: String
                var lastOut: (String, String)? = nil
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
                    moment(.wicket, index, balls: card.balls, team: batting.teamId, text, score: card.score,
                           priority: 40 + min(out.runs, 60) / 2 + (deathOvers ? 5 : 0) + (bowlTrait != nil && bowlerCredit ? 5 : 0))
                    if card.wickets >= maxWickets || nextIn >= order.count {
                        card.allOut = true
                        let snap = snapshot(bi)
                        log.append(BallEvent(innings: index, over: over, ballInOver: legal, label: label, text: text,
                                             score: card.runs, wickets: card.wickets, batters: snap.0, bowler: snap.1))
                        tag(striker: batter.id, runs: 0, outId: out.id, how: how, bowlerId: bowler.id)
                        break overs
                    }
                    lastOut = (out.id, how)
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
                    let fifty = r - outcome < 50 && r >= 50 && r < 100
                    let hundred = r - outcome < 100 && r >= 100
                    if fifty { text += " — FIFTY for \(batter.name)!" }
                    if hundred { text += " — HUNDRED for \(batter.name)!" }
                    label = "\(outcome)"
                    let won = index == 1 && target.map { card.runs >= $0 } == true
                    if won {
                        let shot = outcome == 6 ? "a SIX" : outcome == 4 ? "a FOUR" : "\(outcome) run\(outcome == 1 ? "" : "s")"
                        moment(.winningRuns, index, balls: card.balls, team: batting.teamId,
                               "\(batter.name) finishes it with \(shot)!", score: card.score, priority: 100)
                    } else if hundred {
                        moment(.hundred, index, balls: card.balls, team: batting.teamId,
                               "HUNDRED for \(batter.name)! \(r) off \(card.batters[striker].balls)", score: card.score, priority: 95)
                    } else if fifty {
                        moment(.fifty, index, balls: card.balls, team: batting.teamId,
                               "FIFTY for \(batter.name) — \(r) off \(card.batters[striker].balls)", score: card.score, priority: 70)
                    } else if outcome == 6 {
                        moment(.six, index, balls: card.balls, team: batting.teamId, text, score: card.score,
                               priority: 25 + (deathOvers ? 10 : 0) + (batTrait != nil ? 5 : 0))
                    } else if outcome == 4 && deathOvers && target != nil {
                        moment(.four, index, balls: card.balls, team: batting.teamId, text, score: card.score, priority: 20)
                    }
                    if outcome % 2 == 1 { swap(&striker, &nonStriker) }
                }
                let snap = snapshot(bi)
                log.append(BallEvent(innings: index, over: over, ballInOver: legal, label: label, text: text,
                                     score: card.runs, wickets: card.wickets, batters: snap.0, bowler: snap.1))
                tag(striker: batter.id, runs: outcome == -1 ? 0 : outcome, outId: lastOut?.0, how: lastOut?.1, bowlerId: bowler.id)
            }
            card.overRuns.append(card.runs)
            card.overWickets = (card.overWickets ?? []) + [card.wickets]
            let overRuns = card.runs - runsAtOverStart
            let chaseDone = target.map { card.runs >= $0 } ?? false
            if overRuns >= 16 && maxOvers == 20 && !chaseDone {
                moment(.bigOver, index, balls: card.balls, team: batting.teamId,
                       "\(overRuns) runs off the over from \(bowler.name)", score: card.score, priority: 55 + (overRuns - 16) * 3)
            }
            swap(&striker, &nonStriker)
        }
        // Close the last, partial over (also catches a chase won by a wide before any legal ball).
        if card.overRuns.last != card.runs || (card.overWickets?.last ?? 0) != card.wickets {
            card.overRuns.append(card.runs)
            card.overWickets = (card.overWickets ?? []) + [card.wickets]
        }
        return card
    }

    // MARK: Ball outcome

    /// Returns runs (0,1,2,3,4,6) or -1 for a wicket, plus the traits that shaped the ball.
    mutating func ball(batter: Player, bowler: Player, over: Int, maxOvers: Int, card: InningsCard,
                       target: Int?, maxWickets: Int, pitch: Pitch, position: Int = 3, faced: Int = 10) -> (Int, Trait?, Trait?) {
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
        // Conditions, batting position and bowling phase.
        batSkill += Double(pitch.homeBonus(batter))
        if maxOvers == 20 { batSkill += Double(batter.slot.fit(position: position)) }
        var bowlSkill = Double(MatchEngine.effectiveBowl(bowler, pitch: pitch))
        if maxOvers == 20 {
            bowlSkill += Double(MatchEngine.phaseFit(bowler, powerplay ? .powerplay : (death ? .death : .middle), pitch: pitch))
        }
        if bigGame {
            if batter.has(.bigMatch) { batSkill += 8; batTrait = .bigMatch }
            if bowler.has(.bigMatch) { bowlSkill += 8; bowlTrait = .bigMatch }
        }
        let d = max(-2.2, min(1.6, (batSkill - bowlSkill) / 50))
        let boost = exp(0.42 * d)
        w[0] /= boost
        w[4] *= boost
        w[5] *= pow(boost, 1.5)
        w[6] /= pow(boost, 1.8)

        // Role clarity: in their slot a batter plays freely; out of it they look lost.
        if maxOvers == 20 {
            let dist = batter.slot.distance(position: position)
            if dist == 0 {
                w[6] *= 0.92; w[4] *= 1.05; w[5] *= 1.05
            } else if dist >= 2 {
                let k = Double(dist - 1)
                w[6] *= 1 + 0.35 * k; w[4] *= max(0.5, 1 - 0.12 * k); w[5] *= max(0.4, 1 - 0.15 * k); w[0] *= 1 + 0.08 * k
            }
            // Settling in: new batters are vulnerable, set batters cash in.
            if faced < 6 { w[6] *= 1.3; w[4] *= 0.8; w[5] *= 0.75 }
            else if faced >= 25 { w[6] *= 0.85; w[4] *= 1.1; w[5] *= 1.12 }
        }
        // A tail-ender in the top order: no technique to survive, no shots to score.
        if maxOvers == 20 && batter.isExposed(atPosition: position) {
            w[6] *= 1.9; w[4] *= 0.55; w[5] *= 0.45; w[0] *= 1.25
        }

        // Batting traits.
        let chasing = target != nil
        if batter.has(.powerHitter) { w[5] *= 1.4; w[6] *= 1.05; batTrait = batTrait ?? .powerHitter }
        if batter.has(.anchor) { w[6] *= 0.75; w[5] *= 0.8; w[1] *= 1.1; batTrait = batTrait ?? .anchor }
        if batter.has(.finisher) && death { w[4] *= 1.25; w[5] *= 1.4; w[6] *= 0.85; batTrait = .finisher }
        if batter.has(.powerplayBlitz) && powerplay { w[4] *= 1.35; w[5] *= 1.3; w[6] *= 1.05; batTrait = .powerplayBlitz }
        if batter.has(.chaseMaster) && chasing { w[6] *= 0.8; w[4] *= 1.1; w[5] *= 1.1; batTrait = batTrait ?? .chaseMaster }
        if batter.has(.flatTrackBully) {
            if pitch == .indianFlat || pitch == .aussieBounce { w[4] *= 1.15; w[5] *= 1.2; batTrait = batTrait ?? .flatTrackBully }
            else if pitch == .englishSeam || pitch == .dustyTurner { w[6] *= 1.15 }
        }
        if batter.has(.technician) && (pitch == .englishSeam || pitch == .dustyTurner) { w[6] *= 0.8; batTrait = batTrait ?? .technician }
        let shortBallThreat = !spin && (pitch == .aussieBounce || bowler.has(.expressPace) || bowler.has(.bounceMerchant))
        if batter.has(.shortBallKing) && shortBallThreat { w[4] *= 1.2; w[5] *= 1.25; w[6] *= 0.85; batTrait = .shortBallKing }

        // Bowling traits.
        let readsSpin = batter.has(.spinBasher) || batter.has(.threeSixty)
        if bowler.has(.mysterySpin) && !readsSpin { w[6] *= 1.3; w[0] *= 1.1; bowlTrait = .mysterySpin }
        if bowler.has(.newBallSwing) && powerplay {
            var m = pitch.swings ? 1.6 : 1.35
            if batter.has(.technician) { m = 1 + (m - 1) * 0.5 }
            w[6] *= m; w[4] *= 0.85; bowlTrait = .newBallSwing
        }
        if bowler.has(.slowerBallMaster) && (death || pitch == .caribbeanSlow || pitch == .dustyTurner) {
            w[5] *= batter.has(.powerHitter) ? 0.7 : 0.8; w[6] *= 1.15; bowlTrait = bowlTrait ?? .slowerBallMaster
        }
        if bowler.has(.bounceMerchant) && !batter.has(.shortBallKing) {
            let bouncy = pitch == .aussieBounce
            w[6] *= bouncy ? 1.3 : 1.1; w[4] *= 0.92
            bowlTrait = bouncy ? .bounceMerchant : (bowlTrait ?? .bounceMerchant)
        }
        if bowler.has(.turnerTerror) && (pitch == .dustyTurner || pitch == .caribbeanSlow) && !readsSpin {
            w[6] *= batter.has(.technician) ? 1.15 : 1.35; w[0] *= 1.1; bowlTrait = .turnerTerror
        }
        if bowler.has(.middleOversBoss) && !powerplay && !death { w[4] *= 0.8; w[5] *= 0.8; w[6] *= 1.1; bowlTrait = bowlTrait ?? .middleOversBoss }
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
        // Early collapse: rebuild before attacking again.
        if card.wickets >= 3 && over < 10 && maxOvers == 20 { aggression = max(-0.45, aggression - 0.3) }

        // Tactics: batting intent shifts aggression; the field trades boundaries for wickets.
        let phaseIndex = powerplay ? 0 : (death ? 2 : 1)
        // The batter's own brief (career): anchors cut risk, hitters swing.
        if maxOvers == 20, let role = battingTactics?.roles?[batter.id] {
            switch role {
            case .anchor: w[6] *= 0.8; w[5] *= 0.75; w[4] *= 0.93; w[1] *= 1.1
            case .hitter: w[5] *= 1.35; w[4] *= 1.08; w[6] *= 1.2; w[0] *= 0.95
            case .normal: break
            }
        }
        if maxOvers == 20, let t = battingTactics, phaseIndex < t.intent.count {
            // Risk depends on the surface: swinging on a seamer or a turner costs far more wickets
            // than on a flat track (the probe found All-out attack best on every pitch before this).
            let risk = pitch.wicketMult / 0.95
            // Owner's request (device test): the setting has to be felt. Block roughly halves the
            // wickets and the batters stop chasing the rate (no swinging when told to block); Attack
            // scores clearly faster for clearly more wickets.
            switch t.intent[phaseIndex] {
            case .attack: w[4] *= 1.12; w[5] *= 1.25; w[6] *= 1.15 * risk; w[0] *= 0.95
            case .block:
                w[4] *= 0.7; w[5] *= 0.4; w[6] *= 0.5; w[1] *= 1.15; w[0] *= 1.12
                aggression = min(aggression, 0)
            case .rotate: break
            }
        }
        if maxOvers == 20, let t = bowlingTactics, phaseIndex < t.field.count {
            // An attacking field leaks more on a fast, flat outfield.
            switch t.field[phaseIndex] {
            case .attack: w[6] *= 1.12; w[4] *= 1.04 * pitch.fourMult; w[5] *= 1.02 * pitch.sixMult
            case .defend: w[6] *= 0.84; w[4] *= 0.88; w[5] *= 0.96; w[1] *= 1.1
            case .balanced: break
            }
        }

        if aggression > 0 {
            w[4] *= 1 + 0.5 * aggression
            w[5] *= 1 + aggression
            w[6] *= 1 + (realisticChase ? 0.35 : 0.8) * aggression
            w[0] *= 1 + 0.2 * aggression
        } else if aggression < 0 {
            w[5] *= 1 + aggression
            // Career: easy chases still lose wickets (mishits, pressure); only boundaries dry up.
            w[6] *= 1 + (realisticChase ? 0.25 : 0.7) * aggression
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

// MARK: - Scorecard so far

extension MatchEngine {
    /// The scorecard up to (not including) log index `shown`: no spoilers while a match is paused.
    /// Batting and bowling orders come from the final cards; figures come from the balls shown.
    static func scorecardSoFar(result r: MatchResult, log: [BallEvent], upTo shown: Int) -> [InningsCard] {
        let events = log.prefix(max(0, min(shown, log.count)))
        let inningsSeen = Set(events.map(\.innings))
        var cards: [InningsCard] = []
        for i in inningsSeen.sorted() {
            let final = r.card(i)
            var card = InningsCard(teamId: final.teamId)
            card.maxBalls = r.maxBalls(i)
            card.batters = final.batters.map { BatterCard(id: $0.id, name: $0.name) }
            card.bowlers = final.bowlers.map { BowlerCard(id: $0.id, name: $0.name) }
            func bat(_ id: String) -> Int? { card.batters.firstIndex { $0.id == id } }
            func bowl(_ id: String) -> Int? { card.bowlers.firstIndex { $0.id == id } }
            var overs: [Int: (Int, Int)] = [:]
            for e in events where e.innings == i {
                if let s = bat(e.strikerId) { card.batters[s].batted = true }
                if let n = bat(e.nonStrikerId) { card.batters[n].batted = true }
                if e.label == "wd" {
                    card.runs += 1; card.extras += 1
                    if let b = bowl(e.bowlerId) { card.bowlers[b].runs += 1 }
                } else {
                    card.balls += 1
                    if let b = bowl(e.bowlerId) { card.bowlers[b].balls += 1; card.bowlers[b].runs += e.runsOffBat }
                    if let s = bat(e.strikerId) {
                        card.batters[s].balls += 1
                        card.batters[s].runs += e.runsOffBat
                        if e.runsOffBat == 4 { card.batters[s].fours += 1 }
                        if e.runsOffBat == 6 { card.batters[s].sixes += 1 }
                    }
                    card.runs += e.runsOffBat
                    if let out = e.outId {
                        card.wickets += 1
                        if let o = bat(out) { card.batters[o].dismissal = e.how; card.batters[o].batted = true }
                        if let b = bowl(e.bowlerId), !(e.how ?? "").hasPrefix("run out") { card.bowlers[b].wickets += 1 }
                    }
                }
                overs[e.over] = (card.runs, card.wickets)
            }
            card.overRuns = overs.keys.sorted().map { overs[$0]!.0 }
            card.overWickets = overs.keys.sorted().map { overs[$0]!.1 }
            card.allOut = card.wickets >= card.batters.count - 1
            card.bowlers = card.bowlers.filter { $0.balls > 0 || $0.runs > 0 }
            cards.append(card)
        }
        return cards
    }
}
