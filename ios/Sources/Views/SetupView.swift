import SwiftUI

struct SetupView: View {
    @EnvironmentObject var store: GameStore
    @State private var teams: [Franchise] = []
    @State private var rules = Rules()

    private var humans: Int { teams.filter { !$0.isCPU }.count }
    private var problems: [String] {
        var p: [String] = []
        if teams.count < 3 { p.append("Add at least 3 franchises.") }
        if humans == 0 { p.append("At least one franchise must be a human player.") }
        if teams.contains(where: { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }) { p.append("Every franchise needs a name.") }
        return p
    }

    var body: some View {
        Form {
            Section {
                ForEach($teams) { $team in
                    TeamSetupRow(team: $team)
                }
                .onDelete { teams.remove(atOffsets: $0) }
                if teams.count < 10 {
                    Button { addTeam() } label: { Label("Add franchise", systemImage: "plus.circle.fill") }
                }
            } header: {
                Text("Franchises · \(humans) human · \(teams.count - humans) CPU")
            } footer: {
                Text("3–10 franchises. Tap 👤/🤖 to switch a team between a player and the computer, tap the badge to change colour, swipe to remove.")
            }

            Section("Rules") {
                Picker("Purse", selection: $rules.purse) {
                    Text("₹80 Cr").tag(8000)
                    Text("₹100 Cr").tag(10_000)
                    Text("₹120 Cr").tag(12_000)
                }
                Picker("Auction", selection: $rules.poolSize) {
                    Text("Quick").tag(PoolSize.quick)
                    Text("Full · 273 players").tag(PoolSize.full)
                }
                Picker("Bid timer", selection: $rules.bidSeconds) {
                    Text("5 s").tag(5.0)
                    Text("8 s").tag(8.0)
                    Text("12 s").tag(12.0)
                }
                Toggle("Play each team twice", isOn: $rules.doubleRoundRobin)
            }

            Section {
                ForEach(problems, id: \.self) { Text($0).foregroundStyle(.orange) }
                Button("Start Auction") { store.startAuction(teams: teams, rules: rules) }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!problems.isEmpty)
                    .opacity(problems.isEmpty ? 1 : 0.4)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            } footer: {
                Text("Squads: 11–18 players, max 8 overseas (4 in the XI).")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("New Game")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { store.reset() } }
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
        }
        .onAppear {
            if teams.isEmpty, let g = store.game {
                teams = g.teams
                rules = g.rules
            }
        }
    }

    private func addTeam() {
        let used = Set(teams.map(\.name))
        let template = FranchiseTemplate.all.first { !used.contains($0.name) } ?? FranchiseTemplate.all[0]
        let nextId = (teams.map(\.id).max() ?? -1) + 1
        teams.append(Franchise(id: nextId, name: template.name, short: template.short,
                               colorHex: template.color, isCPU: true))
    }
}

struct TeamSetupRow: View {
    @Binding var team: Franchise

    var body: some View {
        HStack(spacing: 10) {
            Button {
                // Tap the badge to cycle through team colours.
                let colors = Palette.teamColors
                let i = colors.firstIndex(of: team.colorHex) ?? -1
                team.colorHex = colors[(i + 1) % colors.count]
                Haptics.tap()
            } label: {
                TeamBadge(team: team, size: 38)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                TextField("Team name", text: $team.name)
                    .font(.body.weight(.semibold))
                TextField("ABC", text: $team.short)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textInputAutocapitalization(.characters)
                    .onChange(of: team.short) { v in
                        let clean = String(v.uppercased().prefix(4))
                        if clean != v { team.short = clean }
                    }
            }
            Spacer()
            Button {
                team.isCPU.toggle()
                Haptics.tap()
            } label: {
                Text(team.isCPU ? "🤖 CPU" : "👤 Human")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(team.isCPU ? Color.white.opacity(0.1) : Palette.gold.opacity(0.25)))
            }
            .buttonStyle(.plain)
        }
    }
}
