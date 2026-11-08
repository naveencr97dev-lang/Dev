import SwiftUI

struct SquadsView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    /// true right after the auction (shows "Start Season"); false when browsing from elsewhere.
    let preseason: Bool
    @State private var confirmQuit = false

    var body: some View {
        List {
            if let g = store.game {
                if preseason {
                    Section {
                        Text("Auction complete! Check your squad and set your Playing XI. The computer has auto-picked a balanced XI for every team.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Palette.card)
                }
                Section("Franchises") {
                    ForEach(g.teams.sorted { ($0.isCPU ? 1 : 0, $0.id) < ($1.isCPU ? 1 : 0, $1.id) }) { t in
                        NavigationLink {
                            TeamDetailView(teamId: t.id)
                        } label: {
                            HStack(spacing: 12) {
                                TeamBadge(team: t, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.name).font(.headline)
                                    Text("\(t.squad.count) players · \(Money.format(t.purse)) left · \(t.isCPU ? "CPU" : "Human")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(strength(t)).font(.display(18)).foregroundStyle(Palette.gold)
                            }
                        }
                    }
                }
                .listRowBackground(Palette.card)

                let top = topBuys(g)
                if !top.isEmpty {
                    Section("Biggest buys") {
                        ForEach(top) { buy in
                            if let p = store.player(buy.id), let t = g.team(buy.teamId) {
                                HStack {
                                    TeamBadge(team: t, size: 26)
                                    Text(p.name)
                                    Spacer()
                                    Text(Money.format(buy.price)).font(.subheadline.monospacedDigit().weight(.semibold))
                                }
                            }
                        }
                    }
                    .listRowBackground(Palette.card)
                }

                if preseason {
                    Section {
                        Button("Start Season 🏏") { store.startSeason() }
                            .buttonStyle(PrimaryButtonStyle())
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    } footer: {
                        Text("\(g.teams.count * (g.teams.count - 1) / 2 * (g.rules.doubleRoundRobin ? 2 : 1)) league matches, then playoffs.")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Squads")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if preseason {
                    Menu { QuitMenuItem(confirm: $confirmQuit) } label: { Image(systemName: "ellipsis.circle") }
                } else {
                    Button("Done") { dismiss() }
                }
            }
        }
        .quitConfirmation($confirmQuit, store: store)
    }

    /// Team strength = average rating of the XI's best skill.
    private func strength(_ t: Franchise) -> String {
        let xi = t.xi.compactMap { store.player($0) }
        guard !xi.isEmpty else { return "–" }
        let v = xi.map { max($0.bat, $0.bowl) }.reduce(0, +) / xi.count
        return "\(v)"
    }

    struct Buy: Identifiable {
        let id: String
        let price: Int
        let teamId: Int
    }

    private func topBuys(_ g: GameState) -> [Buy] {
        let all = g.teams.flatMap { t in t.paid.map { Buy(id: $0.key, price: $0.value, teamId: t.id) } }
        return Array(all.sorted { $0.price > $1.price }.prefix(5))
    }
}

struct TeamDetailView: View {
    @EnvironmentObject var store: GameStore
    let teamId: Int

    var body: some View {
        List {
            if let g = store.game, let t = g.team(teamId) {
                Section {
                    HStack(spacing: 14) {
                        TeamBadge(team: t, size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t.name).font(.display(22))
                            Text("Spent \(Money.format(g.rules.purse - t.purse)) · \(Money.format(t.purse)) left")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("\(t.squad.count) players · \(AuctionEngine.overseasCount(t, players: store.book.byId)) overseas")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Palette.card)

                if !t.xi.isEmpty {
                    Section {
                        if g.phase == .squads || g.phase == .season {
                            NavigationLink { PickXIView(teamId: teamId) } label: {
                                Label("Edit Playing XI", systemImage: "pencil.circle.fill").foregroundStyle(Palette.gold)
                            }
                        }
                        ForEach(Array(t.xi.enumerated()), id: \.element) { i, pid in
                            if let p = store.player(pid) {
                                HStack(spacing: 10) {
                                    Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 18)
                                    PlayerRow(player: p, price: t.paid[pid])
                                }
                            }
                        }
                    } header: {
                        Text("Playing XI · batting order")
                    }
                    .listRowBackground(Palette.card)
                }

                let bench = t.squad.filter { !t.xi.contains($0) }
                if !bench.isEmpty {
                    Section(t.xi.isEmpty ? "Squad" : "Bench") {
                        ForEach(bench, id: \.self) { pid in
                            if let p = store.player(pid) { PlayerRow(player: p, price: t.paid[pid]) }
                        }
                    }
                    .listRowBackground(Palette.card)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle(store.team(teamId)?.short ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PickXIView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let teamId: Int
    @State private var selected: Set<String> = []

    var body: some View {
        let g = store.game
        let team = g?.team(teamId)
        let rules = g?.rules ?? Rules()
        let squad = (team?.squad ?? []).compactMap { store.player($0) }
            .sorted { max($0.bat, $0.bowl) > max($1.bat, $1.bowl) }
        let picked = squad.filter { selected.contains($0.id) }
        let issues = TeamSelector.blockingIssues(picked, rules: rules)
        let warnings = TeamSelector.warnings(picked)

        List {
            Section {
                HStack(spacing: 16) {
                    counter("\(picked.count)/11", "players", picked.count == 11)
                    counter("\(picked.filter(\.overseas).count)/\(rules.maxOverseasXI)", "overseas", picked.filter(\.overseas).count <= rules.maxOverseasXI)
                    counter("\(picked.filter(\.isBowlingOption).count)", "bowlers", picked.filter(\.isBowlingOption).count >= 5)
                    counter("\(picked.filter { $0.role == .WK }.count)", "keeper", picked.contains { $0.role == .WK })
                }
                ForEach(issues + warnings, id: \.self) { Text("• \($0)").font(.footnote).foregroundStyle(issues.contains($0) ? Color.red : Color.orange) }
                Button("Auto-pick best XI") {
                    selected = Set(TeamSelector.autoXI(squad: squad, rules: rules))
                    Haptics.tap()
                }
            }
            .listRowBackground(Palette.card)

            Section("Squad — tap to select") {
                ForEach(squad) { p in
                    Button {
                        if selected.contains(p.id) { selected.remove(p.id) } else { selected.insert(p.id) }
                        Haptics.tap()
                    } label: {
                        HStack {
                            Image(systemName: selected.contains(p.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(p.id) ? Palette.gold : .secondary)
                                .font(.title3)
                            PlayerRow(player: p)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(Palette.card)
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Playing XI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    let order = TeamSelector.battingOrder(picked).map(\.id)
                    store.setXI(teamId: teamId, ids: order)
                    Haptics.success()
                    dismiss()
                }
                .disabled(!issues.isEmpty)
            }
        }
        .onAppear {
            if selected.isEmpty { selected = Set(team?.xi ?? []) }
        }
    }

    private func counter(_ value: String, _ label: String, _ ok: Bool) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.display(18)).foregroundStyle(ok ? Palette.four : .orange)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
