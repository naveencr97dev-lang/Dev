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
                        Text("Auction complete! Every franchise has its XI. Tap a team to see it or change the batting order.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Palette.surface)
                }
                Section("Franchises") {
                    ForEach(g.teams.sorted { ($0.isCPU ? 1 : 0, $0.id) < ($1.isCPU ? 1 : 0, $1.id) }) { t in
                        let needs = AuctionEngine.needs(t, players: store.book.byId)
                        NavigationLink {
                            TeamDetailView(teamId: t.id)
                        } label: {
                            HStack(spacing: 12) {
                                TeamBadge(team: t, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.name).font(.headline)
                                    Text("\(t.squad.count)/\(g.rules.maxSquad) · \(Money.format(t.purse)) left · \(t.isCPU ? "CPU" : "Human")")
                                        .font(.caption).foregroundStyle(.secondary)
                                    if needs.total > 0 {
                                        Text(needs.summary).font(.caption2).foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text(strength(t)).font(.display(22)).foregroundStyle(Palette.accent)
                                    Text("STR").font(.display(10, weight: .heavy)).foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Palette.surface)

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
                    .listRowBackground(Palette.surface)
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
        .darkList()
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
                            Text("\(t.squad.count) players · \(AuctionEngine.overseasCount(t, players: store.book.byId)) overseas · \(AuctionEngine.needs(t, players: store.book.byId).summary)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Palette.surface)

                if !t.xi.isEmpty {
                    Section {
                        if (g.phase == .squads || g.phase == .season) && g.championId == nil {
                            NavigationLink { BattingOrderView(teamId: teamId) } label: {
                                Label("Change batting order", systemImage: "arrow.up.arrow.down.circle.fill").foregroundStyle(Palette.accent)
                            }
                        }
                        ForEach(Array(t.xi.enumerated()), id: \.element) { i, pid in
                            if let p = store.player(pid) {
                                VStack(alignment: .trailing, spacing: 0) {
                                    BattingSlotRow(position: i, player: p)
                                    if let price = t.paid[pid] {
                                        Text("Bought for \(Money.format(price))").font(.caption2).foregroundStyle(Palette.muted)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Playing XI · batting order")
                    }
                    .listRowBackground(Palette.surface)
                }

                let bench = t.squad.filter { !t.xi.contains($0) }
                if !bench.isEmpty {
                    Section(t.xi.isEmpty ? "Squad" : "Bench") {
                        ForEach(bench, id: \.self) { pid in
                            if let p = store.player(pid) { PlayerRow(player: p, price: t.paid[pid]) }
                        }
                    }
                    .listRowBackground(Palette.surface)
                }
            }
        }
        .darkList()
        .navigationTitle(store.team(teamId)?.short ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BattingOrderView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let teamId: Int
    @State private var order: [String] = []

    var body: some View {
        let players = order.compactMap { store.player($0) }
        List {
            Section {
                LineupSummary(players: players)
            }
            .listRowBackground(Palette.surface)
            Section {
                ForEach(Array(order.enumerated()), id: \.element) { i, pid in
                    if let p = store.player(pid) {
                        BattingSlotRow(position: i, player: p)
                    }
                }
                .onMove { order.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("Drag ≡ to reorder. Big number = batting strength. ✓ means the player's trait suits that slot (e.g. 🚀 Powerplay Blitz opening, 🏁 Finisher at 5–7). Your five best bowlers for the pitch bowl automatically.")
            }
            .listRowBackground(Palette.surface)
            Section {
                Button("Reset to best order") {
                    order = TeamSelector.battingOrder(order.compactMap { store.player($0) }).map(\.id)
                    Haptics.tap()
                }
            }
            .listRowBackground(Palette.surface)
        }
        .environment(\.editMode, .constant(.active))
        .darkList()
        .navigationTitle("Batting order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    store.setXI(teamId: teamId, ids: order)
                    Haptics.success()
                    dismiss()
                }
            }
        }
        .onAppear {
            if order.isEmpty, let t = store.team(teamId) { order = t.xi.isEmpty ? t.squad : t.xi }
        }
    }
}

/// Batting-strength colour: elite lime → solid blue → amber → tail grey.
func strengthColor(_ v: Int) -> Color {
    switch v {
    case 75...: return Palette.accent
    case 60..<75: return Palette.four
    case 45..<60: return Color(hex: "#F59E0B")
    default: return Palette.muted
    }
}

enum BattingSlot {
    case opener, topOrder, finisher, tail

    init(position i: Int) {
        switch i {
        case 0, 1: self = .opener
        case 2, 3: self = .topOrder
        case 4, 5, 6: self = .finisher
        default: self = .tail
        }
    }

    var label: String {
        switch self {
        case .opener: return "OPENER"
        case .topOrder: return "TOP ORDER"
        case .finisher: return "FINISHER"
        case .tail: return "TAIL"
        }
    }

    /// Batting traits that shine in this slot.
    var suits: [Trait] {
        switch self {
        case .opener: return [.powerplayBlitz, .anchor, .paceBasher]
        case .topOrder: return [.anchor, .spinBasher, .threeSixty, .chaseMaster]
        case .finisher: return [.finisher, .powerHitter, .spinBasher, .chaseMaster]
        case .tail: return []
        }
    }
}

/// One row of the batting order: slot, name, traits, and a big clear strength reading.
struct BattingSlotRow: View {
    let position: Int
    let player: Player

    var body: some View {
        let slot = BattingSlot(position: position)
        let batTraits = player.traits.filter(\.isBatting)
        let fits = batTraits.contains { slot.suits.contains($0) }
        let color = strengthColor(player.bat)
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text("\(position + 1)").font(.display(26)).foregroundStyle(position < 7 ? .white : Palette.muted)
                Text(slot.label).font(.display(9, weight: .heavy)).foregroundStyle(Palette.muted)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(player.name).font(.body.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    if player.overseas { Image(systemName: "airplane").font(.caption2).foregroundStyle(Palette.muted) }
                }
                HStack(spacing: 6) {
                    RoleChip(role: player.role)
                    ForEach(batTraits, id: \.self) { t in
                        Text("\(t.icon) \(t.label)").font(.caption2.weight(.semibold))
                            .foregroundStyle(slot.suits.contains(t) ? Palette.accent : Palette.muted)
                            .lineLimit(1)
                    }
                    if fits { Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Palette.accent) }
                }
                // Strength bar.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(color).frame(width: geo.size.width * CGFloat(player.bat) / 100)
                    }
                }
                .frame(height: 5)
            }

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(player.bat)").font(.display(32)).foregroundStyle(color)
                Text("BAT").font(.display(10, weight: .heavy)).foregroundStyle(Palette.muted)
                if player.bowl >= 40 {
                    Text("BOWL \(player.bowl)").font(.score(11, weight: .semibold)).foregroundStyle(Palette.muted)
                        .lineLimit(1).fixedSize()
                }
            }
            .frame(width: 58, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

/// Quick read of the line-up: top-order and finishing strength, plus bowling depth.
struct LineupSummary: View {
    let players: [Player]

    var body: some View {
        let top = Array(players.prefix(4))
        let middle = Array(players.dropFirst(4).prefix(3))
        let avg: ([Player]) -> Int = { $0.isEmpty ? 0 : $0.map(\.bat).reduce(0, +) / $0.count }
        let bowlers = players.filter(\.isBowlingOption).count
        HStack(spacing: 0) {
            stat("\(avg(top))", "TOP 4 BAT", strengthColor(avg(top)))
            stat("\(avg(middle))", "5–7 BAT", strengthColor(avg(middle)))
            stat("\(bowlers)", "BOWLERS", bowlers >= 5 ? Palette.accent : .orange)
        }
        .padding(.vertical, 4)
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.display(30)).foregroundStyle(color)
            Text(label).font(.display(11, weight: .heavy)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
