import Foundation

// MARK: - Facilities

enum FacilityKind: String, Codable, CaseIterable, Identifiable {
    case stadium, trainingGround, youthAcademy, medical, scoutingNetwork, analytics, commercial

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stadium: return "Stadium"
        case .trainingGround: return "Training Ground"
        case .youthAcademy: return "Youth Academy"
        case .medical: return "Medical Centre"
        case .scoutingNetwork: return "Scouting Network"
        case .analytics: return "Analytics Room"
        case .commercial: return "Commercial Hub"
        }
    }

    var icon: String {
        switch self {
        case .stadium: return "🏟️"
        case .trainingGround: return "🏋️"
        case .youthAcademy: return "🎓"
        case .medical: return "🩺"
        case .scoutingNetwork: return "🔭"
        case .analytics: return "📊"
        case .commercial: return "🛍️"
        }
    }

    var effect: String {
        switch self {
        case .stadium: return "Gate money from every home match"
        case .trainingGround: return "Faster training; +1 drill slot at levels 3, 6 and 9"
        case .youthAcademy: return "Better academy intakes (more gems)"
        case .medical: return "Longer careers and less form lost to hard training"
        case .scoutingNetwork: return "+1 scout at levels 4, 7 and 10; scouts learn more"
        case .analytics: return "Match preparation: your XI plays a little above its ratings"
        case .commercial: return "Sponsor and merchandise money every season"
        }
    }
}

struct FacilityState: Codable, Hashable {
    /// Level by facility (1-10).
    var levels: [String: Int] = [:]
    /// Facility being upgraded and weeks (your matches) left.
    var building: String? = nil
    var weeksLeft = 0

    func level(_ k: FacilityKind) -> Int { levels[k.rawValue] ?? 1 }
}

// MARK: - Manager

enum PerkTree: String, Codable, CaseIterable {
    case training, boardroom, tactical
    var label: String { self == .training ? "Training" : (self == .boardroom ? "Boardroom" : "Tactical") }
}

enum Perk: String, Codable, CaseIterable, Identifiable {
    // Training
    case drillMaster, extraSession, youthMentor, veteranCare, fitnessGuru, ironBody, specialistCoach, netProgram
    // Boardroom
    case negotiator, dealmaker, starMagnet, auctionShark, sponsorFriend, crowdPuller, leanBuild, globalNetwork
    // Tactical
    case captainsCall, powerplayPlan, deathPlan, spinDoctor, settledSide, youthFaith, homeFortress, bigMatchTemperament

    var id: String { rawValue }

    var tree: PerkTree {
        let i = Perk.allCases.firstIndex(of: self)!
        return [PerkTree.training, .boardroom, .tactical][i / 8]
    }

    /// 1-3: tier within the tree (cost in points, and how many perks of the tree you need first).
    var tier: Int {
        let i = Perk.allCases.firstIndex(of: self)! % 8
        return i < 3 ? 1 : (i < 6 ? 2 : 3)
    }

    var cost: Int { tier }
    var requires: Int { tier == 1 ? 0 : (tier == 2 ? 2 : 4) }

    var label: String {
        switch self {
        case .drillMaster: return "Drill Master"
        case .extraSession: return "Extra Session"
        case .youthMentor: return "Youth Mentor"
        case .veteranCare: return "Veteran Care"
        case .fitnessGuru: return "Fitness Guru"
        case .ironBody: return "Iron Body"
        case .specialistCoach: return "Specialist Coach"
        case .netProgram: return "Net Program"
        case .negotiator: return "Negotiator"
        case .dealmaker: return "Dealmaker"
        case .starMagnet: return "Star Magnet"
        case .auctionShark: return "Auction Shark"
        case .sponsorFriend: return "Sponsor Friend"
        case .crowdPuller: return "Crowd Puller"
        case .leanBuild: return "Lean Build"
        case .globalNetwork: return "Global Network"
        case .captainsCall: return "Captain's Call"
        case .powerplayPlan: return "Powerplay Plan"
        case .deathPlan: return "Death Plan"
        case .spinDoctor: return "Spin Doctor"
        case .settledSide: return "Settled Side"
        case .youthFaith: return "Youth Faith"
        case .homeFortress: return "Home Fortress"
        case .bigMatchTemperament: return "Big-Match Temperament"
        }
    }

    var blurb: String {
        switch self {
        case .drillMaster: return "Drills 10% more effective"
        case .extraSession: return "+1 training slot"
        case .youthMentor: return "Under-22s train 15% faster"
        case .veteranCare: return "30+ players decline more slowly"
        case .fitnessGuru: return "Hard training costs half the form"
        case .ironBody: return "Your players retire later"
        case .specialistCoach: return "Individual focus 20% stronger"
        case .netProgram: return "Bowling drills 10% more effective"
        case .negotiator: return "Players ask 10% lower wages"
        case .dealmaker: return "AI bids for your players 10% higher"
        case .starMagnet: return "Players accept 80% of their wage demand"
        case .auctionShark: return "See the top rival's limit in the auction"
        case .sponsorFriend: return "Commercial income +10%"
        case .crowdPuller: return "Gate money +10%"
        case .leanBuild: return "Facility upgrades 10% cheaper"
        case .globalNetwork: return "+1 scout"
        case .captainsCall: return "Your XI plays +1 above its ratings"
        case .powerplayPlan: return "Openers +3 batting"
        case .deathPlan: return "Your two death bowlers +3"
        case .spinDoctor: return "Spinners +3 on turners and slow pitches"
        case .settledSide: return "Your players' form never drops below -4"
        case .youthFaith: return "Academy kids arrive with +3 potential"
        case .homeFortress: return "+2 for everyone at home"
        case .bigMatchTemperament: return "+3 for everyone in the playoffs"
        }
    }
}

struct ManagerProfile: Codable, Hashable {
    var xp = 0
    var level = 1
    var points = 0
    var perks: [Perk] = []

    func has(_ p: Perk) -> Bool { perks.contains(p) }
    static func xpFor(level n: Int) -> Int { Int(100 * pow(Double(n), 1.5)) }
}

// MARK: - Gold and the store

/// Store packs. Real StoreKit needs an App Store/TestFlight build; in this build every pack is free
/// (test mode) and the 1,000,000 Gold tester pack can be bought any number of times.
enum StorePack: String, CaseIterable, Identifiable {
    case small, medium, large, tester

    var id: String { rawValue }
    var gold: Int { [400, 1_200, 6_000, 1_000_000][StorePack.allCases.firstIndex(of: self)!] }
    var priceLabel: String { self == .tester ? "Free · unlimited" : ["€1.99", "€4.99", "€19.99"][StorePack.allCases.firstIndex(of: self)!] }
    var title: String { self == .tester ? "Tester Pack" : "\(gold.formatted()) Gold" }
}

enum StoreConfig {
    /// Test mode: no real purchases, every pack is granted for free. Turn off before any public release.
    static let testerStore = true
}

enum GoldItem: String, CaseIterable, Identifiable {
    case finishBuild, trainingBoost, scoutReport, freshLegs

    var id: String { rawValue }
    var label: String {
        switch self {
        case .finishBuild: return "Finish the facility build now"
        case .trainingBoost: return "Training boost (+50% for 4 weeks)"
        case .scoutReport: return "Instant scout report on a player"
        case .freshLegs: return "Fresh legs (a player's form to +3)"
        }
    }
}

// MARK: - Engine

extension Career {
    func facility(_ k: FacilityKind) -> Int { facilities.level(k) }

    /// Cost of the next level, in lakhs.
    func upgradeCost(_ k: FacilityKind) -> Int {
        let next = facility(k) + 1
        let base = Double(tuning.facilityBaseCost * next * next)
        return Career.round5(base * (manager.has(.leanBuild) ? 0.9 : 1))
    }

    func upgradeWeeks(_ k: FacilityKind) -> Int { facility(k) + 1 }

    @discardableResult
    mutating func upgrade(_ k: FacilityKind) -> String? {
        if facilities.building != nil { return "Already building. One project at a time." }
        if facility(k) >= 10 { return "Already at the top level." }
        let cost = upgradeCost(k)
        if bank(userClubId) < cost { return "You need \(Money.format(cost)) in the bank." }
        post(userClubId, "\(k.label) upgrade", -cost)
        facilities.building = k.rawValue
        facilities.weeksLeft = upgradeWeeks(k)
        addNews(.info, "🏗️ Work starts on the \(k.label) (level \(facility(k) + 1)) — ready in \(facilities.weeksLeft) weeks.")
        return nil
    }

    /// One week of building work. Called after each of the user's matches (and in the off-season).
    mutating func facilityTick(weeks: Int = 1) {
        guard let b = facilities.building, let k = FacilityKind(rawValue: b) else { return }
        facilities.weeksLeft -= weeks
        if facilities.weeksLeft <= 0 { completeBuild(k) }
    }

    private mutating func completeBuild(_ k: FacilityKind) {
        facilities.levels[k.rawValue] = facility(k) + 1
        facilities.building = nil
        facilities.weeksLeft = 0
        addNews(.info, "✅ \(k.label) upgraded to level \(facility(k)).")
        gainXP(30, reason: nil)
    }

    var facilityMaintenance: Int {
        FacilityKind.allCases.reduce(0) { $0 + tuning.facilityUpkeep * facility($1) * facility($1) }
    }

    /// Gate money for one home match.
    func gate(for clubId: Int) -> Int {
        let level = clubId == userClubId ? facility(.stadium) : tuning.aiFacilityLevel
        return Career.round5(Double(tuning.gatePerLevel * level) * (clubId == userClubId && manager.has(.crowdPuller) ? 1.1 : 1))
    }

    func commercialIncome(for clubId: Int) -> Int {
        let level = clubId == userClubId ? facility(.commercial) : tuning.aiFacilityLevel
        return Career.round5(Double(tuning.commercialPerLevel * level) * (clubId == userClubId && manager.has(.sponsorFriend) ? 1.1 : 1))
    }

    /// Season accounts, posted at the start of the off-season: wages, upkeep, gate, commercial.
    mutating func settleSeasonAccounts() {
        for club in clubs {
            let homeGames = results.filter { r in
                fixtures.first { $0.resultId == r.id }?.home == club.id
            }.count
            post(club.id, "Wages", -payroll(club.id))
            if club.id == userClubId {
                // Tickets and merchandise were paid weekly.
                post(club.id, "Facility upkeep", -facilityMaintenance)
            } else {
                post(club.id, "Gate money (\(homeGames) home matches)", gate(for: club.id) * homeGames)
                post(club.id, "Sponsors & merchandise", commercialIncome(for: club.id))
            }
        }
        let b = bank(userClubId)
        if b < 0 {
            addNews(.info, "⚠️ The owner is unhappy: the club is \(Money.format(-b)) in debt. No transfer fees until the bank is back in the black.")
        } else {
            gainXP(50, reason: nil)
        }
    }

    // MARK: Manager

    mutating func gainXP(_ amount: Int, reason: String?) {
        manager.xp += amount
        while manager.level < 100 && manager.xp >= ManagerProfile.xpFor(level: manager.level) {
            manager.level += 1
            manager.points += 1
            gold += tuning.goldPerLevel * manager.level
            addNews(.info, "⭐ Manager level \(manager.level)! +1 trait point, +\(tuning.goldPerLevel * manager.level) gold.")
        }
    }

    func canLearn(_ p: Perk) -> String? {
        if manager.has(p) { return "Already learned." }
        if manager.points < p.cost { return "Needs \(p.cost) point\(p.cost == 1 ? "" : "s")." }
        let owned = manager.perks.filter { $0.tree == p.tree }.count
        if owned < p.requires { return "Learn \(p.requires) \(p.tree.label) perks first." }
        return nil
    }

    @discardableResult
    mutating func learn(_ p: Perk) -> String? {
        if let why = canLearn(p) { return why }
        manager.points -= p.cost
        manager.perks.append(p)
        if p == .extraSession || p == .globalNetwork { setTraining(training) }
        return nil
    }

    /// Per-player rating boosts for the user's XI from perks and the Analytics Room.
    func userBoost(for p: Player, position: Int, attackSlot: Int?, fixture: Fixture?) -> (bat: Int, bowl: Int) {
        var bat = difficulty.userBoost, bowl = difficulty.userBoost
        let analytics = (facility(.analytics) - 1) / 3
        bat += analytics; bowl += analytics
        if manager.has(.captainsCall) { bat += 1; bowl += 1 }
        if manager.has(.powerplayPlan) && position < 2 { bat += 3 }
        if manager.has(.deathPlan), let s = attackSlot, s < 2 { bowl += 3 }
        if let f = fixture {
            if manager.has(.spinDoctor) && p.bowlType == .spin && (f.pitch == .dustyTurner || f.pitch == .caribbeanSlow) { bowl += 3 }
            if manager.has(.homeFortress) && f.home == userClubId { bat += 2; bowl += 2 }
            if manager.has(.bigMatchTemperament) && f.stage != .league { bat += 3; bowl += 3 }
        }
        return (bat, bowl)
    }

    // MARK: Gold

    func goldCost(_ item: GoldItem) -> Int {
        switch item {
        case .finishBuild: return max(1, facilities.weeksLeft) * tuning.goldPerBuildWeek
        case .trainingBoost: return 80
        case .scoutReport: return 50
        case .freshLegs: return 30
        }
    }

    /// Spends gold. `playerId` is needed for scout reports and fresh legs.
    @discardableResult
    mutating func spendGold(_ item: GoldItem, playerId: String? = nil) -> String? {
        let cost = goldCost(item)
        if gold < cost { return "You need \(cost) gold." }
        switch item {
        case .finishBuild:
            guard let b = facilities.building, let k = FacilityKind(rawValue: b) else { return "Nothing is being built." }
            gold -= cost
            completeBuild(k)
        case .trainingBoost:
            gold -= cost
            trainingBoostWeeks += 4
        case .scoutReport:
            guard let id = playerId, players[id] != nil else { return "Pick a player." }
            gold -= cost
            scouting.knowledge[id] = 100
        case .freshLegs:
            guard let id = playerId, players[id]?.clubId == userClubId else { return "Pick one of your players." }
            gold -= cost
            let form = max(players[id]?.form ?? 0, 3)
            players[id]?.form = form
        }
        return nil
    }

    /// Test-mode store: grants the pack's gold (no charge).
    mutating func buy(_ pack: StorePack) {
        guard StoreConfig.testerStore else { return }
        gold += pack.gold
    }
}
