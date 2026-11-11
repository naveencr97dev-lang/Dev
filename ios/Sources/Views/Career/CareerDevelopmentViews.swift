import SwiftUI

// MARK: - Training

struct TrainingView: View {
    @EnvironmentObject var store: GameStore
    @State private var plan = TrainingPlan()
    @State private var loaded = false
    @State private var report: [String]? = nil

    var body: some View {
        let c = store.career
        let year = c?.year ?? 0
        let squad = c.map { car in car.squad(car.userClubId).sorted { $0.age(in: car.year) < $1.age(in: car.year) } } ?? []
        PaneScreen(title: "Training") {
            PaneBox(title: "This week", note: "One session per week (a week = your next match). If you don't start it, it runs after the match.") {
                if c?.phase == .season {
                    ActionChip(icon: "figure.run", title: c?.trainingDoneThisWeek == true ? "This week's session is done" : "Start this week's session",
                               primary: c?.trainingDoneThisWeek != true, disabled: c?.trainingDoneThisWeek == true) {
                        report = store.careerRunTraining()
                        Haptics.success()
                    }
                } else {
                    Text("Training sessions run during the season.").font(.system(size: 13 * TextScale.factor)).foregroundStyle(Palette.muted)
                }
                if let report {
                    if report.isEmpty {
                        Text("Session done. No visible gains this week: keep going.").font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted)
                    }
                    ForEach(report, id: \.self) { line in
                        Label(line, systemImage: "arrow.up.circle.fill").font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.accent)
                    }
                }
            }
            PaneBox(title: "Weekly drills · \(c?.trainingSlots ?? 3) slots",
                    note: "Every player may gain a point in the drilled skills after each match. Under-22s learn fastest; hard sessions develop faster but cost form.") {
                ForEach(0..<plan.drills.count, id: \.self) { i in
                    HStack {
                        Text("Slot \(i + 1)").font(.system(size: 13 * TextScale.factor)).foregroundStyle(Palette.muted)
                        Spacer()
                        MenuChip(title: "\(plan.drills[i].icon) \(plan.drills[i].label)") {
                            ForEach(Drill.allCases) { d in Button("\(d.icon) \(d.label)") { setDrill(i, d) } }
                        }
                    }
                }
                if plan.drills.count < (c?.trainingSlots ?? 3) {
                    ActionChip(icon: "plus", title: "Add a drill slot") { plan.drills.append(.fitness) }
                }
                Picker("Intensity", selection: $plan.intensity) {
                    ForEach(Intensity.allCases, id: \.self) { i in Text(i.label).tag(i) }
                }
                .pickerStyle(.segmented)
                if let car = c {
                    if car.trainingBoostWeeks > 0 {
                        Text("Training boost active: \(car.trainingBoostWeeks) weeks left").font(.system(size: 12 * TextScale.factor, weight: .bold))
                            .foregroundStyle(Palette.accent)
                    } else {
                        ActionChip(icon: "bolt.fill", title: "Boost +50% for 4 weeks · \(car.goldCost(.trainingBoost)) gold") {
                            _ = store.careerSpendGold(.trainingBoost)
                        }
                    }
                }
            }
        } right: {
            VStack(alignment: .leading, spacing: 5) {
                Text("INDIVIDUAL FOCUS · GROWS ABOUT 2.5× FASTER THAN A DRILL")
                    .font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted).lineLimit(1)
                TableHead {
                    Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
                    Text("AGE").frame(width: TCol.age, alignment: .trailing)
                    Text("NOW").frame(width: TCol.stat, alignment: .trailing)
                    Text("POT").frame(width: TCol.stat, alignment: .trailing)
                    Text("FOCUS").frame(width: 112, alignment: .trailing)
                }
                LazyVStack(spacing: 4) {
                    ForEach(squad) { p in
                        HStack(spacing: 8) {
                            TName(text: p.name, overseas: p.overseas)
                            TNum(text: "\(p.age(in: year))", width: TCol.age, color: Palette.muted)
                            TNum(text: "\(max(p.bat, p.bowl))", width: TCol.stat, color: strengthColor(max(p.bat, p.bowl)))
                            TNum(text: "\(p.potential)", width: TCol.stat, color: Palette.four)
                            Menu {
                                Button("No focus") { plan.focus[p.id] = nil }
                                ForEach(Attributes.trainable, id: \.name) { t in
                                    Button(t.label) { plan.focus[p.id] = t.name }
                                }
                            } label: {
                                Text(focusLabel(p.id)).font(.system(size: 12 * TextScale.factor, weight: .bold))
                                    .foregroundStyle(plan.focus[p.id] == nil ? Palette.muted : Palette.accent).lineLimit(1)
                            }
                            .frame(width: 112, alignment: .trailing)
                        }
                        .tableRow()
                    }
                }
            }
        }
        .onAppear {
            if !loaded, let t = store.career?.training {
                plan = t
                loaded = true
            }
        }
        .onChange(of: plan) { p in
            if loaded { store.careerSetTraining(p) }
        }
    }

    private func setDrill(_ i: Int, _ d: Drill) {
        if i < plan.drills.count { plan.drills[i] = d }
    }

    private func focusLabel(_ id: String) -> String {
        guard let name = plan.focus[id] else { return "Focus ▾" }
        return (Attributes.trainable.first { $0.name == name }?.label ?? name) + " ▾"
    }
}

// MARK: - Academy

struct AcademyView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.verticalSizeClass) private var vSize
    @State private var message: String? = nil

    var body: some View {
        let c = store.career
        let kids = c?.academyPlayers.sorted { $0.potential > $1.potential } ?? []
        TableScreen(title: "Academy") {
            SummaryLine(cells: [
                SummaryCell(value: "\(kids.count)/\(c?.tuning.academyMax ?? 8)", label: "in the academy"),
                SummaryCell(value: "\(kids.map(\.potential).max() ?? 0)", label: "best potential", color: Palette.four),
                SummaryCell(value: Money.format(c?.tuning.minWage ?? 20), label: "to promote"),
            ])
            TableNote(text: message ?? (kids.isEmpty ? "No academy players right now. A new intake arrives every off-season."
                                                     : "Academy kids train with your plan and cost nothing until promoted."),
                      warning: message != nil && message?.contains("joins") != true)
            TableHead {
                Text("OVR").frame(width: TCol.ovr, alignment: .center)
                Text("PLAYER · \(kids.count)").frame(maxWidth: .infinity, alignment: .leading)
                Text("ROLE").frame(width: TCol.role, alignment: .leading)
                Text("AGE").frame(width: TCol.age, alignment: .trailing)
                if vSize == .compact {
                    Text("BAT").frame(width: TCol.stat, alignment: .trailing)
                    Text("BOWL").frame(width: TCol.stat, alignment: .trailing)
                }
                Text("POT").frame(width: TCol.stat, alignment: .trailing)
                Text("").frame(width: vSize == .compact ? 200 : 76)
            }
        } rows: {
            ForEach(kids) { p in
                HStack(spacing: 8) {
                    NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                        HStack(spacing: 8) {
                            TNum(text: "\(p.rating)", width: TCol.ovr, color: strengthColor(p.rating), align: .center)
                            TName(text: p.name, overseas: p.overseas)
                            TRole(role: p.role)
                            TNum(text: "\(p.age(in: c?.year ?? 0))", width: TCol.age, color: Palette.muted)
                            if vSize == .compact {
                                TNum(text: "\(p.bat)", width: TCol.stat, color: Palette.muted)
                                TNum(text: p.bowl >= 25 ? "\(p.bowl)" : "–", width: TCol.stat, color: Palette.muted)
                            }
                            TNum(text: "\(p.potential)", width: TCol.stat, color: Palette.four)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 6) {
                        ActionChip(icon: "arrow.up.circle", title: "Promote", iconOnly: vSize != .compact) {
                            message = store.careerPromote(p.id) ?? "\(p.name) joins the squad on \(Money.format(c?.tuning.minWage ?? 20))."
                        }
                        ActionChip(icon: "xmark", title: "Release", destructive: true, iconOnly: vSize != .compact) {
                            store.careerReleaseAcademy(p.id)
                        }
                    }
                    .frame(width: vSize == .compact ? 200 : 76, alignment: .trailing)
                }
                .tableRow()
            }
        }
    }
}

// MARK: - Scouting

struct ScoutingView: View {
    @EnvironmentObject var store: GameStore
    @State private var message: String? = nil

    var body: some View {
        let c = store.career
        let s = c?.scouting ?? ScoutingState()
        PaneScreen(title: "Scouting") {
            PaneBox(title: "Your scouts · \(s.scouts.count)/\(c?.scoutCap ?? 2)",
                    note: "Give each scout a job. After every match he watches the best candidates for it; his shortlist is on the right.") {
                if s.scouts.isEmpty {
                    Text("No scouts. Hire one below.").font(.system(size: 13 * TextScale.factor)).foregroundStyle(Palette.muted)
                }
                ForEach(Array(s.scouts.enumerated()), id: \.element.id) { i, scout in
                    if i > 0 { Hairline() }
                    ScoutRow(scout: scout, regions: c?.scoutRegions ?? ["ANY"])
                }
            }
            PaneBox(title: "Available to hire") {
                ForEach(s.candidates) { cand in
                    HStack(spacing: 8) {
                        Text(cand.name).font(.system(size: 14 * TextScale.factor, weight: .semibold)).lineLimit(1)
                        Text(String(repeating: "★", count: cand.stars) + String(repeating: "☆", count: 5 - cand.stars))
                            .font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.accent)
                        Spacer(minLength: 4)
                        ActionChip(icon: "plus", title: "Hire · \(Money.format(cand.wage))/yr") {
                            message = store.careerHireScout(cand.id) ?? "\(cand.name) hired."
                        }
                    }
                }
                if let message { TableNote(text: message) }
            }
        } right: {
            VStack(alignment: .leading, spacing: 8) {
                if let c {
                    ForEach(s.scouts) { scout in
                        ScoutShortlist(career: c, scout: scout)
                    }
                }
            }
        }
    }
}

/// One scout's shortlist: title with his job, then up to five players.
struct ScoutShortlist: View {
    let career: Career
    let scout: Scout

    var body: some View {
        let c = career
        let job = c.mission(of: scout)
        let picks = c.scoutPicks(scout)
        let target = c.scoutTarget(scout)
        VStack(alignment: .leading, spacing: 4) {
            Text("\(scout.name.uppercased()) · \(target.map { "UPGRADE ON \($0.name.uppercased()) (\($0.rating))" } ?? job.label.uppercased())")
                .font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted).lineLimit(1)
            ScoutPickTable(career: c, picks: picks, showGain: target != nil,
                           empty: "Watching… the first names come after your next match.")
        }
    }
}

/// OVR, player, gain or potential, price (red when you can't afford it yet).
struct ScoutPickTable: View {
    let career: Career
    let picks: [ScoutPick]
    let showGain: Bool
    let empty: String

    var body: some View {
        let c = career
        VStack(spacing: 0) {
            TableHead {
                Text("OVR").frame(width: TCol.ovr, alignment: .center)
                Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
                Text("AGE").frame(width: TCol.age, alignment: .trailing)
                Text(showGain ? "GAIN" : "POT").frame(width: 46, alignment: .trailing)
                Text("PRICE").frame(width: 76, alignment: .trailing)
            }
            if picks.isEmpty {
                Text(empty).font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).tableRow()
            }
            ForEach(picks) { pick in
                let p = pick.player
                NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                    HStack(spacing: 8) {
                        TNum(text: "\(p.rating)", width: TCol.ovr, color: strengthColor(p.rating), align: .center)
                        TName(text: p.name, overseas: p.overseas, pitchFit: c.suitsUserPitch(p))
                        TNum(text: "\(p.age(in: c.year))", width: TCol.age, color: Palette.muted)
                        TNum(text: pick.gain.map { "+\($0)" } ?? c.potentialLabel(p), width: 46, color: Palette.four)
                        TNum(text: pick.fee > 0 ? Money.format(pick.fee) : "Free", width: 76,
                             color: pick.affordable ? Palette.accent : Palette.wicket)
                    }
                    .tableRow()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Player card › Find an upgrade: puts a scout on this player and shows his shortlist.
struct ScoutUpgradeScreen: View {
    @EnvironmentObject var store: GameStore
    let playerId: String
    @State private var problem: String? = nil

    var body: some View {
        let c = store.career
        let p = c?.players[playerId]
        TableScreen(title: "Upgrades for \(p?.name ?? "player")") {
            if let c, let p {
                SummaryLine(cells: [SummaryCell(value: "\(p.rating)", label: "OVR"),
                                    SummaryCell(value: p.role.short, label: "role"),
                                    SummaryCell(value: c.upgradeScout(for: playerId)?.name ?? "No scout", label: "scout")])
                TableNote(text: problem ?? "Better \(p.role.label.lowercased())s, best value first. Red price: not affordable yet (bank or salary cap). The list grows after each match.")
            }
        } rows: {
            if let c, let scout = c.upgradeScout(for: playerId) {
                ScoutPickTable(career: c, picks: c.scoutPicks(scout, limit: 8), showGain: true,
                               empty: "No better \(p?.role.label.lowercased() ?? "player")s found yet.")
            }
        }
        .onAppear { problem = store.careerScoutUpgrade(playerId) }
    }
}

struct ScoutRow: View {
    @EnvironmentObject var store: GameStore
    let scout: Scout
    let regions: [String]

    private static let roles: [Role?] = [nil, .BAT, .WK, .AR, .BOWL]

    var body: some View {
        let c = store.career
        let job = c?.mission(of: scout) ?? .talent
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(scout.name).font(.system(size: 14 * TextScale.factor, weight: .semibold)).lineLimit(1)
                Text(String(repeating: "★", count: scout.stars)).font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.accent)
                Spacer(minLength: 4)
                ActionChip(icon: "xmark", title: "Fire", destructive: true) { store.careerFireScout(scout.id) }
            }
            HStack(spacing: 6) {
                MenuChip(title: c?.scoutTarget(scout).map { "Upgrade \($0.name)" } ?? job.label) {
                    Menu("Upgrade a player") {
                        ForEach(c.map { car in car.squad(car.userClubId).sorted { $0.rating > $1.rating } } ?? []) { p in
                            Button("\(p.name) · \(p.role.short) \(p.rating)") { store.careerSetScoutMission(scout.id, .upgrade, target: p.id) }
                        }
                    }
                    ForEach(ScoutMission.allCases.filter { $0 != .upgrade }) { m in
                        Button(m.label) { store.careerSetScoutMission(scout.id, m) }
                    }
                }
                MenuChip(title: scout.region == "ANY" ? "Anywhere" : scout.region) {
                    ForEach(regions, id: \.self) { r in
                        Button(r == "ANY" ? "Anywhere" : r) {
                            store.careerAssignScout(scout.id, region: r, role: scout.role, youthOnly: scout.youthOnly)
                        }
                    }
                }
                if job != .upgrade {
                    MenuChip(title: scout.role?.short ?? "Any role") {
                        ForEach(0..<Self.roles.count, id: \.self) { i in
                            Button(Self.roles[i]?.label ?? "Any role") {
                                store.careerAssignScout(scout.id, region: scout.region, role: Self.roles[i], youthOnly: scout.youthOnly)
                            }
                        }
                    }
                }
                if job == .talent {
                    FilterChip(title: "U21", on: scout.youthOnly) {
                        store.careerAssignScout(scout.id, region: scout.region, role: scout.role, youthOnly: !scout.youthOnly)
                    }
                }
                Spacer(minLength: 0)
            }
            Text(job.blurb).font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(1)
        }
    }
}
