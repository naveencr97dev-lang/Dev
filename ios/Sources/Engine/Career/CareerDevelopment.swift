import Foundation

// MARK: - Types

enum Drill: String, Codable, CaseIterable, Identifiable {
    case powerHitting, rotation, paceBatting, spinBatting, deathBowling, newBallSwing, spinVariations,
         fielding, fitness, matchSimulation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .powerHitting: return "Power hitting"
        case .rotation: return "Rotation & running"
        case .paceBatting: return "Batting vs pace"
        case .spinBatting: return "Batting vs spin"
        case .deathBowling: return "Death bowling"
        case .newBallSwing: return "New-ball swing"
        case .spinVariations: return "Spin variations"
        case .fielding: return "Fielding & keeping"
        case .fitness: return "Fitness"
        case .matchSimulation: return "Match simulation"
        }
    }

    var icon: String {
        switch self {
        case .powerHitting: return "💥"
        case .rotation: return "🏃"
        case .paceBatting: return "⚡️"
        case .spinBatting: return "🌀"
        case .deathBowling: return "☠️"
        case .newBallSwing: return "🌪️"
        case .spinVariations: return "🎩"
        case .fielding: return "🧤"
        case .fitness: return "💪"
        case .matchSimulation: return "🏏"
        }
    }

    /// Attributes the drill trains.
    var keys: [WritableKeyPath<Attributes, Int>] {
        switch self {
        case .powerHitting: return [\.power]
        case .rotation: return [\.technique, \.temperament]
        case .paceBatting: return [\.vsPace]
        case .spinBatting: return [\.vsSpin]
        case .deathBowling: return [\.death]
        case .newBallSwing: return [\.newBall]
        case .spinVariations: return [\.variation, \.potency]
        case .fielding: return [\.fielding, \.keeping]
        case .fitness: return []
        case .matchSimulation: return [\.temperament, \.accuracy]
        }
    }

    var isBowling: Bool { [.deathBowling, .newBallSwing, .spinVariations].contains(self) }
}

enum Intensity: String, Codable, CaseIterable {
    case light, normal, hard

    var label: String { rawValue.capitalized }
    var multiplier: Double { self == .light ? 0.6 : (self == .normal ? 1 : 1.4) }
}

struct TrainingPlan: Codable, Hashable {
    var drills: [Drill] = [.matchSimulation, .powerHitting, .deathBowling]
    var intensity: Intensity = .normal
    /// Individual focus: player id → attribute name (see `Attributes.trainable`).
    var focus: [String: String] = [:]
}

struct Scout: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    /// 1-5: how much each report reveals and how many players it covers.
    let stars: Int
    let wage: Int
    /// Nation code to watch ("ANY" = everywhere), and an optional role and age focus.
    var region: String = "ANY"
    var role: Role? = nil
    var youthOnly = false
    /// His job (owner's request: scouts that help build the squad). nil = young talent (old saves).
    var mission: ScoutMission? = nil
    /// Upgrade job: the user's player to find an upgrade for.
    var targetId: String? = nil
}

struct ScoutReport: Codable, Hashable, Identifiable {
    let id: Int
    let playerId: String
    let scoutName: String
    let year: Int
    let day: Int
    /// What he found, in a line (mission saves; nil in old saves).
    var note: String? = nil
}

struct ScoutingState: Codable, Hashable {
    var scouts: [Scout] = []
    var candidates: [Scout] = []
    /// What the user knows about each player, 0-100 (own squad always counts as 100).
    var knowledge: [String: Int] = [:]
    var reports: [ScoutReport] = []
    var nextId = 1
}

extension Attributes {
    /// Attributes a player can be given as an individual training focus.
    static let trainable: [(name: String, label: String, key: WritableKeyPath<Attributes, Int>)] = [
        ("technique", "Technique", \.technique), ("power", "Power", \.power), ("vsPace", "vs Pace", \.vsPace),
        ("vsSpin", "vs Spin", \.vsSpin), ("temperament", "Temperament", \.temperament),
        ("accuracy", "Accuracy", \.accuracy), ("potency", "Pace / turn", \.potency), ("variation", "Variation", \.variation),
        ("death", "Death bowling", \.death), ("newBall", "New ball", \.newBall), ("fielding", "Fielding", \.fielding),
        ("keeping", "Keeping", \.keeping),
    ]

    static func key(named name: String) -> WritableKeyPath<Attributes, Int>? {
        trainable.first { $0.name == name }?.key
    }
}

// MARK: - Training

extension Career {
    /// Default plan for AI clubs.
    static let aiPlan = TrainingPlan()

    var trainingSlots: Int { tuning.trainingSlots + facilityTrainingSlots + (manager.has(.extraSession) ? 1 : 0) }

    /// +1 slot at Training Ground levels 3, 6 and 9.
    var facilityTrainingSlots: Int { facility(.trainingGround) / 3 }

    mutating func setTraining(_ plan: TrainingPlan) {
        var p = plan
        p.drills = Array(p.drills.prefix(trainingSlots))
        training = p
    }

    /// One week of training for every club. Called after each of the user's matches.
    mutating func trainingTick() {
        for club in clubs {
            let plan = club.id == userClubId ? training : Career.aiPlan
            for id in club.squad.sorted() { train(id, plan: plan, user: club.id == userClubId) }
        }
        for id in academy.sorted() { train(id, plan: training, user: true, youthBoost: tuning.academyBoost) }
        if trainingBoostWeeks > 0 { trainingBoostWeeks -= 1 }
    }

    private mutating func train(_ id: String, plan: TrainingPlan, user: Bool, youthBoost: Double = 1) {
        guard var p = players[id] else { return }
        let age = p.age(in: year)
        let ageFactor = age <= 21 ? 1.6 : (age <= 25 ? 1.2 : (age <= 29 ? 0.8 : 0.4))
        var base = tuning.drillChance * plan.intensity.multiplier * ageFactor * youthBoost
        var bowlingBonus = 1.0, focusBonus = 1.0, hardPenalty = 0.12
        if user {
            base *= 1 + 0.06 * Double(facility(.trainingGround) - 1)
            if manager.has(.drillMaster) { base *= 1.1 }
            if manager.has(.youthMentor) && age < 22 { base *= 1.15 }
            if trainingBoostWeeks > 0 { base *= 1.5 }
            if manager.has(.netProgram) { bowlingBonus = 1.1 }
            if manager.has(.specialistCoach) { focusBonus = 1.2 }
            hardPenalty *= 1 - 0.06 * Double(facility(.medical) - 1)
            if manager.has(.fitnessGuru) { hardPenalty *= 0.5 }
        } else {
            base *= 1 + 0.06 * Double(tuning.aiFacilityLevel - 1)
        }
        let bowler = p.bowl >= 40
        for d in plan.drills where !d.isBowling || bowler {
            let chance = base * (d.isBowling ? bowlingBonus : 1)
            for k in d.keys where k != \Attributes.keeping || p.role == .WK {
                if rng.unit() < chance { bump(&p, k) }
            }
        }
        if let name = plan.focus[id], let k = Attributes.key(named: name),
           rng.unit() < base * tuning.focusMultiplier * focusBonus {
            bump(&p, k)
        }
        // Intensity: hard work tires players, light sessions freshen them up.
        if plan.drills.contains(.fitness) || plan.intensity == .light {
            if rng.unit() < 0.15 { p.form = min(tuning.formCap, p.form + 1) }
        } else if plan.intensity == .hard, rng.unit() < hardPenalty {
            p.form = max(-tuning.formCap, p.form - 1)
        }
        players[id] = p
    }

    /// +1 to an attribute, unless it pushes the player's skill past his potential.
    private func bump(_ p: inout CareerPlayer, _ k: WritableKeyPath<Attributes, Int>) {
        let before = p.attr
        p.attr[keyPath: k] = Attributes.clamp(p.attr[keyPath: k] + 1)
        if max(p.bat, p.bowl) > p.potential || p.attr[keyPath: k] > p.potential + 8 { p.attr = before }
    }

    // MARK: - Scouting

    func knowledge(of id: String) -> Int {
        if let p = players[id], p.clubId == userClubId || academy.contains(id) { return 100 }
        return scouting.knowledge[id] ?? 0
    }

    /// What the user can see of a player's potential.
    func potentialRange(_ p: CareerPlayer) -> ClosedRange<Int> {
        let k = knowledge(of: p.id)
        if k >= 100 { return p.potential...p.potential }
        let width = Int(Double(tuning.unknownPotentialWidth) * (1 - Double(k) / 100))
        // Off-centre by a fixed amount per player, so the true value isn't simply the middle.
        let shift = Career.stableHash(p.id) % (width + 1) - width / 2
        let lo = max(max(p.bat, p.bowl), p.potential - width / 2 + shift / 2)
        return lo...max(lo, min(99, lo + width))
    }

    static func stableHash(_ s: String) -> Int {
        var h: UInt32 = 5381
        for b in s.utf8 { h = (h &* 33) ^ UInt32(b) }
        return Int(h % 10_000)
    }

    func potentialLabel(_ p: CareerPlayer) -> String {
        let r = potentialRange(p)
        return r.lowerBound == r.upperBound ? "\(r.lowerBound)" : "\(r.lowerBound)–\(r.upperBound)"
    }

    var scoutCap: Int { tuning.scoutCap + facilityScoutSlots + (manager.has(.globalNetwork) ? 1 : 0) }

    /// +1 scout at Scouting Network levels 4, 7 and 10.
    var facilityScoutSlots: Int { (facility(.scoutingNetwork) - 1) / 3 }

    /// New scouts available to hire (refreshed each off-season).
    mutating func refreshScoutCandidates() {
        let first = ["Ravi", "Steve", "Imran", "Tom", "Ajay", "Grant", "Kumar", "Darren", "Faisal", "Neil", "Suresh", "Mark"]
        let last = ["Menon", "Hart", "Qadir", "Rhodes", "Bhatia", "Elliott", "Dias", "Lehmann", "Iqbal", "Fox", "Kamat", "Boucher"]
        scouting.candidates = (0..<3).map { _ in
            let stars = 1 + rng.weighted([30, 30, 22, 12, 6])
            let name = "\(first.randomElement(using: &rng)!) \(last.randomElement(using: &rng)!)"
            defer { scouting.nextId += 1 }
            return Scout(id: scouting.nextId, name: name, stars: stars, wage: tuning.scoutWage * stars)
        }
    }

    /// Hires a candidate: the first season's wage comes out of the bank now.
    @discardableResult
    mutating func hireScout(_ id: Int) -> String? {
        guard let s = scouting.candidates.first(where: { $0.id == id }) else { return "Not available." }
        if scouting.scouts.count >= scoutCap { return "You can only employ \(scoutCap) scouts. Upgrade the Scouting Network." }
        if bank(userClubId) < s.wage { return "Not enough in the bank." }
        post(userClubId, "Hired scout \(s.name)", -s.wage)
        scouting.scouts.append(s)
        scouting.candidates.removeAll { $0.id == id }
        return nil
    }

    mutating func fireScout(_ id: Int) { scouting.scouts.removeAll { $0.id == id } }

    mutating func assignScout(_ id: Int, region: String, role: Role?, youthOnly: Bool) {
        guard let i = scouting.scouts.firstIndex(where: { $0.id == id }) else { return }
        scouting.scouts[i].region = region
        scouting.scouts[i].role = role
        scouting.scouts[i].youthOnly = youthOnly
    }

    /// Nations a scout can be sent to.
    var scoutRegions: [String] {
        ["ANY"] + Set(players.values.map(\.country)).sorted()
    }

    /// Season's scout wages, charged at the start of each off-season.
    mutating func payScouts() {
        let total = scouting.scouts.reduce(0) { $0 + $1.wage }
        if total > 0 { post(userClubId, "Scout wages", -total) }
    }

    // MARK: - Youth academy

    var academyPlayers: [CareerPlayer] { academy.compactMap { players[$0] } }

    /// Yearly intake into the user's academy (AI academies feed the general youth pool).
    mutating func academyIntake() -> [String] {
        let room = max(0, tuning.academyMax - academy.count)
        let n = min(room, Int.random(in: 2...4, using: &rng))
        guard n > 0 else { return [] }
        var t = tuning
        t.youthGemChance = tuning.youthGemChance + Double(academyLevel - 1) * 0.04
        let taken = Set(players.values.map(\.name))
        var kids = PlayerGen.youth(count: n, year: year, startId: nextPlayerId, taken: taken, tuning: t, rng: &rng)
        nextPlayerId += kids.count
        let home = Career.clubNations[userClubId % Career.clubNations.count]
        for i in kids.indices {
            kids[i] = CareerPlayer(id: kids[i].id, name: kids[i].name, country: home, role: kids[i].role,
                                   bowlType: kids[i].bowlType, slot: kids[i].slot, traits: kids[i].traits,
                                   born: year - Int.random(in: 16...18, using: &rng), attr: kids[i].attr,
                                   potential: kids[i].potential, legend: false, generated: true, line: "Academy graduate",
                                   clubId: nil)
            kids[i].academyOf = userClubId
            if manager.has(.youthFaith) { kids[i].potential = min(99, kids[i].potential + 3) }
            players[kids[i].id] = kids[i]
            academy.append(kids[i].id)
        }
        return kids.map(\.name)
    }

    /// Academy players are local talent.
    static let clubNations = ["IND"]

    var academyLevel: Int { facility(.youthAcademy) }

    /// Moves an academy player into the squad on a minimum contract.
    @discardableResult
    mutating func promote(_ id: String) -> String? {
        guard academy.contains(id), players[id] != nil else { return "Not in the academy." }
        if squad(userClubId).count >= tuning.maxSquad { return "Squad full (\(tuning.maxSquad))." }
        if capRoom(userClubId) < tuning.minWage { return "No room under the salary cap." }
        academy.removeAll { $0 == id }
        players[id]?.academyOf = nil
        sign(id, to: userClubIndex, wage: tuning.minWage)
        addNews(.squad, "🎓 \(players[id]?.name ?? "") promoted from the academy.")
        return nil
    }

    mutating func releaseFromAcademy(_ id: String) {
        guard academy.contains(id) else { return }
        academy.removeAll { $0 == id }
        players[id]?.academyOf = nil
    }
}
