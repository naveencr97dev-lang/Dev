import Foundation

// MARK: - Players

enum Role: String, Codable, CaseIterable {
    case BAT, WK, AR, BOWL

    var label: String {
        switch self {
        case .BAT: return "Batter"
        case .WK: return "Wicket-keeper"
        case .AR: return "All-rounder"
        case .BOWL: return "Bowler"
        }
    }

    var short: String {
        switch self {
        case .BAT: return "BAT"
        case .WK: return "WK"
        case .AR: return "AR"
        case .BOWL: return "BOWL"
        }
    }
}

struct Player: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let role: Role
    let overseas: Bool
    let country: String
    /// Base price in lakhs (100 lakhs = 1 crore).
    let base: Int
    /// Auction pool: Marquee, Batters, All-rounders, Wicket-keepers, Bowlers, Uncapped.
    let pool: String
    let rating: Int
    let bat: Int
    let bowl: Int
    let line: String
    let bowlType: BowlType
    let traits: [Trait]
    /// Where this player bats best.
    let slot: BatSlot
    /// Retired IPL great (vs a current star).
    let legend: Bool

    var isLegend: Bool { legend }
    func has(_ t: Trait) -> Bool { traits.contains(t) }

    /// A tail-ender sent into the top six is badly exposed.
    func isExposed(atPosition i: Int) -> Bool { bat < 40 && i < 6 }

    /// Can be trusted with 4 overs.
    var isBowlingOption: Bool { bowl >= 40 }
    var isTopOrderBat: Bool { bat >= 55 }
}

enum BowlType: String, Codable {
    case pace, spin
}

/// Batting slot groups. Batting a player in his slot gives a bonus, far out of it a penalty.
enum BatSlot: String, Codable, CaseIterable {
    case open, top, middle, finish, lower

    var ordinal: Int { BatSlot.allCases.firstIndex(of: self)! }

    init(position i: Int) {
        switch i {
        case 0, 1: self = .open
        case 2, 3: self = .top
        case 4: self = .middle
        case 5, 6: self = .finish
        default: self = .lower
        }
    }

    var label: String {
        switch self {
        case .open: return "OPENER"
        case .top: return "TOP ORDER"
        case .middle: return "MIDDLE"
        case .finish: return "FINISHER"
        case .lower: return "LOWER ORDER"
        }
    }

    /// How many slot groups away from their best a player is batting.
    func distance(position: Int) -> Int { abs(BatSlot(position: position).ordinal - ordinal) }

    /// Batting-skill adjustment for a player who prefers `self` batting at `position`.
    func fit(position: Int) -> Int {
        switch distance(position: position) {
        case 0: return 6
        case 1: return 2
        case 2: return -8
        case 3: return -16
        default: return -26
        }
    }
}

/// Bowling phases in a T20 innings.
enum BowlPhase: Int {
    case powerplay, middle, death
}

/// Signature skills for legends. They change the ball-by-ball odds in specific match-ups.
enum Trait: String, Codable, CaseIterable {
    // Batting
    case powerHitter, anchor, finisher, spinBasher, paceBasher, powerplayBlitz, chaseMaster, threeSixty
    case flatTrackBully, technician, shortBallKing
    // Either
    case bigMatch
    // Bowling
    case deathSpecialist, newBallSwing, mysterySpin, economical, wicketTaker, expressPace
    case slowerBallMaster, bounceMerchant, turnerTerror, middleOversBoss

    var isBatting: Bool {
        switch self {
        case .powerHitter, .anchor, .finisher, .spinBasher, .paceBasher, .powerplayBlitz, .chaseMaster, .threeSixty,
             .flatTrackBully, .technician, .shortBallKing, .bigMatch: return true
        default: return false
        }
    }

    var isBowling: Bool { !isBatting || self == .bigMatch }

    /// Pitches where this trait comes alive.
    var pitches: [Pitch] {
        switch self {
        case .flatTrackBully: return [.indianFlat, .aussieBounce]
        case .technician: return [.englishSeam, .dustyTurner]
        case .shortBallKing, .bounceMerchant: return [.aussieBounce]
        case .newBallSwing: return [.englishSeam]
        case .turnerTerror: return [.dustyTurner, .caribbeanSlow]
        case .slowerBallMaster: return [.caribbeanSlow, .dustyTurner]
        case .spinBasher: return [.dustyTurner]
        default: return []
        }
    }

    var label: String {
        switch self {
        case .powerHitter: return "Power Hitter"
        case .anchor: return "Anchor"
        case .finisher: return "Finisher"
        case .spinBasher: return "Spin Basher"
        case .paceBasher: return "Pace Basher"
        case .powerplayBlitz: return "Powerplay Blitz"
        case .chaseMaster: return "Chase Master"
        case .threeSixty: return "360° Player"
        case .deathSpecialist: return "Death Specialist"
        case .newBallSwing: return "New-Ball Swing"
        case .mysterySpin: return "Mystery Spin"
        case .economical: return "Miser"
        case .wicketTaker: return "Wicket Taker"
        case .expressPace: return "Express Pace"
        case .flatTrackBully: return "Flat-Track Bully"
        case .technician: return "Technician"
        case .shortBallKing: return "Short-Ball King"
        case .bigMatch: return "Big-Match Player"
        case .slowerBallMaster: return "Slower-Ball Master"
        case .bounceMerchant: return "Bounce Merchant"
        case .turnerTerror: return "Turner Terror"
        case .middleOversBoss: return "Middle-Overs Boss"
        }
    }

    var icon: String {
        switch self {
        case .powerHitter: return "💥"
        case .anchor: return "⚓️"
        case .finisher: return "🏁"
        case .spinBasher: return "🌀"
        case .paceBasher: return "⚡️"
        case .powerplayBlitz: return "🚀"
        case .chaseMaster: return "🎯"
        case .threeSixty: return "🔄"
        case .deathSpecialist: return "☠️"
        case .newBallSwing: return "🌪️"
        case .mysterySpin: return "🎩"
        case .economical: return "🔒"
        case .wicketTaker: return "🪓"
        case .expressPace: return "🔥"
        case .flatTrackBully: return "🛣️"
        case .technician: return "📐"
        case .shortBallKing: return "🪝"
        case .bigMatch: return "👑"
        case .slowerBallMaster: return "🐢"
        case .bounceMerchant: return "🦘"
        case .turnerTerror: return "🌀"
        case .middleOversBoss: return "🧱"
        }
    }

    var blurb: String {
        switch self {
        case .powerHitter: return "Clears the rope far more often"
        case .anchor: return "Rarely gives it away, fewer big shots"
        case .finisher: return "Explodes in the last 4 overs"
        case .spinBasher: return "Dominates spin bowling"
        case .paceBasher: return "Feasts on pace"
        case .powerplayBlitz: return "Attacks hard in the powerplay"
        case .chaseMaster: return "Calm and lethal in a chase"
        case .threeSixty: return "Scores all round the ground vs anyone"
        case .deathSpecialist: return "Yorkers and slower balls at the death"
        case .newBallSwing: return "Lethal with the new ball, deadlier in swing conditions"
        case .mysterySpin: return "Unreadable — unless the batter bashes spin"
        case .economical: return "Bleeds very few boundaries"
        case .wicketTaker: return "Strikes often, at a price"
        case .expressPace: return "Rushes batters, but edges fly to the rope"
        case .flatTrackBully: return "Murders flat decks, struggles when it seams or turns"
        case .technician: return "Survives seam, swing and turn"
        case .shortBallKing: return "Pulls and hooks pace and bounce"
        case .bigMatch: return "Raises their game in the playoffs"
        case .slowerBallMaster: return "Cutters and slower balls — deadly at the death and on slow decks"
        case .bounceMerchant: return "Hits the deck hard — lethal on bouncy pitches"
        case .turnerTerror: return "Rips it on turning and slow pitches"
        case .middleOversBoss: return "Chokes runs and takes wickets in overs 7–16"
        }
    }
}

/// Pitch conditions change scoring and which bowling type thrives.
enum Pitch: String, Codable, CaseIterable, Identifiable {
    case indianFlat, englishSeam, aussieBounce, dustyTurner, caribbeanSlow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .indianFlat: return "Indian Flat Track"
        case .englishSeam: return "English Seamer"
        case .aussieBounce: return "Aussie Bouncer"
        case .dustyTurner: return "Dusty Turner"
        case .caribbeanSlow: return "Caribbean Slow"
        }
    }

    var icon: String {
        switch self {
        case .indianFlat: return "🛣️"
        case .englishSeam: return "🌧️"
        case .aussieBounce: return "🦘"
        case .dustyTurner: return "🏜️"
        case .caribbeanSlow: return "🌴"
        }
    }

    var blurb: String {
        switch self {
        case .indianFlat: return "Batting paradise — 200 is par"
        case .englishSeam: return "Overcast, swing and seam — tricky"
        case .aussieBounce: return "Pace and carry, fast outfield"
        case .dustyTurner: return "Spinners rule, runs are hard"
        case .caribbeanSlow: return "Slow and low — grind it out"
        }
    }

    /// Multipliers on four/six weights.
    var fourMult: Double { [1.15, 0.88, 1.05, 0.84, 0.8][index] }
    var sixMult: Double { [1.25, 0.85, 1.1, 0.78, 0.75][index] }
    var wicketMult: Double { [0.9, 1.2, 1.08, 1.15, 1.05][index] }
    /// Rating points added to a bowler of that type.
    var paceBonus: Int { [-4, 12, 10, -8, -4][index] }
    var spinBonus: Int { [0, -6, -4, 14, 10][index] }
    var swings: Bool { self == .englishSeam }

    private var index: Int { Pitch.allCases.firstIndex(of: self)! }

    /// Countries whose players feel at home here (+5 skill).
    var homeCountries: [String] {
        switch self {
        case .indianFlat: return ["IND"]
        case .englishSeam: return ["ENG", "NZ"]
        case .aussieBounce: return ["AUS", "SA"]
        case .dustyTurner: return ["IND", "SL", "AFG", "BAN"]
        case .caribbeanSlow: return ["WI"]
        }
    }

    func homeBonus(_ p: Player) -> Int { homeCountries.contains(p.country) ? 5 : 0 }

    /// Pitches a player is likely to enjoy (home conditions or a condition trait).
    static func favoured(by p: Player) -> [Pitch] {
        Pitch.allCases.filter { pitch in
            pitch.homeCountries.contains(p.country) || p.traits.contains { $0.pitches.contains(pitch) }
        }
    }

    func bonus(for type: BowlType) -> Int { type == .spin ? spinBonus : paceBonus }
}

enum PitchMode: Codable, Hashable {
    case mixed
    case fixed(Pitch)

    var label: String {
        switch self {
        case .mixed: return "Mixed venues"
        case .fixed(let p): return p.label
        }
    }
}

enum PlayerDB {
    static func decode(_ data: Data) throws -> [Player] {
        try JSONDecoder().decode([Player].self, from: data)
    }
}

// MARK: - Money (all amounts are in lakhs)

enum Money {
    static func format(_ lakhs: Int) -> String {
        if lakhs >= 100 {
            let cr = Double(lakhs) / 100
            var s = String(format: "%.2f", cr)
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
            return "₹\(s) Cr"
        }
        return "₹\(lakhs) L"
    }
}

// MARK: - Franchises

struct Franchise: Codable, Identifiable, Hashable {
    var id: Int
    var name: String
    var short: String
    var colorHex: String
    var isCPU: Bool
    var purse: Int = 0
    var squad: [String] = []
    /// Price paid per player id.
    var paid: [String: Int] = [:]
    /// Playing XI in batting order.
    var xi: [String] = []
    /// CPU bidding temperament (0.85 cautious ... 1.2 aggressive).
    var personality: Double = 1.0
    /// Custom bowling plan: five player ids (slot 1-2 new ball + death, 3-5 middle). Empty = auto.
    var bowlingOrder: [String] = []
}

struct FranchiseTemplate {
    let name: String
    let short: String
    let color: String

    /// Fictional franchise names — not affiliated with any real league.
    static let all: [FranchiseTemplate] = [
        .init(name: "Mumbai Monsoons", short: "MUM", color: "#2563EB"),
        .init(name: "Chennai Chargers", short: "CHE", color: "#EAB308"),
        .init(name: "Bengaluru Blazers", short: "BLR", color: "#DC2626"),
        .init(name: "Kolkata Kites", short: "KOL", color: "#7C3AED"),
        .init(name: "Delhi Defenders", short: "DEL", color: "#0EA5E9"),
        .init(name: "Hyderabad Hawks", short: "HYD", color: "#F97316"),
        .init(name: "Punjab Panthers", short: "PUN", color: "#E11D48"),
        .init(name: "Rajasthan Raiders", short: "RAJ", color: "#EC4899"),
        .init(name: "Lucknow Lions", short: "LKO", color: "#06B6D4"),
        .init(name: "Gujarat Gladiators", short: "GUJ", color: "#14B8A6"),
    ]
}

// MARK: - Rules

struct Rules: Codable, Hashable {
    var purse: Int = 10_000          // ₹100 Cr
    /// Squads are exactly one XI.
    var minSquad: Int = 11
    var maxSquad: Int = 11
    var maxOverseasSquad: Int = 4
    var maxOverseasXI: Int = 4
    var bidSeconds: Double = 8
    var doubleRoundRobin: Bool = false
    var pitchMode: PitchMode = .mixed
    /// Fixed raise per bid in lakhs; 0 = IPL-style sliding increments.
    var bidStep: Int = 0

    static let bidSteps = [0, 25, 50, 100, 200]

    static func bidStepLabel(_ step: Int) -> String {
        step == 0 ? "IPL-style (+5 L → +25 L)" : "+\(Money.format(step)) per bid"
    }

    init() {}

    // Tolerant decoding so saves from older versions still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Rules()
        purse = try c.decodeIfPresent(Int.self, forKey: .purse) ?? d.purse
        minSquad = try c.decodeIfPresent(Int.self, forKey: .minSquad) ?? d.minSquad
        maxSquad = try c.decodeIfPresent(Int.self, forKey: .maxSquad) ?? d.maxSquad
        maxOverseasSquad = try c.decodeIfPresent(Int.self, forKey: .maxOverseasSquad) ?? d.maxOverseasSquad
        maxOverseasXI = try c.decodeIfPresent(Int.self, forKey: .maxOverseasXI) ?? d.maxOverseasXI
        bidSeconds = try c.decodeIfPresent(Double.self, forKey: .bidSeconds) ?? d.bidSeconds
        doubleRoundRobin = try c.decodeIfPresent(Bool.self, forKey: .doubleRoundRobin) ?? d.doubleRoundRobin
        pitchMode = try c.decodeIfPresent(PitchMode.self, forKey: .pitchMode) ?? d.pitchMode
        bidStep = try c.decodeIfPresent(Int.self, forKey: .bidStep) ?? d.bidStep
        minBase = d.minBase
    }
    /// Lowest base price in the pool; used to reserve purse for the minimum squad.
    var minBase: Int = 50
}
