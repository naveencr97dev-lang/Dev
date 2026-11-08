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
                            NavigationLink { BowlingPlanView(teamId: teamId) } label: {
                                Label(t.bowlingOrder.isEmpty ? "Bowling plan · Auto per pitch" : "Bowling plan · Custom",
                                      systemImage: "figure.cricket").foregroundStyle(Palette.accent)
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
                Text("Drag ≡ to reorder. Big number = batting strength. ✓ = in their best slot (+6), ~ = close (+2), ⚠︎ = out of position (−8 to −26). 🚨 A tail-ender in the top six gets out about twice as often and rarely scores. ORDER = this order's strength vs the best possible.")
            }
            .listRowBackground(Palette.surface)
            Section {
                Button("✨ Best order") {
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

/// One row of the batting order: slot, name, traits, and a big clear strength reading.
struct BattingSlotRow: View {
    let position: Int
    let player: Player

    var body: some View {
        let slot = BatSlot(position: position)
        let batTraits = player.traits.filter(\.isBatting)
        let fit = player.slot.fit(position: position)
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
                    if player.isExposed(atPosition: position) {
                        Text("🚨 EXPOSED — tail-ender up top").font(.caption2.weight(.heavy)).foregroundStyle(Palette.wicket).lineLimit(1)
                    } else {
                        FitBadge(fit: fit, preferred: player.slot)
                    }
                    Text(batTraits.map(\.icon).joined()).font(.caption2).lineLimit(1)
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
        let best = TeamSelector.orderScore(TeamSelector.battingOrder(players))
        let pct = best > 0 ? Int((TeamSelector.orderScore(players) / best * 100).rounded()) : 100
        let exposed = players.enumerated().filter { $0.element.isExposed(atPosition: $0.offset) }.count
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                stat("\(pct)%", "ORDER", pct >= 98 ? Palette.accent : (pct >= 90 ? Palette.four : (pct >= 80 ? .orange : Palette.wicket)))
                stat("\(avg(top))", "TOP 4 BAT", strengthColor(avg(top)))
                stat("\(avg(middle))", "5–7 BAT", strengthColor(avg(middle)))
                stat("\(bowlers)", "BOWLERS", bowlers >= 5 ? Palette.accent : .orange)
            }
            if exposed > 0 {
                Text("🚨 \(exposed) tail-ender\(exposed == 1 ? "" : "s") in the top six — expect a collapse")
                    .font(.caption.weight(.bold)).foregroundStyle(Palette.wicket)
            }
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

/// ✓ in slot, ~ near, ⚠︎ out of position.
struct FitBadge: View {
    let fit: Int
    let preferred: BatSlot

    var body: some View {
        let icon = fit >= 6 ? "✓" : (fit > 0 ? "~" : "⚠︎")
        let color = fit >= 6 ? Palette.accent : (fit > 0 ? Palette.four : Color.orange)
        Text(fit >= 6 ? "\(icon) \(preferred.label)" : "\(icon) prefers \(preferred.label.lowercased())")
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Pick the five bowlers and who takes the new ball and the death overs.
struct BowlingPlanView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let teamId: Int
    @State private var order: [String] = []

    private static let slotInfo: [(String, BowlPhase?)] = [
        ("NEW BALL + DEATH", nil), ("NEW BALL + DEATH", nil),
        ("MIDDLE OVERS", .middle), ("MIDDLE OVERS", .middle), ("MIDDLE + 1 DEATH", .middle),
    ]

    var body: some View {
        let players = order.compactMap { store.player($0) }
        List {
            Section {
                ForEach(Array(order.enumerated()), id: \.element) { i, pid in
                    if let p = store.player(pid) {
                        BowlingSlotRow(index: i, player: p)
                    }
                }
                .onMove { order.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text("Top 5 bowl · drag to set the plan")
            } footer: {
                Text("Slots 1–2 bowl overs 1–4 and the death (15–20): swing (🌪️) and death specialists (☠️ 🐢) gain there, spinners lose. Slots 3–5 bowl the middle: spinners and 🧱 gain. Pace/spin also gains or loses with the pitch. Auto lets the captain pick the best five for each pitch.")
            }
            .listRowBackground(Palette.surface)
            Section {
                Button("✨ Auto — captain picks per pitch") {
                    store.setBowlingOrder(teamId: teamId, ids: [])
                    Haptics.success()
                    dismiss()
                }
                Text("Attack strength: \(attackStrength(players))").font(.subheadline).foregroundStyle(Palette.muted)
            }
            .listRowBackground(Palette.surface)
        }
        .environment(\.editMode, .constant(.active))
        .darkList()
        .navigationTitle("Bowling plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    store.setBowlingOrder(teamId: teamId, ids: Array(order.prefix(5)))
                    Haptics.success()
                    dismiss()
                }
            }
        }
        .onAppear {
            guard order.isEmpty, let t = store.team(teamId) else { return }
            let squad = t.squad.compactMap { store.player($0) }
            let plan = t.bowlingOrder.count == 5 ? t.bowlingOrder.compactMap { store.player($0) } : MatchEngine.autoAttack(squad, pitch: nil)
            let rest = squad.filter { p in !plan.contains(p) }.sorted { $0.bowl > $1.bowl }
            order = (plan + rest).map(\.id)
        }
    }

    private func attackStrength(_ players: [Player]) -> Int {
        let five = players.prefix(5)
        guard !five.isEmpty else { return 0 }
        var total = 0
        for (i, p) in five.enumerated() {
            let fit = i < 2
                ? (MatchEngine.phaseFit(p, .powerplay, pitch: nil) + MatchEngine.phaseFit(p, .death, pitch: nil)) / 2
                : MatchEngine.phaseFit(p, .middle, pitch: nil)
            total += p.bowl + fit
        }
        return total / five.count
    }

    struct BowlingSlotRow: View {
        let index: Int
        let player: Player

        var body: some View {
            let bowling = index < 5
            let fit = index < 2
                ? MatchEngine.phaseFit(player, .powerplay, pitch: nil) + MatchEngine.phaseFit(player, .death, pitch: nil)
                : MatchEngine.phaseFit(player, .middle, pitch: nil)
            let overs = index < 5 ? MatchEngine.overs(forSlot: index).map(String.init).joined(separator: ", ") : ""
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(bowling ? "\(index + 1)" : "–").font(.display(26)).foregroundStyle(bowling ? .white : Palette.muted)
                    Text(bowling ? BowlingPlanView.slotInfo[index].0 : "NOT BOWLING")
                        .font(.display(8, weight: .heavy)).foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                }
                .frame(width: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name).font(.body.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    HStack(spacing: 6) {
                        Chip(text: player.bowlType == .spin ? "Spin" : "Pace")
                        Text(player.traits.filter(\.isBowling).map(\.icon).joined()).font(.caption2)
                        if bowling {
                            Text(fit > 3 ? "✓ suits slot" : (fit < 0 ? "⚠︎ poor fit" : "ok"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(fit > 3 ? Palette.accent : (fit < 0 ? Color.orange : Palette.muted))
                        }
                    }
                    if bowling {
                        Text("Overs \(overs)").font(.caption2).foregroundStyle(Palette.muted)
                    }
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(player.bowl)").font(.display(30)).foregroundStyle(bowling ? strengthColor(player.bowl) : Palette.muted)
                    Text("BOWL").font(.display(10, weight: .heavy)).foregroundStyle(Palette.muted)
                }
            }
            .opacity(bowling ? 1 : 0.6)
            .padding(.vertical, 3)
        }
    }
}
