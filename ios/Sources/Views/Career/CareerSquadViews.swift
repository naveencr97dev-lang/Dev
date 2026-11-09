import SwiftUI

// MARK: - Squad tab

struct CareerSquadTab: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        if let c = store.career {
            let club = c.userClub
            let squad = c.squad(club.id)
            let issues = c.xiIssues(club.id)
            let bench = squad.filter { !club.xi.contains($0.id) }.sorted { $0.rating > $1.rating }
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Squad").font(.display(28, weight: .bold))
                    Text("\(squad.count) players · \(squad.filter(\.overseas).count)/\(c.tuning.maxOverseasSquad) overseas · wages \(Money.format(c.payroll(club.id))) · strength \(c.strength(club.id))")
                        .font(.display(14, weight: .regular)).foregroundStyle(Palette.muted)
                }
                if !issues.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(issues, id: \.self) { issue in
                            Label(issue, systemImage: "exclamationmark.triangle.fill").font(.display(14, weight: .semibold)).foregroundStyle(.orange)
                        }
                        Text("The best XI is picked automatically until this is fixed.")
                            .font(.display(12, weight: .regular)).foregroundStyle(Palette.muted)
                    }
                }
                VStack(spacing: 0) {
                    NavigationLink { PickXIView() } label: { DashTile(icon: "checklist", title: "Pick XI") }
                    Hairline(inset: 54)
                    NavigationLink { BattingOrderView(teamId: club.id) } label: { DashTile(icon: "arrow.up.arrow.down", title: "Batting order") }
                    Hairline(inset: 54)
                    NavigationLink { BowlingPlanView(teamId: club.id) } label: { DashTile(icon: "figure.cricket", title: "Bowling plan") }
                    Hairline(inset: 54)
                    NavigationLink { TacticsView() } label: { DashTile(icon: "slider.horizontal.3", title: "Tactics") }
                    Hairline(inset: 54)
                    NavigationLink { TrainingView() } label: {
                        DashTile(icon: "dumbbell", title: "Training", subtitle: c.trainingDoneThisWeek ? "Done this week" : "Session ready")
                    }
                    Hairline(inset: 54)
                    NavigationLink { AcademyView() } label: { DashTile(icon: "graduationcap", title: "Academy", subtitle: "\(c.academy.count) prospects") }
                    Hairline(inset: 54)
                    NavigationLink { CareerScreen(title: "Squad report") { SquadReportView() } } label: {
                        let unhappy = squad.filter { c.morale($0) < 45 }.count
                        DashTile(icon: "list.bullet.clipboard", title: "Squad report",
                                 subtitle: unhappy > 0 ? "\(unhappy) unhappy with their role" : "Strengths and weak spots")
                    }
                }
                .gameFrame()
                .buttonStyle(.plain)
                Button {
                    store.careerAutoXI()
                    Haptics.success()
                } label: {
                    Label("Auto-pick best XI and order", systemImage: "sparkles")
                }
                .buttonStyle(SecondaryButtonStyle())

                SectionLabel(text: "Playing XI · batting order")
                AppCard(padding: DS.Space.md) {
                    VStack(spacing: 6) {
                        ForEach(Array(club.xi.enumerated()), id: \.element) { i, pid in
                            if let p = store.player(pid) {
                                NavigationLink { CareerPlayerView(playerId: pid) } label: {
                                    BattingSlotRow(position: i, player: p)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                SectionLabel(text: "Bench")
                AppCard(padding: DS.Space.md) {
                    VStack(spacing: 8) {
                        if bench.isEmpty {
                            Text("Everyone is in the XI.").font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach(bench) { cp in
                            NavigationLink { CareerPlayerView(playerId: cp.id) } label: {
                                CareerPlayerRow(player: cp, year: c.year)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

struct SquadAction: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3)
            Text(text.uppercased()).font(.display(12, weight: .heavy))
        }
        .foregroundStyle(Palette.accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surfaceHi))
    }
}

/// Compact career row: role, name, age, form and overall rating.
struct CareerPlayerRow: View {
    let player: CareerPlayer
    let year: Int

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(player.name).font(.body.weight(.semibold)).lineLimit(1)
                    if player.overseas { Image(systemName: "airplane").font(.caption2).foregroundStyle(Palette.muted) }
                    if player.legend { Image(systemName: "star.fill").font(.caption2).foregroundStyle(CareerPalette.gold) }
                    if !player.traits.isEmpty { Text(player.traits.map(\.icon).joined()).font(.caption) }
                }
                HStack(spacing: 6) {
                    RoleChip(role: player.role)
                    Text("Age \(player.age(in: year)) · BAT \(player.bat) · BOWL \(player.bowl)")
                        .font(.caption2).foregroundStyle(Palette.muted)
                    Text("FORM \(CareerText.form(player.form))")
                        .font(.caption2.weight(.bold)).foregroundStyle(CareerText.formColor(player.form))
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(player.rating)").font(.display(26)).foregroundStyle(strengthColor(player.rating))
                Text(player.contract.map { Money.format($0.wage) } ?? "OVR")
                    .font(.display(10, weight: .heavy)).foregroundStyle(Palette.muted).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// MARK: - Pick XI

struct PickXIView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var loaded = false

    var body: some View {
        let squad = (store.career?.userClub.squad ?? []).compactMap { store.player($0) }
        let picked = squad.filter { selected.contains($0.id) }
        let rules = store.career?.rules ?? Rules()
        let issues = TeamSelector.blockingIssues(picked, rules: rules) + TeamSelector.warnings(picked)
        List {
            Section {
                HStack {
                    Text("\(picked.count)/11 picked").font(.headline)
                    Spacer()
                    Text("\(picked.filter(\.overseas).count)/\(rules.maxOverseasXI) overseas")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                }
                ForEach(issues, id: \.self) { issue in
                    Text(issue).font(.caption.weight(.bold)).foregroundStyle(.orange)
                }
            } footer: {
                Text("Tap to pick or drop. New picks slot into the batting order where they bat best; adjust it later in Order.")
            }
            .listRowBackground(GameRowBackground())

            ForEach(Role.allCases, id: \.self) { role in
                let group = squad.filter { $0.role == role }.sorted { max($0.bat, $0.bowl) > max($1.bat, $1.bowl) }
                if !group.isEmpty {
                    Section(role.label + "s") {
                        ForEach(group) { p in
                            Button { toggle(p.id) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selected.contains(p.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selected.contains(p.id) ? Palette.accent : Palette.muted)
                                    PlayerRow(player: p, trailing: formText(p.id))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(GameRowBackground())
                }
            }
        }
        .darkList()
        .navigationTitle("Pick XI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    store.careerPickXI(selected)
                    Haptics.success()
                    dismiss()
                }
                .disabled(!TeamSelector.blockingIssues(picked, rules: rules).isEmpty)
            }
        }
        .onAppear {
            if !loaded {
                selected = Set(store.career?.userClub.xi ?? [])
                loaded = true
            }
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else if selected.count < 11 {
            selected.insert(id)
        } else {
            Haptics.warning()
            return
        }
        Haptics.tap()
    }

    private func formText(_ id: String) -> String {
        guard let p = store.careerPlayer(id) else { return "" }
        return "form \(CareerText.form(p.form))"
    }
}

// MARK: - Player profile

struct CareerPlayerView: View {
    @EnvironmentObject var store: GameStore
    let playerId: String

    var body: some View {
        ScrollView {
            if let c = store.career, let p = c.players[playerId] {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    header(c, p)
                    if p.clubId == c.userClubId { RoleMoraleCard(career: c, player: p) }
                    if !p.traits.isEmpty {
                        SectionLabel(text: "Traits")
                        AppCard { TraitChips(traits: p.traits, showBlurb: true) }
                    }
                    SectionLabel(text: "Batting · \(p.bat)")
                    AppCard {
                        VStack(spacing: 8) {
                            RatingBar(label: "TEC", value: p.attr.technique, color: Palette.four)
                            RatingBar(label: "PWR", value: p.attr.power, color: Palette.four)
                            RatingBar(label: "PACE", value: p.attr.vsPace, color: Palette.four)
                            RatingBar(label: "SPIN", value: p.attr.vsSpin, color: Palette.four)
                            RatingBar(label: "TEMP", value: p.attr.temperament, color: Palette.four)
                        }
                    }
                    SectionLabel(text: "Bowling · \(p.bowl) \(p.bowlType == .spin ? "spin" : "pace")")
                    AppCard {
                        VStack(spacing: 8) {
                            RatingBar(label: "ACC", value: p.attr.accuracy, color: Palette.wicket)
                            RatingBar(label: p.bowlType == .spin ? "TURN" : "PACE", value: p.attr.potency, color: Palette.wicket)
                            RatingBar(label: "VAR", value: p.attr.variation, color: Palette.wicket)
                            RatingBar(label: "DTH", value: p.attr.death, color: Palette.wicket)
                            RatingBar(label: "NEW", value: p.attr.newBall, color: Palette.wicket)
                        }
                    }
                    SectionLabel(text: "Fielding")
                    AppCard {
                        VStack(spacing: 8) {
                            RatingBar(label: "FLD", value: p.attr.fielding, color: Palette.six)
                            if p.role == .WK {
                                RatingBar(label: "KEEP", value: p.attr.keeping, color: Palette.six)
                            }
                        }
                    }
                    PlayerStatsSection(career: c, player: p)
                    SectionLabel(text: "Transfer")
                    TransferActions(playerId: playerId)
                    GoldActions(playerId: playerId)
                }
                .padding(DS.Space.lg)
            }
        }
        .background(AppBackground())
        .navigationTitle(store.career?.players[playerId]?.name ?? "Player")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ c: Career, _ p: CareerPlayer) -> some View {
        let club = p.clubId.flatMap { c.club($0) }
        return AppCard(tint: club.map { Color(hex: $0.colorHex) }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    RoleChip(role: p.role)
                    Chip(text: p.country)
                    if p.overseas { Chip(text: "Overseas") }
                    if p.legend { Chip(text: "★ Legend", color: Palette.accent.opacity(0.2), textColor: Palette.accent) }
                }
                Text(p.name.uppercased()).font(.display(30)).lineLimit(1).minimumScaleFactor(0.6)
                Text("Age \(p.age(in: c.year)) · bats \(p.slot.label.lowercased()) · \(club?.name ?? "Free agent")")
                    .font(.subheadline).foregroundStyle(Palette.muted)
                HStack(spacing: 0) {
                    big("\(p.rating)", "OVR", strengthColor(p.rating))
                    big("\(p.bat)", "BAT", strengthColor(p.bat))
                    big("\(p.bowl)", "BOWL", strengthColor(p.bowl))
                    big(CareerText.form(p.form), "FORM", CareerText.formColor(p.form))
                }
                Text("Value \(Money.format(p.value(in: c.year))) · Potential \(c.potentialLabel(p))\(c.knowledge(of: p.id) < 100 ? " (scouted \(c.knowledge(of: p.id))%)" : "")")
                    .font(.subheadline.weight(.semibold))
                if !p.line.isEmpty {
                    Text(p.line).font(.caption).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private func big(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.display(30)).foregroundStyle(color)
            Text(label).font(.display(10, weight: .heavy)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Any club's squad

struct CareerClubView: View {
    @EnvironmentObject var store: GameStore
    let clubId: Int

    var body: some View {
        ScrollView {
            if let c = store.career, let club = c.club(clubId) {
                let squad = c.squad(clubId).sorted { $0.rating > $1.rating }
                let info = c.info(clubId)
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    AppCard(tint: Color(hex: club.colorHex)) {
                        HStack(spacing: 12) {
                            TeamBadge(team: club, size: 52)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(club.name.uppercased()).font(.display(22))
                                if let info {
                                    Text("\(info.homePitch.icon) \(info.homePitch.label) · 🏆 \(info.titles)")
                                        .font(.caption).foregroundStyle(Palette.muted)
                                }
                                Text("\(Career.ordinal(c.position(of: clubId))) · strength \(c.strength(clubId))")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                    SectionLabel(text: "Squad")
                    AppCard(padding: DS.Space.md) {
                        VStack(spacing: 8) {
                            ForEach(squad) { cp in
                                NavigationLink { CareerPlayerView(playerId: cp.id) } label: {
                                    CareerPlayerRow(player: cp, year: c.year)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(DS.Space.lg)
            }
        }
        .background(AppBackground())
        .navigationTitle(store.career?.club(clubId)?.short ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Career › Squad › Roles and morale: the promised role, morale, playing time and the player's future.
struct RoleMoraleCard: View {
    @EnvironmentObject var store: GameStore
    let career: Career
    let player: CareerPlayer

    var body: some View {
        let c = career, p = player
        let m = c.morale(p)
        let share = c.playedShare(p.id)
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Role and morale")
            VStack(spacing: 0) {
                HStack {
                    Text("Squad role").font(.display(16, weight: .regular))
                    Spacer()
                    Menu {
                        ForEach(SquadRole.allCases) { r in
                            Button { store.careerSetSquadRole(p.id, r) } label: {
                                if r == c.squadRole(p) { Label(r.label, systemImage: "checkmark") } else { Text(r.label) }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(c.squadRole(p).label)
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 12 * TextScale.factor, weight: .semibold))
                        }
                        .font(.display(16, weight: .semibold)).foregroundStyle(Palette.accent)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                Hairline(inset: 16)
                InfoRow(label: "Morale", value: "\(m) · \(c.future(p))", color: MoraleStyle.color(m), chevron: false)
                Hairline(inset: 16)
                InfoRow(label: "Playing time", value: share.map { "\(Int($0 * 100))% of recent matches (expects \(Int(c.squadRole(p).expectedShare * 100))%)" } ?? "Not enough matches yet",
                        chevron: false)
            }
            .gameFrame()
            Text("Playing less than his role promises lowers morale. Very unhappy players ask to leave. A demotion costs 10 morale a step.")
                .font(.display(12, weight: .regular)).foregroundStyle(Palette.muted)
        }
    }
}

enum MoraleStyle {
    static func color(_ m: Int) -> Color { m >= 70 ? Palette.accent : (m >= 45 ? .white : (m >= 25 ? .orange : Palette.wicket)) }
}

/// Career › Squad › Squad report: averages, the three best players, strengths and weak spots.
struct SquadReportView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        if let c = store.career {
            let r = c.squadReport()
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                HStack(spacing: 0) {
                    stat("\(r.averageRating)", "AVG RATING")
                    stat("\(c.squad(c.userClubId).count)", "SQUAD")
                    stat(String(format: "%.1f", r.averageAge), "AVG AGE")
                    stat(Money.format(r.totalValue), "VALUE")
                }
                .padding(.vertical, DS.Space.sm)
                .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surface))
                SectionLabel(text: "Best players")
                VStack(spacing: 8) {
                    ForEach(r.stars) { p in
                        NavigationLink { CareerPlayerView(playerId: p.id) } label: { CareerPlayerRow(player: p, year: c.year) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(DS.Space.md)
                .gameFrame()
                SectionLabel(text: "Strengths")
                lines(r.strengths, icon: "checkmark", color: Palette.accent)
                SectionLabel(text: "Weak spots")
                lines(r.weaknesses.isEmpty ? ["Nothing stands out."] : r.weaknesses, icon: "xmark", color: Palette.wicket)
            }
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.display(18)).lineLimit(1).minimumScaleFactor(0.6)
            Text(l).font(.display(9, weight: .heavy)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func lines(_ items: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, line in
                if i > 0 { Hairline(inset: 44) }
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon).font(.system(size: 14 * TextScale.factor, weight: .bold)).foregroundStyle(color)
                        .frame(width: 16)
                    Text(line).font(.display(15, weight: .regular)).foregroundStyle(.white)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
            }
        }
        .gameFrame()
    }
}
