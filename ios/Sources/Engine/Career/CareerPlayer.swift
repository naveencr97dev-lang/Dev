import Foundation

/// Detailed skills (1-99). Match ratings (bat/bowl) are derived from these.
struct Attributes: Codable, Hashable {
    // Batting
    var technique: Int
    var power: Int
    var vsPace: Int
    var vsSpin: Int
    var temperament: Int
    // Bowling ("potency" is pace for seamers, turn for spinners)
    var accuracy: Int
    var potency: Int
    var variation: Int
    var death: Int
    var newBall: Int
    // Other
    var fielding: Int
    var keeping: Int

    static let batKeys: [WritableKeyPath<Attributes, Int>] = [\.technique, \.power, \.vsPace, \.vsSpin, \.temperament]
    static let bowlKeys: [WritableKeyPath<Attributes, Int>] = [\.accuracy, \.potency, \.variation, \.death, \.newBall]
    static let batWeights: [Double] = [0.25, 0.2, 0.2, 0.2, 0.15]
    static let bowlWeights: [Double] = [0.25, 0.25, 0.2, 0.15, 0.15]

    var bat: Int { Attributes.weighted(self, Attributes.batKeys, Attributes.batWeights) }
    var bowl: Int { Attributes.weighted(self, Attributes.bowlKeys, Attributes.bowlWeights) }

    private static func weighted(_ a: Attributes, _ keys: [WritableKeyPath<Attributes, Int>], _ w: [Double]) -> Int {
        Int(zip(keys, w).reduce(0.0) { $0 + Double(a[keyPath: $1.0]) * $1.1 }.rounded())
    }

    static func clamp(_ v: Int) -> Int { max(1, min(99, v)) }

    /// Adds `delta` spread over a group of attributes (keeps the group's shape).
    mutating func shift(_ keys: [WritableKeyPath<Attributes, Int>], by delta: Int) {
        for k in keys { self[keyPath: k] = Attributes.clamp(self[keyPath: k] + delta) }
    }

    /// Builds attributes whose derived bat/bowl match the given ratings, shaped by traits.
    static func seeded(bat: Int, bowl: Int, keeper: Bool, traits: [Trait], rng: inout SeededRNG) -> Attributes {
        func jitter() -> Int { Int.random(in: -5...5, using: &rng) }
        var a = Attributes(technique: bat + jitter(), power: bat + jitter(), vsPace: bat + jitter(),
                           vsSpin: bat + jitter(), temperament: bat + jitter(),
                           accuracy: bowl + jitter(), potency: bowl + jitter(), variation: bowl + jitter(),
                           death: bowl + jitter(), newBall: bowl + jitter(),
                           fielding: 55 + Int.random(in: -15...25, using: &rng),
                           keeping: keeper ? 70 + Int.random(in: 0...20, using: &rng) : Int.random(in: 5...30, using: &rng))
        // Style from traits.
        for t in traits {
            switch t {
            case .powerHitter: a.power += 8; a.technique -= 5
            case .anchor: a.technique += 6; a.temperament += 6; a.power -= 8
            case .spinBasher: a.vsSpin += 8
            case .paceBasher, .shortBallKing: a.vsPace += 8
            case .technician: a.technique += 8
            case .chaseMaster, .bigMatch: a.temperament += 6
            case .deathSpecialist, .slowerBallMaster: a.death += 8
            case .newBallSwing: a.newBall += 8
            case .mysterySpin: a.variation += 8
            case .economical: a.accuracy += 8
            case .expressPace, .bounceMerchant, .turnerTerror: a.potency += 8
            case .wicketTaker: a.potency += 5; a.accuracy -= 3
            default: break
            }
        }
        for k in batKeys + bowlKeys { a[keyPath: k] = clamp(a[keyPath: k]) }
        a.fielding = clamp(a.fielding)
        a.keeping = clamp(a.keeping)
        // Re-centre so the derived ratings equal the targets.
        a.shift(batKeys, by: bat - a.bat)
        a.shift(bowlKeys, by: bowl - a.bowl)
        return a
    }
}

/// Career totals across seasons.
struct CareerStats: Codable, Hashable {
    var matches = 0
    var runs = 0
    var ballsFaced = 0
    var fours = 0
    var sixes = 0
    var fifties = 0
    var hundreds = 0
    var highScore = 0
    var wickets = 0
    var ballsBowled = 0
    var runsConceded = 0
    var potm = 0
    var titles = 0

    var average: Double { matches == 0 ? 0 : Double(runs) / Double(max(1, matches)) }
    var strikeRate: Double { ballsFaced == 0 ? 0 : Double(runs) * 100 / Double(ballsFaced) }
    var economy: Double { ballsBowled == 0 ? 0 : Double(runsConceded) * 6 / Double(ballsBowled) }
}

/// A player in career mode: ages, develops, has form and a club.
struct CareerPlayer: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    let country: String
    var role: Role
    let bowlType: BowlType
    var slot: BatSlot
    var traits: [Trait]
    let born: Int
    var attr: Attributes
    /// Ceiling for the player's main skill (hidden until scouted, from M3).
    var potential: Int
    /// Recent form, -10 (awful) … +10 (red hot).
    var form: Int = 0
    var legend: Bool
    var generated: Bool
    var line: String
    /// nil = free agent.
    var clubId: Int?
    var retired = false
    var stats = CareerStats()
    /// Wage and expiry (nil for free agents; optional so v1 saves still decode).
    var contract: Contract? = nil
    /// In this club's youth academy (not in the squad, not a free agent).
    var academyOf: Int? = nil
    /// Finished seasons, oldest first (schema 7; optional so older saves load).
    var seasonLog: [SeasonLine]? = nil
    /// Rating when the season started (the development report shows the change; optional).
    var seasonStartRating: Int? = nil

    var bat: Int { attr.bat }
    var bowl: Int { attr.bowl }
    /// Overall: main skill plus a little for a useful second skill.
    var rating: Int {
        let hi = max(bat, bowl), lo = min(bat, bowl)
        return min(99, hi + (lo >= 40 ? (lo - 40) / 5 : 0))
    }
    /// The skill group a player is mainly picked for.
    var primaryIsBat: Bool { role == .BAT || role == .WK || (role == .AR && bat >= bowl) }

    func age(in year: Int) -> Int { year - born }
    var overseas: Bool { country != "IND" }

    /// Market value in lakhs, from rating and age.
    func value(in year: Int) -> Int {
        let base = 30 * exp(Double(rating - 50) * 0.1)
        let a = age(in: year)
        let ageFactor = a <= 23 ? 1.3 : (a <= 29 ? 1.0 : (a <= 32 ? 0.8 : 0.5))
        let potentialBoost = a <= 23 ? 1 + Double(max(0, potential - rating)) * 0.03 : 1
        return max(20, Int((base * ageFactor * potentialBoost / 5).rounded()) * 5)
    }

    /// Auction base price in lakhs (₹20 L … ₹2 Cr).
    func basePrice(in year: Int) -> Int {
        let v = value(in: year) / 4
        let steps = [20, 30, 50, 75, 100, 150, 200]
        return steps.last { $0 <= v } ?? 20
    }

    /// The match-engine view of this player, with form applied.
    func matchPlayer(formMatters: Bool = true, batBoost: Int = 0) -> Player {
        let f = formMatters ? form / 3 : 0
        let b = max(1, min(99, bat + f + batBoost))
        let w = bowl >= 25 ? max(1, min(99, bowl + f)) : bowl
        return Player(id: id, name: name, role: role, overseas: overseas, country: country,
                      base: 20, pool: legend ? "Legends" : "Stars", rating: rating, bat: b, bowl: w,
                      line: line, bowlType: bowlType, traits: traits, slot: slot, legend: legend)
    }
}

extension CareerPlayer {
    /// Bowling style in words: spin, or fast vs medium pace from the pace/turn attribute.
    var bowlingStyle: String? {
        guard bowl >= 50 else { return nil }
        if bowlType == .spin { return "spin" }
        return attr.potency >= 75 ? "fast" : "medium pace"
    }

    /// Batting job in words, from the preferred batting slot.
    var battingJob: String {
        switch slot {
        case .open: return "opener"
        case .top: return "top order"
        case .middle: return "middle order"
        case .finish: return "finisher"
        case .lower: return "lower order"
        }
    }

    /// The player's actual role, e.g. "Top-order batter", "Keeper · opener",
    /// "All-rounder · finisher · spin", "Fast bowler".
    var roleDescription: String {
        switch role {
        case .BAT:
            switch slot {
            case .open: return "Opening batter"
            case .finish: return "Finisher"
            default: return battingJob.prefix(1).uppercased() + battingJob.dropFirst() + " batter"
            }
        case .WK: return "Keeper · \(battingJob)"
        case .AR: return (["All-rounder", battingJob] + (bowlingStyle.map { [$0] } ?? [])).joined(separator: " · ")
        case .BOWL:
            let style = bowlingStyle ?? (bowlType == .spin ? "spin" : "medium pace")
            return style.prefix(1).uppercased() + style.dropFirst() + " bowler"
        }
    }
}
