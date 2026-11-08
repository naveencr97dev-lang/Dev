import SwiftUI

struct AuctionView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.verticalSizeClass) private var vSize
    @State private var showSquads = false
    @State private var confirmSim = false
    @State private var confirmQuit = false
    private let clock = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if let g = store.game {
                    if vSize == .compact {
                        // Landscape: player on the left, bidding on the right (good for casting).
                        TwoColumns {
                            lotColumn(g, compact: true)
                        } right: {
                            bidColumn(g, compact: true)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: DS.Space.md) {
                                lotColumn(g)
                                bidColumn(g)
                            }
                            .padding(DS.Space.lg)
                        }
                    }
                }
            }
            .background(AppBackground())
            .overlay {
                if let b = store.banner {
                    SoldTicket(record: b)
                        .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity),
                                                removal: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.62), value: store.banner)
            .navigationTitle("Auction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { store.paused.toggle() } label: {
                        Image(systemName: store.paused ? "play.fill" : "pause.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker(selection: Binding(get: { store.game?.rules.bidStep ?? 0 },
                                                  set: { store.setBidStep($0) })) {
                            ForEach(Rules.bidSteps, id: \.self) { step in
                                Text(step == 0 ? "IPL-style" : "+\(Money.format(step)) per bid").tag(step)
                            }
                        } label: {
                            Label("Bid raise", systemImage: "arrow.up.circle")
                        }
                        .pickerStyle(.menu)
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
            .confirmationDialog("Let the CPU finish the auction? Human teams won't bid on the remaining players; empty slots get filled at base price.",
                                isPresented: $confirmSim, titleVisibility: .visible) {
                Button("Sim rest of auction") { store.simRestOfAuction() }
                Button("Cancel", role: .cancel) {}
            }
            .quitConfirmation($confirmQuit, store: store)
        }
        .onReceive(clock) { _ in store.tick(0.1) }
        .keepAwake()
    }

    // MARK: Columns

    @ViewBuilder private func lotColumn(_ g: GameState, compact: Bool = false) -> some View {
        lotHeader(g)
        if let p = store.currentPlayer {
            PlayerCard(player: p, setName: store.currentSetName, compact: compact)
            bidPanel(g, p, compact: compact)
        }
    }

    @ViewBuilder private func bidColumn(_ g: GameState, compact: Bool = false) -> some View {
        if let p = store.currentPlayer {
            bidButtons(g, p, compact: compact)
            actionRow(g)
        }
        purseStrip(g)
        if !compact { recentSales(g) }
    }

    // MARK: Sections

    private func lotHeader(_ g: GameState) -> some View {
        let a = g.auction
        let filled = g.teams.reduce(0) { $0 + $1.squad.count }
        let slots = g.teams.count * g.rules.maxSquad
        return HStack(alignment: .firstTextBaseline) {
            Text("LOT \(min(a.index + 1, a.queue.count))")
                .font(.display(26)).foregroundStyle(Palette.accent)
            Text("/ \(a.queue.count)").font(.display(18, weight: .heavy)).foregroundStyle(Palette.muted)
            Spacer(minLength: 4)
            if store.paused { Chip(text: "Paused", color: .orange.opacity(0.7)) }
            Text("\(filled)/\(slots) FILLED").font(.display(14, weight: .heavy)).foregroundStyle(Palette.muted)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private func bidPanel(_ g: GameState, _ p: Player, compact: Bool = false) -> some View {
        let leader = g.auction.leader.flatMap { g.team($0) }
        let fraction = max(0, min(1, store.timeLeft / g.rules.bidSeconds))
        let urgent = fraction < 0.3
        return VStack(spacing: 10) {
            HStack(alignment: .center, spacing: DS.Space.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(leader == nil ? "BASE PRICE" : "CURRENT BID")
                        .font(.display(13, weight: .heavy)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Slant().fill(leader == nil ? Palette.muted : Palette.accent))
                    Text(Money.format(g.auction.currentBid ?? p.base))
                        .font(.score(compact ? 34 : 44))
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: g.auction.currentBid)
                }
                Spacer()
                if let leader {
                    VStack(spacing: 4) {
                        TeamBadge(team: leader, size: compact ? 40 : 54).pulse(Color(hex: leader.colorHex), active: true)
                        Text(leader.isCPU ? "CPU" : "LEADING").font(.display(12, weight: .heavy)).foregroundStyle(Palette.muted)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .id(leader.id)
                } else {
                    Text("No bids yet").font(.subheadline).foregroundStyle(Palette.muted)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: g.auction.leader)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(urgent ? Palette.wicket : Palette.accent)
                        .frame(width: geo.size.width * fraction)
                        .animation(.linear(duration: 0.1), value: fraction)
                }
            }
            .frame(height: 6)
            HStack {
                Text(store.lastAction).font(.footnote).foregroundStyle(Palette.muted).lineLimit(1)
                Spacer()
                Text("\(Int(max(0, store.timeLeft.rounded(.up))))s")
                    .font(.score(16)).foregroundStyle(urgent ? Palette.wicket : .white)
            }
        }
        .padding(compact ? DS.Space.md : DS.Space.lg)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
            .stroke(leader.map { Color(hex: $0.colorHex) } ?? Palette.stroke, lineWidth: leader == nil ? 1 : 2))
    }

    private func bidButtons(_ g: GameState, _ p: Player, compact: Bool = false) -> some View {
        let next = g.nextBidAmount(book: store.book) ?? p.base
        let humans = g.teams.filter { !$0.isCPU }
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(humans) { t in
                let leading = g.auction.leader == t.id
                let reason = AuctionEngine.blockReason(t, on: p, amount: next, rules: g.rules, players: store.book.byId)
                let enabled = !leading && reason == nil && store.banner == nil && !store.paused
                let color = Color(hex: t.colorHex)
                Button { store.humanBid(t.id) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            TeamBadge(team: t, size: compact ? 24 : 30)
                            Text(leading ? "LEADING" : (reason?.uppercased() ?? "BID \(Money.format(next))"))
                                .font(.display(compact ? 15 : 17)).lineLimit(1).minimumScaleFactor(0.5)
                        }
                        Text("\(Money.format(t.purse)) · \(t.squad.count)/\(g.rules.maxSquad)")
                            .font(.score(compact ? 11 : 13, weight: .semibold)).opacity(0.85)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text(store.needs(t.id).summary).font(.caption2).opacity(0.75)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(compact ? 7 : 10)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(LinearGradient(colors: [color.opacity(enabled || leading ? 0.95 : 0.22),
                                                          color.opacity(enabled || leading ? 0.6 : 0.12)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .stroke(leading ? Palette.accent : .clear, lineWidth: 2))
                    .pulse(color, active: leading)
                }
                .buttonStyle(BidButtonStyle())
                .disabled(!enabled)
            }
        }
    }

    private func actionRow(_ g: GameState) -> some View {
        HStack(spacing: 10) {
            Button { store.skipLot() } label: { Label("Skip", systemImage: "forward.fill").lineLimit(1) }
                .buttonStyle(SecondaryButtonStyle())
            Button { store.hammerNow() } label: {
                Label(g.auction.leader == nil ? "Unsold" : "Sold", systemImage: "hammer.fill").lineLimit(1)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .disabled(store.banner != nil || store.paused)
        .overlay(alignment: .bottom) {
            Text("Skip: CPUs settle this player instantly")
                .font(.caption2).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.6).offset(y: 18)
        }
        .padding(.bottom, 14)
    }

    private func purseStrip(_ g: GameState) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Purses")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(g.teams) { t in
                        VStack(spacing: 4) {
                            TeamBadge(team: t, size: 34)
                            Text(Money.format(t.purse)).font(.score(13))
                                .contentTransition(.numericText())
                            HStack(spacing: 2) {
                                ForEach(0..<g.rules.maxSquad, id: \.self) { i in
                                    Capsule().fill(i < t.squad.count ? Color(hex: t.colorHex) : Color.white.opacity(0.12))
                                        .frame(width: 4, height: 8)
                                }
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(Palette.surface))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(Palette.stroke))
                    }
                }
            }
        }
    }

    private func recentSales(_ g: GameState) -> some View {
        let recent = Array(g.auction.history.suffix(6).reversed())
        return Group {
            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    SectionLabel(text: "Recent")
                    AppCard(padding: DS.Space.md) {
                        VStack(spacing: 8) {
                            ForEach(Array(recent.enumerated()), id: \.offset) { i, s in
                                HStack {
                                    Text(store.player(s.playerId)?.name ?? "").font(.subheadline).lineLimit(1)
                                    Spacer()
                                    if let tid = s.teamId, let t = g.team(tid) {
                                        Text(Money.format(s.price)).font(.score(15))
                                        TeamBadge(team: t, size: 22)
                                    } else {
                                        Text("UNSOLD").font(.display(13, weight: .heavy)).foregroundStyle(Palette.muted)
                                    }
                                }
                                .opacity(i == 0 ? 1 : 0.75)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct BidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

/// Trading-card style lot, flips in for every new player.
struct PlayerCard: View {
    let player: Player
    var setName: String = ""
    /// Landscape: smaller type, no stat line or trait descriptions.
    var compact = false

    var body: some View {
        FlipCard(id: player.id) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(setName.uppercased()).font(.display(13, weight: .heavy))
                    Spacer(minLength: 4)
                    Text(player.role.label.uppercased()).font(.display(13, weight: .heavy))
                }
                .lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, DS.Space.lg).padding(.vertical, 6)
                .background(Palette.role(player.role))

                VStack(alignment: .leading, spacing: compact ? DS.Space.sm : DS.Space.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(player.name.uppercased()).font(.display(compact ? 26 : 34)).minimumScaleFactor(0.4).lineLimit(1)
                            ViewThatFits(in: .horizontal) {
                                chips(full: true)
                                chips(full: false)
                            }
                        }
                        Spacer(minLength: 4)
                        VStack(spacing: -4) {
                            Text("\(player.rating)").font(.display(compact ? 34 : 46)).foregroundStyle(Palette.accent)
                            Text("OVR").font(.display(12, weight: .heavy)).foregroundStyle(Palette.muted)
                        }
                    }
                    RatingBar(label: "BAT", value: player.bat, color: Color(hex: "#F59E0B"))
                    RatingBar(label: "BOWL", value: player.bowl, color: Color(hex: "#F43F5E"))
                    TraitChips(traits: player.traits, showBlurb: !compact)
                    let thrives = Pitch.favoured(by: player)
                    HStack(spacing: 6) {
                        Text("BATS \(player.slot.label)").font(.display(12, weight: .heavy)).foregroundStyle(Palette.muted)
                        if !thrives.isEmpty {
                            Text("· THRIVES ON").font(.display(12, weight: .heavy)).foregroundStyle(Palette.muted)
                            Text(thrives.map(\.icon).joined(separator: " ")).font(.caption)
                        }
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                    if !compact {
                        Text(player.line).font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
                .padding(compact ? DS.Space.md : DS.Space.lg)
            }
            .background(
                ZStack {
                    Palette.surface
                    LinearGradient(colors: [Palette.role(player.role).opacity(0.18), .clear], startPoint: .top, endPoint: .center)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(player.isLegend ? Palette.accent.opacity(0.7) : Palette.stroke, lineWidth: player.isLegend ? 1.5 : 1))
        }
    }
}

extension PlayerCard {
    @ViewBuilder func chips(full: Bool) -> some View {
        HStack(spacing: 6) {
            if player.overseas { Chip(text: full ? "✈︎ Overseas" : "✈︎", color: Color(hex: "#1E3A8A")) }
            if player.legend {
                Chip(text: full ? "★ IPL Legend" : "★", color: Palette.accent, textColor: Palette.ink)
            } else if full {
                Chip(text: "Current star")
            }
            if player.bowl >= 40 { Chip(text: player.bowlType == .spin ? "Spin" : "Pace") }
        }
        .fixedSize()
    }
}

/// Re-runs a 3D flip whenever `id` changes.
struct FlipCard<Content: View>: View {
    let id: String
    @ViewBuilder var content: Content
    @State private var angle: Double = 90

    var body: some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .opacity(angle > 80 ? 0 : 1)
            .onAppear { flip() }
            .onChange(of: id) { _ in
                var reset = Transaction()
                reset.disablesAnimations = true
                withTransaction(reset) { angle = 90 }
                DispatchQueue.main.async { flip() }
            }
    }

    private func flip() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { angle = 0 }
    }
}

/// SOLD / UNSOLD ticket that pops over the auction.
struct SoldTicket: View {
    @EnvironmentObject var store: GameStore
    let record: SaleRecord
    @State private var stamp = false

    var body: some View {
        let team = record.teamId.flatMap { store.team($0) }
        let color = team.map { Color(hex: $0.colorHex) } ?? Palette.muted
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(store.player(record.playerId)?.name.uppercased() ?? "").font(.display(30)).lineLimit(1).minimumScaleFactor(0.5)
                    if let team {
                        HStack(spacing: 10) {
                            TeamBadge(team: team, size: 40)
                            Text(team.name.uppercased()).font(.display(18, weight: .heavy))
                        }
                    } else {
                        Text("No takers").font(.headline).foregroundStyle(Palette.muted)
                    }
                }
                .padding(.vertical, 22).padding(.horizontal, 28)
                Line().stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6])).foregroundStyle(Palette.ink.opacity(0.5))
                    .frame(height: 1).padding(.horizontal, 20)
                HStack {
                    Text(team == nil ? "UNSOLD" : "SOLD").font(.display(44))
                    Spacer()
                    if team != nil { Text(Money.format(record.price)).font(.score(32)) }
                }
                .padding(.vertical, 16).padding(.horizontal, 28)
            }
            .foregroundStyle(Palette.ink)
            .background(TicketShape().fill(team == nil ? Color(hex: "#C9CDD6") : Palette.accent, style: FillStyle(eoFill: true))
                .clipShape(Rectangle()))
            .overlay(alignment: .topTrailing) {
                Text(team?.short ?? "—")
                    .font(.display(20)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Slant().fill(color))
                    .rotationEffect(.degrees(stamp ? -8 : -30))
                    .scaleEffect(stamp ? 1 : 2.2)
                    .opacity(stamp ? 1 : 0)
                    .offset(x: 6, y: -12)
            }
            .rotationEffect(.degrees(-3))
            .padding(32)
            .frame(maxWidth: 460)
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.spring(response: 0.35, dampingFraction: 0.5).delay(0.15)) { stamp = true } }
    }
}

struct Line: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}
