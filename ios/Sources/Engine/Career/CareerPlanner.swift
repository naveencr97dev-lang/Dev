import Foundation

// Career › Squad › Squad planner: a depth chart for each job in a T20 XI (modelled on manager games'
// squad planners, rebuilt for cricket). Each job has its starters and the players behind them, so the
// manager can see where the squad is thin or ageing and who to sign. Planning only: the matchday XI
// changes only when the manager taps "Use as my XI".

enum PlanSlot: String, Codable, CaseIterable, Identifiable {
    case openers, topOrder, finishers, keeper, allRounder, spinner, seamers
    var id: String { rawValue }

    var label: String {
        switch self {
        case .openers: return "Openers"
        case .topOrder: return "Top order"
        case .finishers: return "Finishers"
        case .keeper: return "Wicket-keeper"
        case .allRounder: return "All-rounder"
        case .spinner: return "Spinner"
        case .seamers: return "Seamers"
        }
    }

    /// Players in the XI for this job (7 jobs, 11 places).
    var starters: Int {
        switch self {
        case .openers, .topOrder, .finishers, .seamers: return 2
        case .keeper, .allRounder, .spinner: return 1
        }
    }

    /// Can this player do the job?
    func fits(_ p: CareerPlayer) -> Bool {
        switch self {
        case .openers: return p.bat >= 50 && [.open, .top].contains(p.slot)
        case .topOrder: return p.bat >= 50 && [.open, .top, .middle].contains(p.slot)
        case .finishers: return p.bat >= 50 && [.middle, .finish].contains(p.slot)
        case .keeper: return p.role == .WK
        case .allRounder: return p.role == .AR
        case .spinner: return p.bowlType == .spin && p.bowl >= 50
        case .seamers: return p.bowlType == .pace && p.bowl >= 50
        }
    }

    /// How good the player is at this job (ranking for auto-fill and targets).
    func score(_ p: CareerPlayer) -> Int {
        switch self {
        case .openers: return p.bat + (p.slot == .open ? 4 : 0)
        case .topOrder: return p.bat + (p.slot == .top ? 4 : 0)
        case .finishers: return p.bat + (p.slot == .finish ? 4 : 0) + (p.traits.contains(.finisher) ? 3 : 0)
        case .keeper: return (p.bat + p.attr.keeping) / 2
        case .allRounder: return p.rating
        case .spinner, .seamers: return p.bowl
        }
    }
}

/// Schema 14: the manager's depth chart, player ids per job, first choice first.
struct SquadPlan: Codable, Hashable {
    var slots: [String: [String]] = [:]
    /// Depth kept per job (starters plus backups).
    static let depth = 4
}

struct PlanSummary {
    var rating = 0
    var age = 0.0
    /// A starter aged 33+ with no backup aged 28 or under.
    var successionWarning: String? = nil
}

extension Career {
    /// The planned players for a job, still in the squad, in order.
    func planned(_ slot: PlanSlot) -> [CareerPlayer] {
        (plan?.slots[slot.rawValue] ?? []).compactMap { id in players[id].flatMap { $0.clubId == userClubId ? $0 : nil } }
    }

    /// Squad players who can do the job and aren't planned there yet, best first.
    func planCandidates(_ slot: PlanSlot) -> [CareerPlayer] {
        let taken = Set(planned(slot).map(\.id))
        return squad(userClubId).filter { slot.fits($0) && !taken.contains($0.id) }
            .sorted { slot.score($0) != slot.score($1) ? slot.score($0) > slot.score($1) : $0.id < $1.id }
    }

    /// Fills every job: starters go to the best player not already starting elsewhere (within the
    /// overseas limit), then backups. A job nobody fits takes the best player left, so the plan always
    /// names 11 starters (tests found 10 and 6 overseas before this rule).
    mutating func autoPlan() {
        var p = SquadPlan()
        var starting = Set<String>()
        var overseas = 0
        let squadNow = squad(userClubId)
        func canStart(_ x: CareerPlayer) -> Bool {
            !starting.contains(x.id) && (!x.overseas || overseas < tuning.maxOverseasXI)
        }
        func start(_ x: CareerPlayer) {
            starting.insert(x.id)
            if x.overseas { overseas += 1 }
        }
        // Scarce jobs first (keeper, spinner, all-rounder), so the openers don't use them up.
        let order: [PlanSlot] = [.keeper, .spinner, .allRounder, .seamers, .openers, .topOrder, .finishers]
        for slot in order {
            let byScore = { (a: CareerPlayer, b: CareerPlayer) in
                slot.score(a) != slot.score(b) ? slot.score(a) > slot.score(b) : a.id < b.id
            }
            let ranked = squadNow.filter(slot.fits).sorted(by: byScore)
            var ids: [String] = []
            for x in ranked where ids.count < slot.starters && canStart(x) { ids.append(x.id); start(x) }
            // Nobody left who fits: the best remaining player does the job.
            let value = { (x: CareerPlayer) in max(x.bat, x.bowl) + min(x.bat, x.bowl) / 2 }
            // With no wicket-keeper in the squad, the best gloveman keeps (panel: the planner failed 66 times).
            let fallback = { (x: CareerPlayer) in slot == .keeper ? x.attr.keeping : value(x) }
            for x in squadNow.sorted(by: { fallback($0) != fallback($1) ? fallback($0) > fallback($1) : $0.id < $1.id })
                where ids.count < slot.starters && canStart(x) {
                ids.append(x.id); start(x)
            }
            ids += ranked.map(\.id).filter { !ids.contains($0) }.prefix(max(0, SquadPlan.depth - ids.count))
            p.slots[slot.rawValue] = ids
        }
        plan = p
    }

    mutating func planAdd(_ slot: PlanSlot, _ id: String) {
        var p = plan ?? SquadPlan()
        var ids = (p.slots[slot.rawValue] ?? []).filter { players[$0]?.clubId == userClubId }
        guard !ids.contains(id), players[id]?.clubId == userClubId else { return }
        ids.append(id)
        p.slots[slot.rawValue] = ids
        plan = p
    }

    mutating func planRemove(_ slot: PlanSlot, _ id: String) {
        plan?.slots[slot.rawValue]?.removeAll { $0 == id }
    }

    /// Moves a player up (-1) or down (+1) the depth chart.
    mutating func planMove(_ slot: PlanSlot, _ id: String, by step: Int) {
        guard var ids = plan?.slots[slot.rawValue], let i = ids.firstIndex(of: id) else { return }
        let j = i + step
        guard ids.indices.contains(j) else { return }
        ids.swapAt(i, j)
        plan?.slots[slot.rawValue] = ids
    }

    mutating func planClear(_ slot: PlanSlot) { plan?.slots[slot.rawValue] = [] }

    func planSummary(_ slot: PlanSlot) -> PlanSummary {
        var s = PlanSummary()
        let list = planned(slot)
        let starters = Array(list.prefix(slot.starters))
        guard !starters.isEmpty else { return s }
        s.rating = starters.map { slot.score($0) }.reduce(0, +) / starters.count
        s.age = Double(starters.map { $0.age(in: year) }.reduce(0, +)) / Double(starters.count)
        let backups = list.dropFirst(slot.starters)
        if let old = starters.first(where: { $0.age(in: year) >= 33 }), !backups.contains(where: { $0.age(in: year) <= 28 }) {
            s.successionWarning = "\(old.name) is \(old.age(in: year)) with no young backup. Plan a successor."
        }
        return s
    }

    /// The scout's pick for a job: the best player at another club or free who would start there and
    /// whom the club can afford.
    func planTarget(_ slot: PlanSlot) -> CareerPlayer? {
        let starters = planned(slot).prefix(slot.starters)
        let bar = starters.count < slot.starters ? 0 : (starters.map { slot.score($0) }.min() ?? 0)
        return players.values
            .filter { $0.clubId != userClubId && !$0.retired && $0.academyOf == nil && slot.fits($0) && slot.score($0) > bar + 1 }
            .filter { scoutAdvice($0, fee: $0.clubId == nil ? 0 : askingPrice($0)).good }
            .max { slot.score($0) != slot.score($1) ? slot.score($0) < slot.score($1) : $0.id > $1.id }
    }

    /// The XI the plan describes: each job's starters (a player starting twice counts once, the next
    /// in line steps up), in batting order. nil with the reasons if it isn't a legal XI.
    func xiFromPlan() -> (ids: [String]?, issues: [String]) {
        var ids: [String] = []
        for slot in PlanSlot.allCases {
            var n = 0
            for p in planned(slot) where n < slot.starters {
                if !ids.contains(p.id) { ids.append(p.id) }
                n += 1
            }
        }
        let xi = ids.compactMap { player($0) }
        var issues = TeamSelector.blockingIssues(xi, rules: rules)
        if xi.count != 11 { issues.insert("The plan names \(xi.count) different starters, not 11.", at: 0) }
        guard issues.isEmpty else { return (nil, issues) }
        return (TeamSelector.battingOrder(xi).map(\.id), [])
    }

    /// Makes the planned starters the XI (turns the assistant's selection off, like any manual pick).
    @discardableResult
    mutating func applyPlan() -> [String] {
        let (ids, issues) = xiFromPlan()
        guard let ids else { return issues }
        setXI(clubId: userClubId, ids: ids)
        settings.assistantPicksXI = false
        return []
    }
}
