import SwiftUI

/// Career home: tabs for the manager's desk, squad, fixtures, table and club.
struct CareerHubView: View {
    @EnvironmentObject var store: GameStore
    @State private var tab = 0
    @State private var path: [Route] = []
    @State private var note: String? = nil
    @State private var confirmSimSeason = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("View", selection: $tab) {
                    Text("Home").tag(0)
                    Text("Squad").tag(1)
                    Text("Fixtures").tag(2)
                    Text("Table").tag(3)
                    Text("Club").tag(4)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DS.Space.lg)
                .padding(.vertical, DS.Space.sm)

                ScrollView {
                    Group {
                        switch tab {
                        case 0: CareerHomeTab(path: $path, note: $note)
                        case 1: CareerSquadTab()
                        case 2: CareerFixturesTab(path: $path)
                        case 3: CareerTableTab(path: $path)
                        default: CareerClubTab(path: $path)
                        }
                    }
                    .padding(DS.Space.lg)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(AppBackground())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .match(let id): MatchView(fixtureId: id)
                case .result(let id): ResultScreen(resultId: id)
                case .highlights(let id): ResultScreen(resultId: id, autoplay: true)
                case .team(let id): CareerClubView(clubId: id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if store.career?.phase == .season {
                            Button { confirmSimSeason = true } label: {
                                Label("Quick-sim rest of season", systemImage: "forward.end.fill")
                            }
                        }
                        Button { store.exitCareer() } label: {
                            Label("Main menu", systemImage: "house")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog("Simulate every remaining match, yours included?", isPresented: $confirmSimSeason,
                                titleVisibility: .visible) {
                Button("Sim to season end") {
                    store.careerSimToSeasonEnd()
                    tab = 0
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var title: String {
        guard let c = store.career else { return "Career" }
        return "\(c.userClub.short) · \(c.year) · \(CareerCalendar.label(c.currentDay))"
    }
}

enum CareerText {
    static func fixtureLabel(_ c: Career, _ f: Fixture) -> String {
        let date = CareerCalendar.label(c.day(of: f))
        if let r = c.round(of: f) { return "Round \(r) of \(c.totalRounds) · \(date)" }
        return "\(f.stage.label) · \(date)"
    }

    static func form(_ v: Int) -> String { v > 0 ? "+\(v)" : "\(v)" }

    static func formColor(_ v: Int) -> Color {
        v >= 3 ? Palette.accent : (v <= -3 ? Palette.wicket : Palette.muted)
    }

    static func rollover(_ r: Career.RolloverReport) -> String {
        var parts = ["New season! \(r.retired.count) retirements, \(r.youth) youngsters entered the pool."]
        if !r.userRetired.isEmpty { parts.append("Retired from your squad: \(r.userRetired.joined(separator: ", ")).") }
        if !r.signed.isEmpty { parts.append("Signed to fill your squad: \(r.signed.joined(separator: ", ")).") }
        if !r.bigRisers.isEmpty { parts.append("Big improvers: \(r.bigRisers.joined(separator: ", ")).") }
        return parts.joined(separator: " ")
    }
}

// MARK: - Home

struct CareerHomeTab: View {
    @EnvironmentObject var store: GameStore
    @Binding var path: [Route]
    @Binding var note: String?

    var body: some View {
        if let c = store.career {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                ClubHeaderCard(career: c)

                if c.phase == .seasonEnd {
                    SeasonEndCard(career: c) {
                        let report = store.careerStartNextSeason()
                        note = CareerText.rollover(report)
                        Haptics.success()
                    }
                } else if let f = c.nextFixture {
                    if c.isUserFixture(f) {
                        NextMatchCard(fixture: f, number: CareerText.fixtureLabel(c, f)) {
                            path.append(.match(f.id))
                        } quick: {
                            if let r = store.play(fixtureId: f.id) { path.append(.result(r.id)) }
                        }
                    } else if let mine = c.nextUserFixture {
                        UpcomingCard(career: c, fixture: mine) {
                            let n = store.careerSimUntilUserMatch()
                            note = "Simulated \(n) other match\(n == 1 ? "" : "es") around the league."
                            Haptics.tap()
                        }
                    } else {
                        Text("You're out of the playoffs. Watch the rest, or sim to the end of the season.")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                        NextMatchCard(fixture: f, number: CareerText.fixtureLabel(c, f)) {
                            path.append(.match(f.id))
                        } quick: {
                            if let r = store.play(fixtureId: f.id) { path.append(.result(r.id)) }
                        }
                        Button("Sim to season end") { store.careerSimToSeasonEnd() }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }

                if let note {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }

                let mine = c.results.filter { $0.teamA == c.userClubId || $0.teamB == c.userClubId }.suffix(3).reversed()
                if !mine.isEmpty {
                    SectionLabel(text: "Your recent results")
                    VStack(spacing: DS.Space.sm) {
                        ForEach(Array(mine), id: \.id) { r in
                            Button { path.append(.result(r.id)) } label: { ResultRow(result: r) }
                                .buttonStyle(.plain)
                        }
                    }
                }

                NewsFeed(news: Array(c.news.prefix(12)))
            }
        }
    }
}

struct ClubHeaderCard: View {
    let career: Career

    var body: some View {
        let c = career
        let club = c.userClub
        let row = c.table.first { $0.teamId == c.userClubId }
        AppCard(tint: Color(hex: club.colorHex)) {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(spacing: 12) {
                    TeamBadge(team: club, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(club.name.uppercased()).font(.display(24))
                        Text("Manager \(c.managerName) · Season \(c.year)").font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 0) {
                    stat(Career.ordinal(c.position(of: c.userClubId)), "POSITION")
                    stat("\(row?.points ?? 0)", "POINTS")
                    stat("\(row?.won ?? 0)-\(row?.lost ?? 0)", "W-L")
                    stat("\(c.strength(c.userClubId))", "STRENGTH")
                }
                HStack(spacing: 6) {
                    Text("FORM").font(.display(12, weight: .heavy)).foregroundStyle(Palette.muted)
                    let form = c.userForm()
                    if form.isEmpty {
                        Text("No matches yet").font(.caption).foregroundStyle(Palette.muted)
                    }
                    ForEach(Array(form.enumerated()), id: \.offset) { _, won in
                        Text(won ? "W" : "L")
                            .font(.display(13, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 5).fill(won ? Palette.accent : Palette.wicket))
                    }
                    Spacer()
                    Text("\(c.leaguePlayed)/\(c.leagueFixtures.count) played").font(.caption2).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.display(24)).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.display(10, weight: .heavy)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The user's next match when other games come first.
struct UpcomingCard: View {
    let career: Career
    let fixture: Fixture
    let onContinue: () -> Void

    var body: some View {
        let c = career
        let oppId = fixture.home == c.userClubId ? fixture.away : fixture.home
        let home = fixture.home == c.userClubId
        AppCard {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                Text("NEXT · \(CareerText.fixtureLabel(c, fixture).uppercased())")
                    .font(.display(15, weight: .heavy)).foregroundStyle(Palette.accent)
                if let opp = c.club(oppId) {
                    HStack(spacing: 10) {
                        TeamBadge(team: opp, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(home ? "vs" : "at") \(opp.name)").font(.headline)
                            Text("\(fixture.pitch.icon) \(fixture.pitch.label) · \(Career.ordinal(c.position(of: oppId))) in the table")
                                .font(.caption).foregroundStyle(Palette.muted)
                        }
                    }
                }
                Button("Continue ▶︎", action: onContinue).buttonStyle(PrimaryButtonStyle())
                Text("Plays the other clubs' matches up to yours.").font(.caption2).foregroundStyle(Palette.muted)
            }
        }
    }
}

struct SeasonEndCard: View {
    let career: Career
    let onNext: () -> Void

    var body: some View {
        let c = career
        let record = c.history.last
        AppCard(tint: Palette.accent) {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                if let champ = c.championId.flatMap({ c.club($0) }) {
                    HStack(spacing: 12) {
                        TeamBadge(team: champ, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(c.year) CHAMPIONS").font(.display(14, weight: .heavy)).foregroundStyle(Palette.accent)
                            Text(champ.name.uppercased()).font(.display(24))
                        }
                    }
                }
                if let record {
                    Text("Your season: \(record.userFinish)").font(.headline)
                    VStack(alignment: .leading, spacing: 4) {
                        if let a = record.orangeCap { Text("🟠 Orange Cap: \(a.name) — \(a.value)") }
                        if let a = record.purpleCap { Text("🟣 Purple Cap: \(a.name) — \(a.value)") }
                        if let a = record.mvp { Text("⭐ MVP: \(a.name) — \(a.value)") }
                    }
                    .font(.subheadline)
                }
                Button("Start \(c.year + 1) season ▶︎", action: onNext).buttonStyle(PrimaryButtonStyle())
                Text("Players age a year, develop or decline, veterans retire and a youth intake joins the pool.")
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
        }
    }
}

struct NewsFeed: View {
    let news: [NewsItem]

    var body: some View {
        if !news.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionLabel(text: "News")
                AppCard(padding: DS.Space.md) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(news) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Text(icon(item.kind)).font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.text).font(.subheadline)
                                    Text("\(CareerCalendar.label(item.day)) \(String(item.year))")
                                        .font(.caption2).foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func icon(_ k: NewsItem.Kind) -> String {
        switch k {
        case .result: return "🏏"
        case .milestone: return "⭐"
        case .squad: return "👥"
        case .season: return "🏆"
        case .info: return "📰"
        }
    }
}

// MARK: - Fixtures

struct CareerFixturesTab: View {
    @EnvironmentObject var store: GameStore
    @Binding var path: [Route]
    @State private var showAll = false

    var body: some View {
        if let c = store.career {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Picker("Show", selection: $showAll) {
                    Text("Your matches").tag(false)
                    Text("League results").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, DS.Space.sm)

                if showAll {
                    let others = Array(c.results.reversed().prefix(40))
                    if others.isEmpty {
                        Text("No results yet.").foregroundStyle(.secondary)
                    }
                    ForEach(others, id: \.id) { r in
                        Button { path.append(.result(r.id)) } label: { ResultRow(result: r) }
                            .buttonStyle(.plain)
                    }
                } else {
                    ForEach(c.userFixtures) { f in
                        Button {
                            if let r = c.result(f.resultId) { path.append(.result(r.id)) }
                        } label: {
                            FixtureRow(career: c, fixture: f)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct FixtureRow: View {
    let career: Career
    let fixture: Fixture

    var body: some View {
        let c = career
        let oppId = fixture.home == c.userClubId ? fixture.away : fixture.home
        let r = c.result(fixture.resultId)
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(CareerCalendar.label(c.day(of: fixture))).font(.score(15))
                Text(c.round(of: fixture).map { "R\($0)" } ?? fixture.stage.label)
                    .font(.caption2).foregroundStyle(Palette.muted).lineLimit(1)
            }
            .frame(width: 70, alignment: .leading)
            if let opp = c.club(oppId) {
                TeamBadge(team: opp, size: 28)
                Text("\(fixture.home == c.userClubId ? "vs" : "at") \(opp.short)").font(.subheadline.weight(.semibold))
            }
            Text(fixture.pitch.icon).font(.caption)
            Spacer()
            if let r {
                let won = r.winnerId == c.userClubId
                Text(won ? "W" : "L")
                    .font(.display(14, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(won ? Palette.accent : Palette.wicket))
                Text(scoreLine(r)).font(.score(13, weight: .regular)).foregroundStyle(Palette.muted)
            } else {
                Text("Upcoming").font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, DS.Space.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surface))
    }

    private func scoreLine(_ r: MatchResult) -> String {
        r.innings.prefix(2).map(\.score).joined(separator: " · ")
    }
}

// MARK: - Table

struct CareerTableTab: View {
    @EnvironmentObject var store: GameStore
    @Binding var path: [Route]

    var body: some View {
        if let c = store.career {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                if c.fixtures.contains(where: { $0.stage != .league }) {
                    CareerPlayoffs(career: c) { path.append(.result($0)) }
                }
                CareerPointsTable(career: c) { path.append(.team($0)) }
                CareerLeaders(career: c)
            }
        }
    }
}

struct CareerPointsTable: View {
    let career: Career
    let onOpen: (Int) -> Void

    var body: some View {
        let c = career
        let table = c.table
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Points table")
            AppCard(padding: DS.Space.md) {
                VStack(spacing: 10) {
                    HStack {
                        Text("#").frame(width: 18, alignment: .leading)
                        Text("Team").frame(maxWidth: .infinity, alignment: .leading)
                        Text("P").frame(width: 24)
                        Text("W").frame(width: 24)
                        Text("L").frame(width: 24)
                        Text("Pts").frame(width: 32)
                        Text("NRR").frame(width: 52, alignment: .trailing)
                    }
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(Array(table.enumerated()), id: \.element.teamId) { i, row in
                        if let t = c.club(row.teamId) {
                            Button { onOpen(t.id) } label: {
                                HStack {
                                    Text("\(i + 1)").frame(width: 18, alignment: .leading).foregroundStyle(.secondary)
                                    HStack(spacing: 8) {
                                        TeamBadge(team: t, size: 24)
                                        Text(t.short).fontWeight(.semibold)
                                        if !t.isCPU { Image(systemName: "person.fill").font(.caption2).foregroundStyle(Palette.accent) }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(row.played)").frame(width: 24)
                                    Text("\(row.won)").frame(width: 24)
                                    Text("\(row.lost)").frame(width: 24)
                                    Text("\(row.points)").fontWeight(.heavy).frame(width: 32)
                                    Text(String(format: "%+.2f", row.nrr)).frame(width: 52, alignment: .trailing)
                                        .foregroundStyle(row.nrr >= 0 ? Palette.four : Palette.wicket)
                                }
                                .font(.subheadline.monospacedDigit())
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if i == 3 {
                                Rectangle().fill(Palette.accent.opacity(0.5)).frame(height: 1)
                            }
                        }
                    }
                }
            }
            Text("Top 4 reach the playoffs. Tap a club to see its squad.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct CareerPlayoffs: View {
    let career: Career
    let onOpen: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Playoffs")
            AppCard(padding: DS.Space.md) {
                VStack(spacing: 10) {
                    ForEach([Stage.qualifier1, .eliminator, .qualifier2, .final], id: \.self) { stage in
                        row(stage)
                    }
                }
            }
        }
    }

    private func row(_ stage: Stage) -> some View {
        let c = career
        let f = c.fixtures.first { $0.stage == stage }
        let r = c.result(f?.resultId)
        return Button {
            if let r { onOpen(r.id) }
        } label: {
            HStack {
                Text(stage.label).font(.caption.weight(.bold)).frame(width: 86, alignment: .leading)
                    .foregroundStyle(stage == .final ? Palette.accent : .primary)
                if let f, let a = c.club(f.home), let b = c.club(f.away) {
                    Text(a.short).fontWeight(r?.winnerId == a.id ? Font.Weight.heavy : Font.Weight.regular)
                    Text("v").foregroundStyle(.secondary)
                    Text(b.short).fontWeight(r?.winnerId == b.id ? Font.Weight.heavy : Font.Weight.regular)
                    Spacer()
                    if let r, let w = c.club(r.winnerId) {
                        Text("\(w.short) won").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(CareerCalendar.label(c.day(of: f))).font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("TBD").foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .font(.subheadline)
        }
        .buttonStyle(.plain)
    }
}

struct CareerLeaders: View {
    let career: Career

    var body: some View {
        let stats = Array(SeasonEngine.playerStats(results: career.results).values)
        if !stats.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                board("🟠 Orange Cap", Array(stats.filter { $0.runs > 0 }.sorted { $0.runs > $1.runs }.prefix(5))) { s in
                    "\(s.runs) runs · SR \(s.ballsFaced == 0 ? 0 : s.runs * 100 / s.ballsFaced)"
                }
                board("🟣 Purple Cap", Array(stats.filter { $0.wickets > 0 }.sorted { $0.wickets > $1.wickets }.prefix(5))) { s in
                    "\(s.wickets) wkts · econ \(String(format: "%.1f", s.economy))"
                }
                board("⭐ MVP race", Array(stats.sorted { $0.mvpPoints > $1.mvpPoints }.prefix(5))) { s in
                    "\(Int(s.mvpPoints)) pts"
                }
            }
        }
    }

    private func board(_ title: String, _ rows: [PlayerSeason], stat: @escaping (PlayerSeason) -> String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text(title).font(.headline)
            AppCard(padding: DS.Space.md) {
                VStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, s in
                        HStack(spacing: 10) {
                            Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 14)
                            if let t = career.club(s.teamId) { TeamBadge(team: t, size: 24) }
                            Text(career.players[s.id]?.name ?? s.id).font(.subheadline.weight(i == 0 ? .bold : .regular)).lineLimit(1)
                            Spacer()
                            Text(stat(s)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Club

struct CareerClubTab: View {
    @EnvironmentObject var store: GameStore
    @Binding var path: [Route]

    var body: some View {
        if let c = store.career {
            let club = c.userClub
            let info = c.info(c.userClubId)
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                AppCard(tint: Color(hex: club.colorHex)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(club.name.uppercased()).font(.display(26))
                        if let info {
                            Text("\(info.homePitch.icon) Home ground: \(info.homePitch.label)").font(.subheadline)
                            Text(info.homePitch.blurb).font(.caption).foregroundStyle(Palette.muted)
                            Text("🏆 Titles: \(info.titles)").font(.subheadline)
                        }
                        Text("Manager since \(String(c.startYear)) · \(c.history.count) season\(c.history.count == 1 ? "" : "s") completed")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                }

                SectionLabel(text: "History")
                if c.history.isEmpty {
                    Text("Your first season is under way.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: DS.Space.sm) {
                        ForEach(c.history.reversed()) { h in
                            HistoryRow(career: c, record: h)
                        }
                    }
                }

                SectionLabel(text: "Roll of honour")
                AppCard(padding: DS.Space.md) {
                    VStack(spacing: 8) {
                        ForEach(c.clubInfo.sorted { $0.titles != $1.titles ? $0.titles > $1.titles : $0.id < $1.id }) { i in
                            if let t = c.club(i.id) {
                                Button { path.append(.team(t.id)) } label: {
                                    HStack(spacing: 10) {
                                        TeamBadge(team: t, size: 26)
                                        Text(t.name).font(.subheadline)
                                        Spacer()
                                        Text(i.titles > 0 ? String(repeating: "🏆", count: min(i.titles, 6)) + (i.titles > 6 ? " ×\(i.titles)" : "") : "–")
                                            .font(.caption)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct HistoryRow: View {
    let career: Career
    let record: SeasonRecord

    var body: some View {
        AppCard(padding: DS.Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(String(record.year)).font(.display(22)).foregroundStyle(Palette.accent)
                    Spacer()
                    if let champ = career.club(record.championId) {
                        Text("🏆 \(champ.short)").font(.subheadline.weight(.bold))
                    }
                }
                Text("You: \(record.userFinish) · \(Career.ordinal(record.userPosition)) in the league").font(.subheadline)
                if let a = record.orangeCap { Text("🟠 \(a.name) \(a.value)").font(.caption).foregroundStyle(Palette.muted) }
                if let a = record.purpleCap { Text("🟣 \(a.name) \(a.value)").font(.caption).foregroundStyle(Palette.muted) }
            }
        }
    }
}
