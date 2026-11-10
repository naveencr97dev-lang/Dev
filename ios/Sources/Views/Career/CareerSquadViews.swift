import SwiftUI

// MARK: - Squad tab

struct CareerSquadTab: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.compactLandscape) private var compact
    @State private var selected: String? = nil
    @State private var message: String? = nil

    var body: some View {
        if let c = store.career {
            let club = c.userClub
            let squad = c.squad(club.id)
            let issues = c.xiIssues(club.id)
            let bench = squad.filter { !club.xi.contains($0.id) }.sorted { $0.rating > $1.rating }.map(\.id)
            // Device feedback: the XI is a fixed list on the left; tools and the bench on the right.
            AdaptiveColumns(leftScrolls: false) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Squad").font(.display(compact ? 18 : 28, weight: .bold))
                    Text("\(squad.count) players · \(squad.filter(\.overseas).count)/\(c.tuning.maxOverseasSquad) overseas · strength \(c.strength(club.id))")
                        .font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(1)
                }
                EditableLineup(title: "Playing XI · batting order", ids: club.xi, selected: $selected, message: $message)
                HStack(spacing: 8) {
                    Text(message ?? (selected == nil ? "Drag a bench player onto someone to swap, or tap one then the other." : "Now tap who to swap with."))
                        .font(.system(size: 11 * TextScale.factor, weight: message == nil ? .regular : .semibold))
                        .foregroundStyle(message == nil ? Palette.muted : Color.orange)
                    if let id = selected {
                        NavigationLink { CareerPlayerView(playerId: id) } label: {
                            Text("Open profile ›").font(.system(size: 11 * TextScale.factor, weight: .bold)).foregroundStyle(Palette.accent)
                        }
                    }
                }
            } right: {
                if !issues.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(issues, id: \.self) { issue in
                            Label(issue, systemImage: "exclamationmark.triangle.fill").font(.display(13, weight: .semibold)).foregroundStyle(.orange)
                        }
                        Text("The best XI is picked automatically until this is fixed.")
                            .font(.display(12, weight: .regular)).foregroundStyle(Palette.muted)
                    }
                }
                EditableLineup(title: "Bench · \(bench.count)", ids: bench, numbered: false, selected: $selected, message: $message)
                Button {
                    store.careerAutoXI()
                    Haptics.success()
                } label: {
                    Label("Auto-pick best XI and order", systemImage: "sparkles")
                }
                .buttonStyle(SecondaryButtonStyle())
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
                    NavigationLink { CareerScreen(title: "Squad planner") { SquadPlannerView() } } label: {
                        DashTile(icon: "square.grid.3x3", title: "Squad planner", subtitle: "Depth chart for every job in the XI")
                    }
                    Hairline(inset: 54)
                    NavigationLink { CareerScreen(title: "Development") { DevelopmentReportView() } } label: {
                        DashTile(icon: "chart.line.uptrend.xyaxis", title: "Development", subtitle: "Young players this season")
                    }
                    Hairline(inset: 54)
                    NavigationLink { CareerScreen(title: "Club stats") { ClubStatsView() } } label: {
                        DashTile(icon: "chart.bar", title: "Club stats", subtitle: "Runs, wickets, match ratings")
                    }
                    Hairline(inset: 54)
                    NavigationLink { CareerScreen(title: "Squad report") { SquadReportView() } } label: {
                        let cold = squad.filter { club.xi.contains($0.id) && $0.form <= -4 }.count
                        DashTile(icon: "list.bullet.clipboard", title: "Squad report",
                                 subtitle: cold > 0 ? "\(cold) out of form in the XI" : "Strengths and weak spots")
                    }
                }
                .gameFrame()
                .buttonStyle(.plain)
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
                    FormCard(career: c, player: p)
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

/// Career › Squad › Form: the player's form, its trend and his recent match ratings.
struct FormCard: View {
    let career: Career
    let player: CareerPlayer

    var body: some View {
        let c = career, p = player
        let trend = c.formTrend(p.id)
        let recent = c.recentRatings(p.id)
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Form")
            VStack(spacing: 0) {
                InfoRow(label: "Form", value: "\(Career.formLabel(p.form)) · \(CareerText.form(p.form))",
                        color: CareerText.formColor(p.form), chevron: false)
                Hairline(inset: 16)
                InfoRow(label: "Trend", value: trend > 0 ? "Rising" : (trend < 0 ? "Falling" : "Level"),
                        color: trend > 0 ? Palette.accent : (trend < 0 ? Palette.wicket : .white), chevron: false)
                Hairline(inset: 16)
                InfoRow(label: "Match rating", value: c.averageRating(p.id).map { "\(String(format: "%.2f", $0)) over \(c.matchRatings(p.id).count) matches" } ?? "No matches this season",
                        chevron: false)
                if !recent.isEmpty {
                    Hairline(inset: 16)
                    HStack {
                        Text("Last \(recent.count)").font(.display(16, weight: .regular))
                        Spacer()
                        ForEach(Array(recent.enumerated()), id: \.offset) { _, x in
                            Text(String(format: "%.1f", x)).font(.score(16)).foregroundStyle(RatingStyle.color(x))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
            .gameFrame()
            Text("Form comes from recent performances and moves his batting and bowling by up to 3 in matches. It drifts back towards steady between games.")
                .font(.display(12, weight: .regular)).foregroundStyle(Palette.muted)
        }
    }
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

enum RatingStyle {
    /// Match ratings: 8+ excellent, 7+ good, 6+ fair, below that poor.
    static func color(_ x: Double) -> Color { x >= 8 ? Palette.accent : (x >= 7 ? Palette.four : (x >= 6 ? .white : .orange)) }
}

/// Career › Squad › Club stats: the user's players ranked by one category.
struct ClubStatsView: View {
    @EnvironmentObject var store: GameStore
    @State private var category = Category.runs

    enum Category: String, CaseIterable, Identifiable {
        case runs = "Runs", wickets = "Wickets", rating = "Match rating", sixes = "Sixes"
        case strikeRate = "Strike rate", economy = "Economy", potm = "Player of the match"
        var id: String { rawValue }
        /// Header of the middle column (a rate that puts the total in context).
        var rateLabel: String {
            switch self {
            case .runs: return "SR"
            case .wickets: return "Econ"
            case .sixes: return "Balls/6"
            case .strikeRate: return "Runs"
            case .economy: return "Wkts"
            case .rating, .potm: return ""
            }
        }
    }

    var body: some View {
        if let c = store.career {
            let season = c.seasonStatLines
            let rows = ranked(c, season)
            VStack(alignment: .leading, spacing: DS.Space.md) {
                HStack {
                    Text("Season \(String(c.year))").font(.display(14, weight: .semibold)).foregroundStyle(Palette.muted)
                    Spacer()
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                HStack {
                    Text("Player").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Apps").frame(width: 44)
                    Text(category.rateLabel).frame(width: 60)
                    Text(category == .rating ? "Avg" : "Total").frame(width: 56, alignment: .trailing)
                }
                .font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                .padding(.horizontal, 16)
                VStack(spacing: 0) {
                    if rows.isEmpty {
                        Text("No matches played this season yet.").font(.subheadline).foregroundStyle(.secondary)
                            .padding(16)
                    }
                    ForEach(Array(rows.enumerated()), id: \.element.0.id) { i, row in
                        if i > 0 { Hairline(inset: 16) }
                        NavigationLink { CareerPlayerView(playerId: row.0.id) } label: {
                            HStack {
                                Text(row.0.name).font(.display(15, weight: i == 0 ? .semibold : .regular)).lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(row.1)").font(.score(15)).foregroundStyle(Palette.muted).frame(width: 44)
                                Text(row.2).font(.score(15)).foregroundStyle(Palette.muted).frame(width: 60)
                                Text(row.3).font(.score(16)).foregroundStyle(Palette.accent).frame(width: 56, alignment: .trailing)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .gameFrame()
                Text("Match ratings run from 3 to 10: runs and strike rate, wickets and economy, the result and player of the match. Strike rate needs 30 balls faced, economy 24 bowled.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }

    /// (player, apps, rate, total) for the chosen category, best first.
    private func ranked(_ c: Career, _ season: [String: StatLine]) -> [(CareerPlayer, Int, String, String)] {
        let squad = c.squad(c.userClubId)
        let f1 = { (x: Double) in String(format: "%.1f", x) }
        var rows: [(CareerPlayer, Int, String, String, Double)] = []
        for p in squad {
            let s = season[p.id] ?? StatLine()
            guard s.matches > 0 else { continue }
            switch category {
            case .runs:
                rows.append((p, s.matches, s.balls > 0 ? f1(s.strikeRate) : "–", "\(s.runs)", Double(s.runs)))
            case .wickets:
                guard s.ballsBowled > 0 else { continue }
                rows.append((p, s.matches, f1(s.economy), "\(s.wickets)", Double(s.wickets) - s.economy / 100))
            case .rating:
                guard let avg = c.averageRating(p.id) else { continue }
                rows.append((p, s.matches, "", String(format: "%.2f", avg), avg))
            case .sixes:
                guard s.sixes > 0 else { continue }
                rows.append((p, s.matches, "\(s.balls / max(1, s.sixes))", "\(s.sixes)", Double(s.sixes)))
            case .strikeRate:
                guard s.balls >= 30 else { continue }
                rows.append((p, s.matches, "\(s.runs)", f1(s.strikeRate), s.strikeRate))
            case .economy:
                guard s.ballsBowled >= 24 else { continue }
                rows.append((p, s.matches, "\(s.wickets)", String(format: "%.2f", s.economy), -s.economy))
            case .potm:
                guard s.potm > 0 else { continue }
                rows.append((p, s.matches, "", "\(s.potm)", Double(s.potm)))
            }
        }
        return rows.sorted { $0.4 != $1.4 ? $0.4 > $1.4 : $0.0.id < $1.0.id }.map { ($0.0, $0.1, $0.2, $0.3) }
    }
}

/// Career › Squad › Development: young players and academy prospects, rating at the season start,
/// now, the trend and the potential range.
struct DevelopmentReportView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        if let c = store.career {
            let list = c.developmentWatch
            VStack(alignment: .leading, spacing: DS.Space.md) {
                HStack {
                    Text("Player").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Start").frame(width: 46)
                    Text("Now").frame(width: 46)
                    Text("").frame(width: 24)
                    Text("Potential").frame(width: 76, alignment: .trailing)
                }
                .font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                .padding(.horizontal, 16)
                VStack(spacing: 0) {
                    if list.isEmpty {
                        Text("No players aged 23 or under. Sign some, or promote from the academy.")
                            .font(.subheadline).foregroundStyle(.secondary).padding(16)
                    }
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, p in
                        if i > 0 { Hairline(inset: 16) }
                        let delta = c.seasonProgress(p) ?? 0
                        NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(.display(15, weight: .semibold)).lineLimit(1)
                                    Text("\(p.age(in: c.year)) · \(p.role.short)\(p.academyOf != nil ? " · academy" : "")")
                                        .font(.caption).foregroundStyle(Palette.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(p.seasonStartRating.map { "\($0)" } ?? "–").font(.score(15)).foregroundStyle(Palette.muted).frame(width: 46)
                                Text("\(p.rating)").font(.score(16)).frame(width: 46)
                                Image(systemName: delta > 0 ? "arrow.up" : (delta < 0 ? "arrow.down" : "minus"))
                                    .font(.system(size: 13 * TextScale.factor, weight: .bold))
                                    .foregroundStyle(delta > 0 ? Palette.accent : (delta < 0 ? Palette.wicket : Palette.muted))
                                    .frame(width: 24)
                                Text(c.potentialLabel(p)).font(.score(15)).foregroundStyle(Palette.accent).frame(width: 76, alignment: .trailing)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .gameFrame()
                Text("Young players grow most with training focus and match time. Scouting narrows the potential range.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }
}
