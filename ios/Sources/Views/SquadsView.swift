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
                                VStack(alignment: .trailing, spacing: 2) {
                                    BattingSlotRow(position: i, player: p)
                                    if let price = t.paid[pid] {
                                        Text("Bought for \(Money.format(price))").font(.caption2).foregroundStyle(Palette.muted)
                                    }
                                }
                                .reorderRow()
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
    @Environment(\.verticalSizeClass) private var vSize
    let teamId: Int
    @State private var order: [String] = []

    var body: some View {
        let players = order.compactMap { store.player($0) }
        TableScreen(title: "Batting order", scrolls: false) {
            LineupSummary(players: players)
            HStack(spacing: 6) {
                TableNote(text: "Drag ≡ to reorder · ✓ best slot · ~ close · ! out of position")
                Spacer(minLength: 4)
                ActionChip(icon: "sparkles", title: "Best order") {
                    order = TeamSelector.battingOrder(order.compactMap { store.player($0) }).map(\.id)
                    Haptics.tap()
                }
                ActionChip(icon: "checkmark", title: "Save", primary: true) {
                    store.setXI(teamId: teamId, ids: order)
                    Haptics.success()
                    dismiss()
                }
            }
            TableHead {
                Text("#").frame(width: TCol.num, alignment: .center)
                if vSize == .compact { Text("SLOT").frame(width: TCol.wide, alignment: .leading) }
                Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
                Text("ROLE").frame(width: TCol.role, alignment: .leading)
                Text("FIT").frame(width: 92, alignment: .leading)
                Text("BAT").frame(width: TCol.stat, alignment: .trailing)
                if vSize == .compact { Text("BOWL").frame(width: TCol.stat, alignment: .trailing) }
            }
            .padding(.trailing, TCol.handle)
        } rows: {
            ReorderList {
                ForEach(Array(order.enumerated()), id: \.element) { i, pid in
                    if let p = store.player(pid) {
                        BattingSlotRow(position: i, player: p).reorderRow()
                    }
                }
                .onMove { order.move(fromOffsets: $0, toOffset: $1) }
            }
        }
        .onAppear {
            if order.isEmpty, let t = store.team(teamId) { order = t.xi.isEmpty ? t.squad : t.xi }
        }
    }
}

/// A List that only reorders (drag handles always on), styled as table rows on black.
struct ReorderList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        List { content }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
    }
}

extension View {
    /// A table row inside a ReorderList: no separators, no inset, the row's own surface.
    func reorderRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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

/// One row of the batting order on one line: position, slot, name, role, fit, batting, bowling.
struct BattingSlotRow: View {
    let position: Int
    let player: Player
    @Environment(\.verticalSizeClass) private var vSize

    var body: some View {
        let slot = BatSlot(position: position)
        let fit = player.slot.fit(position: position)
        let exposed = player.isExposed(atPosition: position)
        HStack(spacing: 8) {
            TNum(text: "\(position + 1)", width: TCol.num, color: position < 7 ? .white : Palette.muted, align: .center)
            if vSize == .compact {
                Text(slot.label).font(.system(size: 11 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted)
                    .lineLimit(1).minimumScaleFactor(0.7).frame(width: TCol.wide, alignment: .leading)
            }
            TName(text: player.name, overseas: player.overseas, legend: player.legend)
            TRole(role: player.role)
            Group {
                if exposed {
                    Text("! Tail-ender").foregroundStyle(Palette.wicket)
                } else {
                    FitBadge(fit: fit, preferred: player.slot)
                }
            }
            .font(.system(size: 11 * TextScale.factor, weight: .bold))
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(width: 92, alignment: .leading)
            TNum(text: "\(player.bat)", width: TCol.stat, color: strengthColor(player.bat))
            if vSize == .compact {
                TNum(text: player.bowl >= 40 ? "\(player.bowl)" : "–", width: TCol.stat, color: Palette.muted)
            }
        }
        .tableRow(selected: exposed)
    }
}

/// The line-up in one summary line: order strength, top-order and middle batting, bowlers.
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
        SummaryLine(cells: [
            SummaryCell(value: "\(pct)%", label: "order", color: pct >= 98 ? Palette.accent : (pct >= 90 ? Palette.four : (pct >= 80 ? .orange : Palette.wicket))),
            SummaryCell(value: "\(avg(top))", label: "top 4", color: strengthColor(avg(top))),
            SummaryCell(value: "\(avg(middle))", label: "5–7", color: strengthColor(avg(middle))),
            SummaryCell(value: "\(bowlers)", label: "bowlers", color: bowlers >= 5 ? .white : .orange),
            SummaryCell(value: "\(exposed)", label: "exposed", color: exposed > 0 ? Palette.wicket : Palette.muted),
        ])
    }
}

/// ✓ in slot, ~ near, ! out of position.
struct FitBadge: View {
    let fit: Int
    let preferred: BatSlot

    var body: some View {
        let color = fit >= 6 ? Palette.accent : (fit > 0 ? Palette.four : Color.orange)
        Text(fit >= 6 ? "✓ \(preferred.label)" : (fit > 0 ? "~ \(preferred.label)" : "! prefers \(preferred.label.lowercased())"))
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Pick the five bowlers and who takes the new ball and the death overs.
struct BowlingPlanView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var vSize
    let teamId: Int
    @State private var order: [String] = []

    static let slotInfo: [(String, BowlPhase?)] = [
        ("New ball + death", nil), ("New ball + death", nil),
        ("Middle overs", .middle), ("Middle overs", .middle), ("Middle + 1 death", .middle),
    ]

    var body: some View {
        let players = order.compactMap { store.player($0) }
        let five = Array(players.prefix(5))
        // Career, your own club: show home-pitch fit and offer a scout for slots that only read ok.
        let career = store.inCareer ? store.career : nil
        let mine = career.map { $0.userClubId == teamId } ?? false
        let weak = five.enumerated().filter { MatchEngine.slotFit($0.element, slot: $0.offset) <= MatchEngine.slotSuits }.count
        TableScreen(title: "Bowling plan", scrolls: false) {
            SummaryLine(cells: [
                SummaryCell(value: "\(attackStrength(players))", label: "attack", color: strengthColor(attackStrength(players))),
                SummaryCell(value: "\(five.filter { $0.bowlType == .pace }.count)", label: "pace"),
                SummaryCell(value: "\(five.filter { $0.bowlType == .spin }.count)", label: "spin"),
                SummaryCell(value: "\(five.filter { !$0.isBowlingOption }.count)", label: "part-timers",
                            color: five.contains { !$0.isBowlingOption } ? .orange : Palette.muted),
            ])
            HStack(spacing: 6) {
                TableNote(text: mine
                          ? "Drag ≡ to set the plan. JOB FIT: traits for the overs (new ball, death, middle). HOME: suits your pitch."
                          : "Top 5 bowl. Drag ≡ to set the plan. 1–2: new ball and death · 3–5: middle overs")
                Spacer(minLength: 4)
                if mine && weak > 0 {
                    NavigationLink {
                        ScoutingView().onAppear { store.careerScoutBowlingPlan() }
                    } label: {
                        LinkChipLabel(icon: "binoculars", title: "Scout bowlers")
                    }
                    .buttonStyle(.plain)
                }
                ActionChip(icon: "sparkles", title: "Auto per pitch") {
                    store.setBowlingOrder(teamId: teamId, ids: [])
                    Haptics.success()
                    dismiss()
                }
                ActionChip(icon: "checkmark", title: "Save", primary: true) {
                    store.setBowlingOrder(teamId: teamId, ids: Array(order.prefix(5)))
                    Haptics.success()
                    dismiss()
                }
            }
            TableHead {
                Text("#").frame(width: TCol.num, alignment: .center)
                if vSize == .compact { Text("JOB").frame(width: 104, alignment: .leading) }
                Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
                Text("TYPE").frame(width: TCol.role, alignment: .leading)
                Text("JOB FIT").frame(width: 70, alignment: .leading)
                if mine { Text("HOME").frame(width: 60, alignment: .leading) }
                if vSize == .compact { Text("OVERS").frame(width: 80, alignment: .leading) }
                Text("BOWL").frame(width: TCol.stat, alignment: .trailing)
            }
            .padding(.trailing, TCol.handle)
        } rows: {
            ReorderList {
                ForEach(Array(order.enumerated()), id: \.element) { i, pid in
                    if let p = store.player(pid) {
                        BowlingSlotRow(index: i, player: p, showHome: mine,
                                       homeFit: career?.players[pid].flatMap { career?.suitsUserPitch($0) })
                            .reorderRow()
                    }
                }
                .onMove { order.move(fromOffsets: $0, toOffset: $1) }
            }
        }
        .onAppear {
            guard order.isEmpty, let t = store.team(teamId) else { return }
            // Bowlers come from the playing XI (career squads are bigger than the XI).
            let squad = (t.xi.count == 11 ? t.xi : t.squad).compactMap { store.player($0) }
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
        /// Career, your club: the HOME column (true suits your pitch, false struggles, nil neither).
        var showHome = false
        var homeFit: Bool? = nil
        @Environment(\.verticalSizeClass) private var vSize

        var body: some View {
            let bowling = index < 5
            let fit = MatchEngine.slotFit(player, slot: min(index, 4))
            let overs = bowling ? MatchEngine.overs(forSlot: index).map(String.init).joined(separator: ", ") : ""
            HStack(spacing: 8) {
                TNum(text: bowling ? "\(index + 1)" : "–", width: TCol.num, color: bowling ? .white : Palette.muted, align: .center)
                if vSize == .compact {
                    Text(bowling ? BowlingPlanView.slotInfo[index].0 : "Not bowling")
                        .font(.system(size: 11 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted)
                        .lineLimit(1).minimumScaleFactor(0.7).frame(width: 104, alignment: .leading)
                }
                TName(text: player.name, overseas: player.overseas, legend: player.legend)
                Text(player.bowlType == .spin ? "Spin" : "Pace")
                    .font(.system(size: 11 * TextScale.factor, weight: .heavy))
                    .foregroundStyle(player.bowlType == .spin ? Palette.six : Palette.four)
                    .frame(width: TCol.role, alignment: .leading)
                Text(bowling ? (fit > 3 ? "✓ suits" : (fit < 0 ? "! poor" : "ok")) : "")
                    .font(.system(size: 11 * TextScale.factor, weight: .bold))
                    .foregroundStyle(fit > 3 ? Palette.accent : (fit < 0 ? Color.orange : Palette.muted))
                    .frame(width: 70, alignment: .leading)
                if showHome {
                    HStack(spacing: 3) {
                        PitchFitMark(fit: homeFit, size: 10)
                        Text(homeFit == true ? "suits" : (homeFit == false ? "poor" : "ok"))
                    }
                    .font(.system(size: 11 * TextScale.factor, weight: .bold))
                    .foregroundStyle(homeFit == true ? Palette.accent : (homeFit == false ? Color.orange : Palette.muted))
                    .frame(width: 60, alignment: .leading)
                }
                if vSize == .compact {
                    Text(overs).font(.score(11, weight: .semibold)).foregroundStyle(Palette.muted)
                        .lineLimit(1).minimumScaleFactor(0.6).frame(width: 80, alignment: .leading)
                }
                TNum(text: "\(player.bowl)", width: TCol.stat, color: bowling ? strengthColor(player.bowl) : Palette.muted)
            }
            .tableRow(dimmed: !bowling)
        }
    }
}
