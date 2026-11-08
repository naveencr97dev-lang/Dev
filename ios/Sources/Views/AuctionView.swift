import SwiftUI

struct AuctionView: View {
    @EnvironmentObject var store: GameStore
    @State private var showSquads = false
    @State private var confirmSim = false
    @State private var confirmQuit = false
    private let clock = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                if let g = store.game {
                    VStack(spacing: DS.Space.md) {
                        lotHeader(g)
                        if let p = store.currentPlayer {
                            PlayerCard(player: p)
                            bidPanel(g, p)
                            bidButtons(g, p)
                        }
                        purseStrip(g)
                        recentSales(g)
                    }
                    .padding(DS.Space.lg)
                }
            }
            .background(AppBackground())
            .overlay {
                if let b = store.banner {
                    SoldBanner(record: b).transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: store.banner)
            .navigationTitle("Auction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { store.paused.toggle() } label: {
                        Label(store.paused ? "Resume" : "Pause", systemImage: store.paused ? "play.fill" : "pause.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showSquads = true } label: { Label("View squads", systemImage: "person.3") }
                        Button { confirmSim = true } label: { Label("Sim rest of auction", systemImage: "forward.end") }
                        QuitMenuItem(confirm: $confirmQuit)
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $showSquads) {
                NavigationStack { SquadsView(preseason: false) }
                    .environmentObject(store)
            }
            .onChange(of: showSquads) { open in store.paused = open }
            .confirmationDialog("Let the CPU finish the auction? Human teams won't bid on the remaining players; anyone short of 11 gets filled at base price.",
                                isPresented: $confirmSim, titleVisibility: .visible) {
                Button("Sim rest of auction") { store.simRestOfAuction() }
                Button("Cancel", role: .cancel) {}
            }
            .quitConfirmation($confirmQuit, store: store)
        }
        .onReceive(clock) { _ in store.tick(0.1) }
        .keepAwake()
    }

    // MARK: Sections

    private func lotHeader(_ g: GameState) -> some View {
        let a = g.auction
        let pool = store.currentPlayer?.pool ?? ""
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(a.round == 1 ? "LOT \(min(a.index + 1, a.queue.count)) OF \(a.queue.count)" : "ACCELERATED · \(min(a.index + 1, a.queue.count))/\(a.queue.count)")
                    .font(.caption.weight(.bold)).foregroundStyle(Palette.gold)
                Text(a.round == 1 ? pool : "Unsold players return")
                    .font(.headline)
            }
            Spacer()
            if store.paused {
                Chip(text: "PAUSED", color: .orange.opacity(0.6))
            }
        }
    }

    private func bidPanel(_ g: GameState, _ p: Player) -> some View {
        let leader = g.auction.leader.flatMap { g.team($0) }
        let fraction = max(0, min(1, store.timeLeft / g.rules.bidSeconds))
        return AppCard(tint: leader.map { Color(hex: $0.colorHex) }) {
            VStack(spacing: DS.Space.sm) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(leader == nil ? "BASE PRICE" : "CURRENT BID")
                            .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        Text(Money.format(g.auction.currentBid ?? p.base))
                            .font(.display(38, weight: .heavy))
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    if let leader {
                        VStack(spacing: 4) {
                            TeamBadge(team: leader, size: 48)
                            Text(leader.isCPU ? "CPU" : "Leading").font(.caption2.weight(.bold))
                        }
                    } else {
                        Text("No bids yet").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                ProgressView(value: fraction)
                    .tint(fraction < 0.35 ? Palette.wicket : Palette.gold)
                    .animation(.linear(duration: 0.1), value: fraction)
                HStack {
                    Text(store.lastAction).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Text(String(format: "%.0fs", max(0, store.timeLeft.rounded(.up))))
                        .font(.footnote.monospacedDigit().weight(.bold))
                }
            }
        }
    }

    private func bidButtons(_ g: GameState, _ p: Player) -> some View {
        let next = g.nextBidAmount(book: store.book) ?? p.base
        let humans = g.teams.filter { !$0.isCPU }
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(humans) { t in
                    let leading = g.auction.leader == t.id
                    let reason = AuctionEngine.blockReason(t, on: p, amount: next, rules: g.rules, players: store.book.byId)
                    let enabled = !leading && reason == nil && store.banner == nil && !store.paused
                    Button { store.humanBid(t.id) } label: {
                        VStack(spacing: 3) {
                            Text(t.short).font(.display(20, weight: .heavy))
                            Text(leading ? "Leading ✓" : (reason ?? "Bid \(Money.format(next))"))
                                .font(.caption.weight(.bold))
                            Text("\(Money.format(t.purse)) · \(t.squad.count)/\(g.rules.maxSquad)")
                                .font(.caption2).opacity(0.85)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .fill(Color(hex: t.colorHex).opacity(enabled || leading ? 0.95 : 0.25))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .stroke(leading ? Color.white : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                }
            }
            Button {
                store.hammerNow()
            } label: {
                Label(g.auction.leader == nil ? "No takers — mark unsold" : "Hammer it — SOLD now", systemImage: "hammer.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(store.banner != nil || store.paused)
        }
    }

    private func purseStrip(_ g: GameState) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Purses")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(g.teams) { t in
                        VStack(spacing: 4) {
                            TeamBadge(team: t, size: 34)
                            Text(Money.format(t.purse)).font(.caption2.monospacedDigit().weight(.semibold))
                            Text("\(t.squad.count) · \(AuctionEngine.overseasCount(t, players: store.book.byId))✈︎")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(width: 66)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(Palette.card))
                    }
                }
            }
        }
    }

    private func recentSales(_ g: GameState) -> some View {
        let recent = g.auction.history.suffix(6).reversed()
        return Group {
            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    SectionLabel(text: "Recent")
                    AppCard(padding: DS.Space.md) {
                        VStack(spacing: 8) {
                            ForEach(Array(recent.enumerated()), id: \.offset) { _, s in
                                HStack {
                                    Text(store.player(s.playerId)?.name ?? "").font(.subheadline).lineLimit(1)
                                    Spacer()
                                    if let tid = s.teamId, let t = g.team(tid) {
                                        Text(Money.format(s.price)).font(.subheadline.monospacedDigit().weight(.semibold))
                                        TeamBadge(team: t, size: 24)
                                    } else {
                                        Text("Unsold").font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct PlayerCard: View {
    let player: Player

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(player.name).font(.display(28, weight: .heavy)).minimumScaleFactor(0.6).lineLimit(1)
                        HStack(spacing: 6) {
                            Chip(text: player.role.label.uppercased(), color: Palette.gold.opacity(0.3))
                            if player.overseas { Chip(text: "✈︎ OVERSEAS", color: Color.blue.opacity(0.35)) }
                            if player.pool == "Uncapped" { Chip(text: "UNCAPPED") }
                        }
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(player.rating)").font(.display(30, weight: .heavy)).foregroundStyle(Palette.gold)
                        Text("OVR").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    }
                }
                RatingBar(label: "BAT", value: player.bat, color: Palette.four)
                RatingBar(label: "BOWL", value: player.bowl, color: Palette.six)
                Text(player.line).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .id(player.id)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }
}

struct SoldBanner: View {
    @EnvironmentObject var store: GameStore
    let record: SaleRecord

    var body: some View {
        let team = record.teamId.flatMap { store.team($0) }
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 10) {
                Text(team == nil ? "UNSOLD" : "SOLD!")
                    .font(.display(54, weight: .black))
                    .foregroundStyle(team == nil ? Color.gray : Palette.gold)
                Text(store.player(record.playerId)?.name ?? "").font(.display(24))
                if let team {
                    HStack(spacing: 10) {
                        TeamBadge(team: team, size: 44)
                        VStack(alignment: .leading) {
                            Text(team.name).font(.headline)
                            Text(Money.format(record.price)).font(.display(26, weight: .heavy))
                        }
                    }
                }
            }
            .padding(30)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(team.map { Color(hex: $0.colorHex).opacity(0.35) } ?? Color.white.opacity(0.08)))
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.ultraThinMaterial))
            .padding(30)
        }
        .allowsHitTesting(false)
    }
}
