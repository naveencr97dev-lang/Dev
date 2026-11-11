import Foundation

// Career › Scouting. Owner's request: scouts that help build the squad, not random reports.
// Each scout has a job: upgrade one of your players, find players for your home pitch, find
// young talent or find bargains. After each of your matches he watches the best candidates for
// that job; the ones he has seen make his shortlist, ranked, priced and marked affordable or not.

enum ScoutMission: String, Codable, CaseIterable, Identifiable {
    case upgrade, bowlingPlan, homePitch, talent, bargains
    var id: String { rawValue }
    var label: String {
        switch self {
        case .upgrade: return "Upgrade a player"
        case .bowlingPlan: return "Fill the bowling plan"
        case .homePitch: return "Home-pitch specialists"
        case .talent: return "Young talent"
        case .bargains: return "Bargains"
        }
    }
    var short: String {
        switch self {
        case .upgrade: return "Upgrade"
        case .bowlingPlan: return "Bowling plan"
        case .homePitch: return "Home pitch"
        case .talent: return "Talent"
        case .bargains: return "Bargains"
        }
    }
    var blurb: String {
        switch self {
        case .upgrade: return "Better players in the same role as one of yours, best value first"
        case .bowlingPlan: return "Bowlers whose traits suit the slots in your plan that only read ok"
        case .homePitch: return "Players who suit your home pitch"
        case .talent: return "23 and under with the most potential"
        case .bargains: return "Free agents and cheap squad players worth a place"
        }
    }
}

/// One player on a scout's shortlist.
struct ScoutPick: Identifiable {
    let player: CareerPlayer
    let fee: Int
    let wage: Int
    let affordable: Bool
    /// Upgrade job: rating points over the target. Otherwise nil.
    let gain: Int?
    let reason: String
    var id: String { player.id }
}

extension Career {
    func mission(of s: Scout) -> ScoutMission {
        if s.mission == .upgrade, let t = s.targetId, players[t]?.clubId == userClubId { return .upgrade }
        if let m = s.mission, m != .upgrade { return m }
        return .talent
    }

    /// The user's player an upgrade scout is working for (nil if he has left).
    func scoutTarget(_ s: Scout) -> CareerPlayer? {
        guard mission(of: s) == .upgrade, let t = s.targetId else { return nil }
        return players[t]
    }

    /// Fee and wage for the user, and whether the bank and the salary cap allow it. For an upgrade
    /// the target's wage counts as room (he'd be sold or released).
    func scoutDeal(_ p: CareerPlayer, freeing: CareerPlayer? = nil) -> (fee: Int, wage: Int, affordable: Bool) {
        let fee = p.clubId == nil ? 0 : askingPrice(p)
        let wage = userWageDemand(p)
        let room = capRoom(userClubId) + (freeing?.contract?.wage ?? 0)
        return (fee, wage, fee <= max(0, bank(userClubId)) && wage <= room)
    }

    /// Everyone who fits the scout's job and region, best first (before what he has seen).
    func scoutPool(_ s: Scout) -> [CareerPlayer] {
        let job = mission(of: s)
        let target = scoutTarget(s)
        let pool = players.values.filter { p in
            !p.retired && p.clubId != userClubId && !academy.contains(p.id)
                && (s.region == "ANY" || p.country == s.region)
                && (job == .upgrade || s.role == nil || p.role == s.role)
        }
        let weak = job == .bowlingPlan ? weakPlanSlots() : []
        let planBowl = userBowlingPlan().map(\.bowl).min() ?? 0
        func score(_ p: CareerPlayer) -> Double {
            let deal = scoutDeal(p, freeing: target)
            let penalty = deal.affordable ? 0.0 : 25
            let fit = Double(homeFit(p, clubId: userClubId))
            switch job {
            case .upgrade:
                guard let t = target else { return -999 }
                return Double(p.rating - t.rating) + fit * 0.4 - penalty
            case .homePitch: return Double(p.rating) + fit * 0.8 - penalty
            case .bowlingPlan:
                let best = weak.map { Career.slotFit(p, slot: $0) }.max() ?? 0
                return Double(p.bowl) + fit * 0.5 + Double(best) - penalty
            case .talent: return Double(p.potential) + Double(p.rating) * 0.1 - penalty * 0.4
            case .bargains:
                // Rating for the money: free agents first, then cheap squad players.
                let crores = Double(deal.fee) / 100
                return Double(p.rating) - 6 * log2(1 + crores) - penalty
            }
        }
        let eligible: [CareerPlayer]
        switch job {
        case .bowlingPlan:
            eligible = pool.filter { p in
                p.bowl >= max(60, planBowl - 3) && weak.contains { Career.slotFit(p, slot: $0) > MatchEngine.slotSuits }
            }
        case .upgrade:
            guard let t = target else { return [] }
            eligible = pool.filter { p in
                p.role == t.role && p.rating >= t.rating + 2
                    && (t.role == .BAT || t.role == .WK || p.bowlType == t.bowlType)
            }
        case .homePitch:
            eligible = pool.filter { homeFit($0, clubId: userClubId) >= PitchFit.suits && $0.rating >= 70 }
        case .talent:
            eligible = pool.filter { $0.age(in: year) <= (s.youthOnly ? 21 : 23) && $0.potential >= 75 }
        case .bargains:
            eligible = pool.filter { $0.rating >= 72 && scoutDeal($0).affordable }
        }
        let scored = eligible.map { ($0, score($0)) }
        return scored.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.id < $1.0.id }.map(\.0)
    }

    /// The scout's shortlist: the best candidates he has seen.
    func scoutPicks(_ s: Scout, limit: Int = 5) -> [ScoutPick] {
        let target = scoutTarget(s)
        return scoutPool(s).filter { knowledge(of: $0.id) >= 25 }.prefix(limit).map { p in
            let deal = scoutDeal(p, freeing: target)
            return ScoutPick(player: p, fee: deal.fee, wage: deal.wage, affordable: deal.affordable,
                             gain: target.map { p.rating - $0.rating }, reason: scoutReason(p, job: mission(of: s), target: target))
        }
    }

    func scoutReason(_ p: CareerPlayer, job: ScoutMission, target: CareerPlayer?) -> String {
        var bits: [String] = []
        if let t = target { bits.append("+\(p.rating - t.rating) on \(t.name)") }
        if job == .bowlingPlan, let slot = weakPlanSlots().first(where: { Career.slotFit(p, slot: $0) > MatchEngine.slotSuits }) {
            bits.append(slot < 2 ? "suits new ball + death" : "suits middle overs")
        }
        if suitsUserPitch(p) == true { bits.append("suits your pitch") }
        if job == .talent || p.age(in: year) <= 23 { bits.append("potential \(potentialLabel(p))") }
        if p.clubId == nil { bits.append("free agent") }
        if let f = formScore(p.id), f >= 8 { bits.append(String(format: "form %.1f", f)) }
        return bits.isEmpty ? "\(p.roleDescription), age \(p.age(in: year))" : bits.joined(separator: " · ")
    }

    /// One visit by one scout: he watches the top unseen candidates for his job. Returns the best
    /// new name for his report (nil if nothing new).
    @discardableResult
    mutating func scoutVisit(_ index: Int) -> CareerPlayer? {
        guard scouting.scouts.indices.contains(index) else { return nil }
        let s = scouting.scouts[index]
        let fresh = scoutPool(s).filter { (scouting.knowledge[$0.id] ?? 0) < 100 }.prefix(12)
        guard !fresh.isEmpty else { return nil }
        let before = Set(scoutPicks(s).map(\.id))
        let looks = 1 + s.stars / 2
        // Mostly the best unseen candidates, sometimes one further down the list.
        var watched: [CareerPlayer] = []
        for p in fresh where watched.count < looks && (scouting.knowledge[p.id] ?? 0) < 25 { watched.append(p) }
        if watched.count < looks, let extra = fresh.randomElement(using: &rng), !watched.contains(extra) { watched.append(extra) }
        for p in watched {
            let k = scouting.knowledge[p.id] ?? 0
            scouting.knowledge[p.id] = min(100, k + 15 + s.stars * 10 + 2 * (facility(.scoutingNetwork) - 1))
        }
        return scoutPicks(s).first { !before.contains($0.id) }?.player
    }

    /// After every user match (with training): each scout makes a visit. A report and a news line
    /// only when someone new makes his shortlist (top five).
    mutating func scoutTick() {
        for i in scouting.scouts.indices {
            let s = scouting.scouts[i]
            guard let best = scoutVisit(i) else { continue }
            let job = mission(of: s)
            let deal = scoutDeal(best, freeing: scoutTarget(s))
            let note = "\(job.short): \(scoutReason(best, job: job, target: scoutTarget(s))) · \(deal.fee > 0 ? Money.format(deal.fee) : "free")\(deal.affordable ? "" : " (can't afford yet)")"
            scouting.reports.insert(ScoutReport(id: scouting.nextId, playerId: best.id, scoutName: s.name,
                                                year: year, day: currentDay, note: note), at: 0)
            scouting.nextId += 1
            addNews(.squad, "📋 \(s.name): \(best.name) (\(best.role.short), \(best.rating)). \(note).")
        }
        if scouting.reports.count > 30 { scouting.reports.removeLast(scouting.reports.count - 30) }
    }

    mutating func setScoutMission(_ id: Int, mission: ScoutMission, targetId: String? = nil) {
        guard let i = scouting.scouts.firstIndex(where: { $0.id == id }) else { return }
        scouting.scouts[i].mission = mission
        scouting.scouts[i].targetId = mission == .upgrade ? targetId : nil
    }

    /// Player card › Find an upgrade: the scout already on it, else a free one (not on another
    /// upgrade), else the first. He takes a first look at once. Returns why not, or nil.
    @discardableResult
    mutating func scoutUpgrade(for playerId: String) -> String? {
        guard players[playerId]?.clubId == userClubId else { return "Only for your own players." }
        return putScout(on: .upgrade, targetId: playerId)
    }

    /// Bowling plan › Scout bowlers: a scout on the "Fill the bowling plan" job.
    @discardableResult
    mutating func scoutBowlingPlan() -> String? { putScout(on: .bowlingPlan) }

    /// The scout already on this job, else one on the plain talent job, else one not on an upgrade,
    /// else the first. A new job starts with two visits, so the shortlist isn't empty.
    private mutating func putScout(on job: ScoutMission, targetId: String? = nil) -> String? {
        guard !scouting.scouts.isEmpty else { return "Hire a scout first (Squad › Scouts)." }
        if scouting.scouts.contains(where: { mission(of: $0) == job && $0.targetId == targetId }) { return nil }
        let i = scouting.scouts.firstIndex { $0.mission == nil }
            ?? scouting.scouts.firstIndex { mission(of: $0) != .upgrade && mission(of: $0) != .bowlingPlan }
            ?? 0
        setScoutMission(scouting.scouts[i].id, mission: job, targetId: targetId)
        for _ in 0..<2 { scoutVisit(i) }
        return nil
    }

    /// The scout on a job (and target), if any.
    func scout(on job: ScoutMission, targetId: String? = nil) -> Scout? {
        scouting.scouts.first { mission(of: $0) == job && (targetId == nil || $0.targetId == targetId) }
    }

    /// The scout working on an upgrade for this player, if any.
    func upgradeScout(for playerId: String) -> Scout? {
        scouting.scouts.first { mission(of: $0) == .upgrade && $0.targetId == playerId }
    }

    // MARK: Bowling plan

    static func slotFit(_ p: CareerPlayer, slot: Int) -> Int {
        MatchEngine.slotFit(p.matchPlayer(formMatters: false), slot: slot)
    }

    /// The user's five bowlers in plan order: the saved plan, else the captain's pick from the XI.
    func userBowlingPlan() -> [CareerPlayer] {
        let club = userClub
        if club.bowlingOrder.count == 5 { return club.bowlingOrder.compactMap { players[$0] } }
        let xi = club.xi.compactMap { player($0) }
        return MatchEngine.autoAttack(xi, pitch: nil).prefix(5).compactMap { players[$0.id] }
    }

    /// Plan slots (0-4) whose bowler doesn't suit the job.
    func weakPlanSlots() -> [Int] {
        userBowlingPlan().enumerated().filter { Career.slotFit($0.element, slot: $0.offset) <= MatchEngine.slotSuits }.map(\.offset)
    }

    // MARK: Market filters

    /// Traits worth filtering the market by (bowling jobs first).
    static let marketTraits: [Trait] = [.newBallSwing, .deathSpecialist, .middleOversBoss, .slowerBallMaster,
                                        .wicketTaker, .economical, .turnerTerror, .powerHitter, .finisher, .anchor]
}
