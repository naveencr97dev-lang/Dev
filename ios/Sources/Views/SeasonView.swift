import SwiftUI

enum Route: Hashable {
    case match(Int)
    case result(UUID)
    case team(Int)
}

struct SeasonView: View {
    @EnvironmentObject var store: GameStore
    @State private var tab = 0
    @State private var path: [Route] = []
    @State private var showSquads = false
    @State private var confirmQuit = false
    @State private var simNote: String? = nil

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("View", selection: $tab) {
                    Text("Matches").tag(0)
                    Text("Table").tag(1)
                    Text("Stats").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DS.Space.lg)
                .padding(.vertical, DS.Space.sm)

                ScrollView {
                    Group {
                        switch tab {
                        case 0: matches
                        case 1: PointsTableView()
                        default: StatsView()
                        }
                    }
                    .padding(DS.Space.lg)
                }
            }
            .background(AppBackground())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .match(let id): MatchView(fixtureId: id)
                case .result(let id): ResultScreen(resultId: id)
                case .team(let id): TeamDetailView(teamId: id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showSquads = true } label: { Label("Squads & Playing XI", systemImage: "person.3") }
                        QuitMenuItem(confirm: $confirmQuit)
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $showSquads) {
                NavigationStack { SquadsView(preseason: false) }
                    .environmentObject(store)
            }
            .quitConfirmation($confirmQuit, store: store)
        }
    }

    private var title: String {
        guard let g = store.game else { return "Season" }
        if let f = g.nextFixture, f.stage != .league { return "Playoffs" }
        if g.championId != nil { return "Season over" }
        return "League · \(g.leagueResults.count)/\(g.leagueFixtureCount)"
    }

    // MARK: Matches tab

    @ViewBuilder private var matches: some View {
        if let g = store.game {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                if let f = g.nextFixture {
                    NextMatchCard(fixture: f, number: matchNumber(g, f)) {
                        path.append(.match(f.id))
                    } quick: {
                        if let r = store.play(fixtureId: f.id) { path.append(.result(r.id)) }
                    }
                    if !g.isHumanFixture(f) {
                        Button {
                            let n = store.simCPUMatches()
                            simNote = "Simulated \(n) CPU match\(n == 1 ? "" : "es") — results below."
                            Haptics.tap()
                        } label: {
                            Label("Sim CPU matches until a human team plays", systemImage: "forward.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                } else if let champ = g.championId.flatMap({ g.team($0) }) {
                    AppCard(tint: Color(hex: champ.colorHex)) {
                        VStack(alignment: .leading, spacing: DS.Space.md) {
                            Text("🏆 \(champ.name) are the champions!").font(.display(22))
                            Button("Trophy ceremony") { store.finishSeason() }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                }
                if let simNote {
                    Text(simNote).font(.footnote).foregroundStyle(.secondary)
                }

                if g.fixtures.contains(where: { $0.stage != .league }) {
                    PlayoffBracket(onOpen: { path.append(.result($0)) })
                }

                if !g.results.isEmpty {
                    SectionLabel(text: "Results")
                    VStack(spacing: DS.Space.sm) {
                        ForEach(g.results.reversed()) { r in
                            Button { path.append(.result(r.id)) } label: { ResultRow(result: r) }
                                .buttonStyle(.plain)
                        }
                    }
                } else {
                    Text("Tip: open ••• → Squads & Playing XI to change your line-up between matches.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func matchNumber(_ g: GameState, _ f: Fixture) -> String {
        if f.stage != .league { return f.stage.label }
        let i = g.fixtures.firstIndex(where: { $0.id == f.id }).map { $0 + 1 } ?? 0
        return "Match \(i) of \(g.leagueFixtureCount)"
    }
}

struct NextMatchCard: View {
    @EnvironmentObject var store: GameStore
    let fixture: Fixture
    let number: String
    let play: () -> Void
    let quick: () -> Void

    var body: some View {
        AppCard(tint: fixture.stage == .final ? Palette.gold : nil) {
            VStack(spacing: DS.Space.md) {
                Text(number.uppercased()).font(.caption.weight(.heavy)).foregroundStyle(Palette.gold)
                HStack {
                    side(fixture.home)
                    Text("vs").font(.display(18)).foregroundStyle(.secondary)
                    side(fixture.away)
                }
                Button("Play match ▶︎", action: play).buttonStyle(PrimaryButtonStyle())
                Button("Just show the result", action: quick).font(.subheadline.weight(.semibold))
            }
        }
    }

    private func side(_ id: Int) -> some View {
        VStack(spacing: 6) {
            if let t = store.team(id) {
                TeamBadge(team: t, size: 58)
                Text(t.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2)
                Text(t.isCPU ? "CPU" : "Human").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ResultRow: View {
    @EnvironmentObject var store: GameStore
    let result: MatchResult

    var body: some View {
        AppCard(padding: DS.Space.md) {
            VStack(alignment: .leading, spacing: 6) {
                if result.stage != .league {
                    Text(result.stage.label.uppercased()).font(.caption2.weight(.heavy)).foregroundStyle(Palette.gold)
                }
                ForEach(result.innings.prefix(2), id: \.teamId) { inn in
                    if let t = store.team(inn.teamId) {
                        HStack {
                            TeamBadge(team: t, size: 24)
                            Text(t.name).font(.subheadline.weight(inn.teamId == result.winnerId ? .bold : .regular))
                            Spacer()
                            Text("\(inn.score) (\(inn.overs))").font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                    }
                }
                if let w = store.team(result.winnerId) {
                    Text("\(w.short) \(result.margin)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct PlayoffBracket: View {
    @EnvironmentObject var store: GameStore
    let onOpen: (UUID) -> Void

    var body: some View {
        if let g = store.game {
            let stages: [Stage] = g.teams.count < 4 ? [.final] : [.qualifier1, .eliminator, .qualifier2, .final]
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionLabel(text: "Playoffs")
                AppCard(padding: DS.Space.md) {
                    VStack(spacing: 10) {
                        ForEach(stages, id: \.self) { stage in
                            row(g, stage)
                        }
                    }
                }
            }
        }
    }

    private func row(_ g: GameState, _ stage: Stage) -> some View {
        let f = g.fixtures.first { $0.stage == stage }
        let r = g.result(f?.resultId)
        return Button {
            if let r { onOpen(r.id) }
        } label: {
            HStack {
                Text(stage.label).font(.caption.weight(.bold)).frame(width: 86, alignment: .leading)
                    .foregroundStyle(stage == .final ? Palette.gold : .primary)
                if let f, let a = g.team(f.home), let b = g.team(f.away) {
                    Text(a.short).fontWeight(r?.winnerId == a.id ? Font.Weight.heavy : Font.Weight.regular)
                    Text("v").foregroundStyle(.secondary)
                    Text(b.short).fontWeight(r?.winnerId == b.id ? Font.Weight.heavy : Font.Weight.regular)
                    Spacer()
                    if let r, let w = g.team(r.winnerId) {
                        Text("\(w.short) won").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Upcoming").font(.caption).foregroundStyle(.secondary)
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

struct PointsTableView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        if let g = store.game {
            let table = g.table
            let cutoff = g.teams.count < 4 ? 2 : 4
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
                        if let t = g.team(row.teamId) {
                            HStack {
                                Text("\(i + 1)").frame(width: 18, alignment: .leading).foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    TeamBadge(team: t, size: 24)
                                    Text(t.short).fontWeight(.semibold)
                                    if !t.isCPU { Image(systemName: "person.fill").font(.caption2).foregroundStyle(Palette.gold) }
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
                            if i == cutoff - 1 && table.count > cutoff {
                                Rectangle().fill(Palette.gold.opacity(0.5)).frame(height: 1)
                            }
                        }
                    }
                }
            }
            Text("Top \(cutoff) qualify for the playoffs. Ties are split by net run rate.")
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DS.Space.sm)
        }
    }
}

struct StatsView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        if let g = store.game {
            let stats = Array(SeasonEngine.playerStats(results: g.results).values)
            if stats.isEmpty {
                Text("Play a match to see the leaderboards.").foregroundStyle(.secondary)
            } else {
                VStack(spacing: DS.Space.lg) {
                    board("🟠 Orange Cap · most runs", stats.filter { $0.runs > 0 }.sorted { $0.runs > $1.runs }.prefix(5)) { s in
                        "\(s.runs) runs · SR \(s.ballsFaced == 0 ? 0 : s.runs * 100 / s.ballsFaced)"
                    }
                    board("🟣 Purple Cap · most wickets", stats.filter { $0.wickets > 0 }.sorted { ($0.wickets, -$0.economy) > ($1.wickets, -$1.economy) }.prefix(5)) { s in
                        "\(s.wickets) wkts · econ \(String(format: "%.1f", s.economy))"
                    }
                    board("💥 Most sixes", stats.filter { $0.sixes > 0 }.sorted { $0.sixes > $1.sixes }.prefix(3)) { s in
                        "\(s.sixes) sixes"
                    }
                    board("⭐ MVP race", stats.sorted { $0.mvpPoints > $1.mvpPoints }.prefix(5)) { s in
                        "\(Int(s.mvpPoints)) pts"
                    }
                }
            }
        }
    }

    private func board(_ title: String, _ rows: ArraySlice<PlayerSeason>, stat: @escaping (PlayerSeason) -> String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text(title).font(.headline)
            AppCard(padding: DS.Space.md) {
                VStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, s in
                        HStack(spacing: 10) {
                            Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 14)
                            if let t = store.team(s.teamId) { TeamBadge(team: t, size: 24) }
                            Text(store.player(s.id)?.name ?? s.id).font(.subheadline.weight(i == 0 ? .bold : .regular)).lineLimit(1)
                            Spacer()
                            Text(stat(s)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
