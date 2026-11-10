import SwiftUI

// MARK: - Off-season steps (Home tab)

struct OffseasonCard: View {
    @EnvironmentObject var store: GameStore
    let career: Career
    let onStarted: ([String]) -> Void

    var body: some View {
        let c = career
        let stage = c.offseason?.stage ?? .window
        AppCard(tint: Palette.accent) {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                Text("\(String(c.year)) OFF-SEASON · \(c.offseason?.mega == true ? "MEGA AUCTION" : "MINI AUCTION")")
                    .font(.display(15, weight: .heavy)).foregroundStyle(Palette.accent)
                step(1, "Retentions", done: stage != .retention, active: stage == .retention, skipped: c.offseason?.mega != true)
                step(2, "Auction", done: stage == .window, active: stage == .auction, skipped: false)
                step(3, "Transfer window", done: false, active: stage == .window, skipped: false)

                switch stage {
                case .retention:
                    NavigationLink { RetentionView() } label: {
                        Text("Choose who to keep ▶︎").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                case .auction:
                    NavigationLink { CareerAuctionView() } label: {
                        Text("Enter the auction room ▶︎").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button("Skip: staff bid for me") { store.careerSimAuction(autoBid: true) }
                        .buttonStyle(SecondaryButtonStyle())
                case .window:
                    Text("Sign free agents or trade in the Market tab, then start the season.")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    Button("Start the \(String(c.year)) season ▶︎") {
                        let signed = store.careerStartSeason()
                        onStarted(signed)
                        Haptics.success()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                Text("Squad \(c.squad(c.userClubId).count)/\(c.tuning.maxSquad) · wages \(Money.format(c.payroll(c.userClubId))) of \(Money.format(c.tuning.salaryCap)) · bank \(Money.format(c.bank(c.userClubId)))")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }

    private func step(_ n: Int, _ title: String, done: Bool, active: Bool, skipped: Bool) -> some View {
        HStack(spacing: 10) {
            Text(skipped ? "–" : (done ? "✓" : "\(n)"))
                .font(.display(15, weight: .heavy))
                .foregroundStyle(active ? Palette.ink : Palette.muted)
                .frame(width: 24, height: 24)
                .background(Circle().fill(active ? Palette.accent : Palette.surfaceHi))
            Text(skipped ? "\(title) (mega-auction years only)" : title)
                .font(.subheadline.weight(active ? .bold : .regular))
                .foregroundStyle(active ? .white : Palette.muted)
        }
    }
}

// MARK: - Retentions

struct RetentionView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var loaded = false

    var body: some View {
        let c = store.career
        let squad = c.map { car in car.squad(car.userClubId).sorted { car.keepScore($0) > car.keepScore($1) } } ?? []
        let maxKeep = c?.tuning.maxRetentions ?? 6
        let cap = c?.tuning.salaryCap ?? 12_000
        let total = squad.filter { selected.contains($0.id) }.reduce(0) { $0 + (c?.retentionWage($1) ?? 0) }
        List {
            Section {
                HStack {
                    Text("\(selected.count)/\(maxKeep) kept").font(.headline)
                    Spacer()
                    Text("\(Money.format(total)) of \(Money.format(cap))").font(.subheadline.monospacedDigit())
                        .foregroundStyle(total > cap * 6 / 10 ? Palette.wicket : Palette.muted)
                }
                if total > cap * 6 / 10 {
                    Text("Retentions over 60% of the cap get trimmed from the bottom of your list.")
                        .font(.caption.weight(.bold)).foregroundStyle(.orange)
                }
            } footer: {
                Text("Every contract ends at a mega auction. Kept players sign again for 3 seasons at their market wage; everyone else goes into the auction, where you can try to buy them back.")
            }
            .listRowBackground(GameRowBackground())

            Section("Your squad") {
                ForEach(squad) { p in
                    Button { toggle(p.id, max: maxKeep) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selected.contains(p.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected.contains(p.id) ? Palette.accent : Palette.muted)
                            CareerPlayerRow(player: p, year: c?.year ?? 0)
                            Text(Money.format(c?.retentionWage(p) ?? 0)).font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(GameRowBackground())
        }
        .darkList()
        .navigationTitle("Retentions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Confirm") {
                    store.careerConfirmRetention(Array(selected))
                    Haptics.success()
                    dismiss()
                }
            }
        }
        .onAppear {
            if !loaded {
                selected = Set(store.career?.suggestedRetentions() ?? [])
                loaded = true
            }
        }
    }

    private func toggle(_ id: String, max: Int) {
        if selected.contains(id) {
            selected.remove(id)
        } else if selected.count < max {
            selected.insert(id)
        } else {
            Haptics.warning()
            return
        }
        Haptics.tap()
    }
}

// MARK: - Auction room

struct CareerAuctionView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var lastSale: SaleLine? = nil

    var body: some View {
        ScrollView {
            if let c = store.career, let os = c.offseason {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    PurseStrip(career: c)
                    if os.stage == .auction, let id = os.auction.currentId, let p = c.players[id] {
                        lot(c, os.auction, p)
                    } else {
                        AppCard {
                            VStack(alignment: .leading, spacing: DS.Space.md) {
                                Text("AUCTION COMPLETE").font(.display(20)).foregroundStyle(Palette.accent)
                                Text("Your squad: \(c.squad(c.userClubId).count) players. The transfer window is open.")
                                    .font(.subheadline)
                                Button("Back to the off-season") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                            }
                        }
                    }
                    if let s = lastSale, let p = c.players[s.playerId] {
                        Text(saleText(c, s, p.name)).font(.footnote).foregroundStyle(.secondary)
                    }
                    let mine = os.auction.sales.filter { $0.clubId == c.userClubId }
                    if !mine.isEmpty {
                        SectionLabel(text: "Your buys")
                        AppCard(padding: DS.Space.md) {
                            VStack(spacing: 6) {
                                ForEach(mine, id: \.playerId) { s in
                                    HStack {
                                        Text(c.players[s.playerId]?.name ?? s.playerId).font(.subheadline)
                                        Spacer()
                                        Text(Money.format(s.price)).font(.subheadline.monospacedDigit())
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(DS.Space.lg)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AppBackground())
        .navigationTitle("Auction")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lot(_ c: Career, _ a: CareerAuctionState, _ p: CareerPlayer) -> some View {
        let next = c.auctionNextBid ?? p.basePrice(in: c.year)
        let block = c.userBidBlock(p, amount: next)
        let leading = a.leader == c.userClubId
        let leader = a.leader.flatMap { c.club($0) }
        return VStack(alignment: .leading, spacing: DS.Space.md) {
            Text("LOT \(a.index + 1) OF \(a.queue.count)").font(.display(14, weight: .heavy)).foregroundStyle(Palette.muted)
            AppCard {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    CareerPlayerRow(player: p, year: c.year)
                    if !p.traits.isEmpty { TraitChips(traits: p.traits, inline: true) }
                    Text("Value \(Money.format(p.value(in: c.year))) · base \(Money.format(p.basePrice(in: c.year)))")
                        .font(.caption).foregroundStyle(Palette.muted)
                    if c.isRTMLot(p.id) {
                        Text("Your player last season · Right to Match cards: \(c.offseason?.rtmLeft ?? 0)")
                            .font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                    }
                    let advice = c.scoutAdvice(p)
                    Label(advice.text, systemImage: advice.good ? "checkmark.circle" : "info.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(advice.good ? Palette.accent : Palette.muted)
                    if let limit = c.auctionTopRivalLimit {
                        Text("Top rival limit: \(limit > 0 ? Money.format(limit) : "nobody interested")")
                            .font(.caption.weight(.bold)).foregroundStyle(Palette.accent)
                    }
                }
            }
            AppCard(tint: leader.map { Color(hex: $0.colorHex) }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.bid.map { Money.format($0) } ?? "No bids").font(.display(34))
                        Text(leader.map { leading ? "YOU LEAD" : "\($0.short) LEADS" } ?? "Opening at \(Money.format(next))")
                            .font(.display(14, weight: .heavy)).foregroundStyle(leading ? Palette.accent : Palette.muted)
                    }
                    Spacer()
                    if let leader { TeamBadge(team: leader, size: 48) }
                }
            }
            Button(leading ? "You lead · waiting" : "Bid \(Money.format(next))") {
                if store.careerUserBid() { Haptics.tap() } else { Haptics.warning() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(block != nil || leading)
            .opacity(block != nil || leading ? 0.5 : 1)
            if let block { Text(block).font(.caption.weight(.bold)).foregroundStyle(.orange) }
            if c.canUseRTM, let price = c.rtmPrice {
                Button("Right to Match: keep him at \(Money.format(price))") {
                    lastSale = store.careerUseRTM()
                    Haptics.success()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            Button(leading ? "Hammer ▶︎ (no one beat you)" : "Pass ▶︎") {
                lastSale = store.careerPassLot()
                Haptics.heavy()
            }
            .buttonStyle(SecondaryButtonStyle())
            HStack(spacing: DS.Space.sm) {
                Button("Sim rest · staff bid") { store.careerSimAuction(autoBid: true) }
                Spacer()
                Button("Sim rest · I'm done") { store.careerSimAuction(autoBid: false) }
            }
            .font(.footnote.weight(.semibold))
        }
    }

    private func saleText(_ c: Career, _ s: SaleLine, _ name: String) -> String {
        guard let cid = s.clubId, let club = c.club(cid) else { return "\(name) went unsold." }
        return "\(name) sold to \(cid == c.userClubId ? "YOU" : club.short) for \(Money.format(s.price))."
    }
}

/// Purse, squad and overseas room — shown in the auction and the market.
struct PurseStrip: View {
    let career: Career

    var body: some View {
        let c = career
        let squad = c.squad(c.userClubId)
        HStack(spacing: 0) {
            cell(Money.format(max(0, c.capRoom(c.userClubId))), "CAP ROOM")
            cell(Money.format(c.bank(c.userClubId)), "BANK")
            cell("\(squad.count)/\(c.tuning.maxSquad)", "SQUAD")
            cell("\(squad.filter(\.overseas).count)/\(c.tuning.maxOverseasSquad)", "OVERSEAS")
        }
        .padding(.vertical, DS.Space.sm)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surface))
    }

    private func cell(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.display(18)).lineLimit(1).minimumScaleFactor(0.6)
            Text(l).font(.display(9, weight: .heavy)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Market tab

struct CareerMarketTab: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.compactLandscape) private var landscape
    @State private var roleIndex = 0
    @State private var freeOnly = false
    @State private var sort: MarketSort = .rating
    @State private var slotIndex = 0
    @State private var bowlIndex = 0
    private static let slots: [BatSlot?] = [nil, .open, .top, .middle, .finish, .lower]
    private static let slotLabels = ["Any slot", "Openers", "Top order", "Middle order", "Finishers", "Lower order"]
    private static let bowls: [BowlType?] = [nil, .pace, .spin]
    private static let bowlLabels = ["Any bowling", "Pace", "Spin"]
    @State private var scope: StatScope = .season

    private static let roles: [Role?] = [nil, .BAT, .WK, .AR, .BOWL]
    private static let roleLabels = ["All", "BAT", "WK", "AR", "BOWL"]

    var body: some View {
        if let c = store.career {
            let season = c.seasonStatLines
            let list = c.marketPlayers(role: Self.roles[roleIndex], slot: Self.slots[slotIndex], bowlType: Self.bowls[bowlIndex],
                                       freeAgentsOnly: freeOnly, sort: sort, scope: scope)
            if landscape {
                // Device feedback: purse and filters stay put; only the player list scrolls.
                VStack(alignment: .leading, spacing: 6) {
                    header(c, count: list.count)
                    ScrollView { rows(c, list, season).padding(.bottom, DS.Space.sm) }
                }
                .padding(.top, 6)
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    header(c, count: list.count)
                    rows(c, list, season)
                }
            }
        }
    }

    /// Purse, market status, scouts, offers, filters and the column titles: compact, pinned.
    @ViewBuilder private func header(_ c: Career, count: Int) -> some View {
        PurseLine(career: c)
        HStack(spacing: 10) {
            Circle().fill(c.windowOpen ? Palette.accent : Palette.wicket).frame(width: 7, height: 7)
            Text(c.windowLabel).font(.system(size: 12 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted).lineLimit(1)
            Spacer(minLength: 6)
            if !c.market.offers.isEmpty || !c.market.listed.isEmpty {
                NavigationLink { CareerScreen(title: "Offers and your list") { OffersScreen() } } label: {
                    chip("tray.full", "\(c.market.offers.count) offer\(c.market.offers.count == 1 ? "" : "s") · \(c.market.listed.count) listed",
                         highlight: !c.market.offers.isEmpty)
                }
                .buttonStyle(.plain)
            }
            NavigationLink { ScoutingView() } label: {
                chip("binoculars", "Scouts \(c.scouting.scouts.count)/\(c.scoutCap) · \(c.scouting.reports.count) reports", highlight: false)
            }
            .buttonStyle(.plain)
        }
        HStack(spacing: 6) {
            ForEach(0..<Self.roleLabels.count, id: \.self) { i in
                Button { roleIndex = i } label: {
                    Text(Self.roleLabels[i]).font(.system(size: 12 * TextScale.factor, weight: .semibold))
                        .foregroundStyle(roleIndex == i ? Palette.ink : .white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(roleIndex == i ? Palette.accent : Palette.surface))
                }
                .buttonStyle(.plain)
            }
            menu(Self.slotLabels[slotIndex]) {
                ForEach(0..<Self.slots.count, id: \.self) { i in Button(Self.slotLabels[i]) { slotIndex = i } }
            }
            menu(Self.bowlLabels[bowlIndex]) {
                ForEach(0..<Self.bowls.count, id: \.self) { i in Button(Self.bowlLabels[i]) { bowlIndex = i } }
            }
            Button { freeOnly.toggle() } label: {
                Text("Free agents").font(.system(size: 12 * TextScale.factor, weight: .semibold))
                    .foregroundStyle(freeOnly ? Palette.ink : .white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(freeOnly ? Palette.accent : Palette.surface))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 4)
            menu("Sort: \(sort.label)") {
                ForEach(MarketSort.allCases) { s in Button(s.label) { sort = s } }
            }
            menu(scope == .season ? "Season" : "All-time") {
                Button("Season") { scope = .season }
                Button("All-time") { scope = .allTime }
            }
        }
        MarketColumns(landscape: landscape, statTitle: sort.isStat ? sort.label : nil, count: count)
    }

    @ViewBuilder private func rows(_ c: Career, _ list: [CareerPlayer], _ season: [String: StatLine]) -> some View {
        LazyVStack(spacing: 4) {
            ForEach(list) { p in
                NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                    MarketRow(career: c, player: p, scope: scope, season: season, sort: sort, landscape: landscape)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func chip(_ icon: String, _ text: String, highlight: Bool) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12 * TextScale.factor, weight: .semibold))
            .foregroundStyle(highlight ? Palette.ink : Palette.accent)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(highlight ? Palette.accent : Palette.surface))
            .lineLimit(1)
    }

    private func menu<C: View>(_ title: String, @ViewBuilder _ items: () -> C) -> some View {
        Menu { items() } label: {
            HStack(spacing: 3) {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9 * TextScale.factor, weight: .bold))
            }
            .font(.system(size: 12 * TextScale.factor, weight: .semibold))
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Palette.surface))
        }
    }
}

/// Purse, bank, squad and overseas on one short line (the Transfers header).
struct PurseLine: View {
    let career: Career

    var body: some View {
        let c = career
        let squad = c.squad(c.userClubId)
        HStack(spacing: 0) {
            cell(Money.format(max(0, c.capRoom(c.userClubId))), "cap room")
            cell(Money.format(c.bank(c.userClubId)), "bank")
            cell("\(squad.count)/\(c.tuning.maxSquad)", "squad")
            cell("\(squad.filter(\.overseas).count)/\(c.tuning.maxOverseasSquad)", "overseas")
        }
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surface))
    }

    private func cell(_ v: String, _ l: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(v).font(.score(15)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(l).font(.system(size: 11 * TextScale.factor, weight: .medium)).foregroundStyle(Palette.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Market column widths, shared by the header and the rows.
enum MarketCol {
    static let ovr: CGFloat = 36
    static let club: CGFloat = 46
    static let age: CGFloat = 30
    static let stat: CGFloat = 56
    static let price: CGFloat = 78
}

/// Column titles above the market list.
struct MarketColumns: View {
    let landscape: Bool
    let statTitle: String?
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("OVR").frame(width: MarketCol.ovr, alignment: .center)
            Text("PLAYER · \(count)").frame(maxWidth: .infinity, alignment: .leading)
            if landscape {
                Text("CLUB").frame(width: MarketCol.club, alignment: .leading)
                Text("AGE").frame(width: MarketCol.age, alignment: .trailing)
                if let statTitle { Text(statTitle.uppercased()).frame(width: MarketCol.stat, alignment: .trailing).lineLimit(1) }
            }
            Text("PRICE").frame(width: MarketCol.price, alignment: .trailing)
            if landscape { Text("ROLE").frame(maxWidth: .infinity, alignment: .leading) }
        }
        .font(.system(size: 10 * TextScale.factor, weight: .heavy))
        .foregroundStyle(Palette.muted)
        .padding(.horizontal, 10)
    }
}

/// One player in the market: OVR, name, (club, age, stat), price, role. Each row its own card.
struct MarketRow: View {
    let career: Career
    let player: CareerPlayer
    var scope: StatScope = .season
    var season: [String: StatLine] = [:]
    var sort: MarketSort = .rating
    var landscape = false

    var body: some View {
        let c = career
        let p = player
        let club = p.clubId.flatMap { c.club($0) }
        HStack(spacing: 8) {
            Text("\(p.rating)").font(.score(15)).foregroundStyle(strengthColor(p.rating))
                .frame(width: MarketCol.ovr, alignment: .center)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(p.name).font(.system(size: 14 * TextScale.factor, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    if p.overseas { Image(systemName: "airplane").font(.system(size: 9 * TextScale.factor)).foregroundStyle(Palette.muted) }
                }
                if !landscape {
                    Text("\(p.roleDescription) · \(club?.short ?? "Free") · \(p.age(in: c.year))")
                        .font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if landscape {
                Text(club?.short ?? "Free").font(.system(size: 12 * TextScale.factor, weight: .semibold))
                    .foregroundStyle(club == nil ? Palette.accent : Palette.muted)
                    .frame(width: MarketCol.club, alignment: .leading)
                Text("\(p.age(in: c.year))").font(.score(13)).foregroundStyle(Palette.muted)
                    .frame(width: MarketCol.age, alignment: .trailing)
                if sort.isStat {
                    Text(statValue(c)).font(.score(13)).foregroundStyle(Palette.accent)
                        .frame(width: MarketCol.stat, alignment: .trailing)
                }
            }
            Text(club == nil ? "Free" : Money.format(c.askingPrice(p)))
                .font(.score(13)).foregroundStyle(club == nil ? Palette.accent : .white)
                .frame(width: MarketCol.price, alignment: .trailing)
            if landscape {
                Text(p.roleDescription).font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted)
                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, landscape ? 6 : 7)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Palette.surface))
        .contentShape(Rectangle())
    }

    private func statValue(_ c: Career) -> String {
        let s = c.statLine(player.id, scope: scope, season: season)
        switch sort {
        case .runs: return "\(s.runs)"
        case .wickets: return "\(s.wickets)"
        case .sixes: return "\(s.sixes)"
        case .strikeRate: return s.balls > 0 ? String(format: "%.1f", s.strikeRate) : "–"
        case .economy: return s.ballsBowled > 0 ? String(format: "%.2f", s.economy) : "–"
        default: return ""
        }
    }
}

/// Offers for your players and your own transfer list (moved off the Transfers header).
struct OffersScreen: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        if let c = store.career {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                SectionLabel(text: "Offers for your players")
                if c.market.offers.isEmpty {
                    Text("No offers right now.").font(.subheadline).foregroundStyle(Palette.muted)
                }
                ForEach(c.market.offers) { o in OfferRow(career: c, offer: o) }
                SectionLabel(text: "Your transfer list")
                if c.market.listed.isEmpty {
                    Text("Nobody listed. List a player from his page.").font(.subheadline).foregroundStyle(Palette.muted)
                }
                ForEach(c.market.listed.keys.sorted(), id: \.self) { id in
                    HStack {
                        Text(c.players[id]?.name ?? id).font(.subheadline)
                        Spacer()
                        Text(Money.format(c.market.listed[id] ?? 0)).font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                        Button("Unlist") { store.careerUnlist(id) }.font(.caption.weight(.bold))
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Palette.surface))
                }
            }
        }
    }
}

struct OfferRow: View {
    @EnvironmentObject var store: GameStore
    let career: Career
    let offer: TransferOffer

    var body: some View {
        let c = career
        AppCard(padding: DS.Space.md) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if let buyer = c.club(offer.fromClub) { TeamBadge(team: buyer, size: 28) }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(c.players[offer.playerId]?.name ?? offer.playerId).font(.subheadline.weight(.bold))
                        Text("\(c.club(offer.fromClub)?.name ?? "") bid \(Money.format(offer.fee))")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                }
                HStack(spacing: DS.Space.sm) {
                    Button("Accept") {
                        if store.careerAcceptOffer(offer.id) { Haptics.success() } else { Haptics.warning() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!c.windowOpen)
                    Button("Reject") { store.careerRejectOffer(offer.id) }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }
}

// MARK: - Transfer actions on a player profile

struct TransferActions: View {
    @EnvironmentObject var store: GameStore
    let playerId: String
    @State private var fee = 0
    @State private var wage = 0
    @State private var loaded = false
    @State private var message: String? = nil
    @State private var confirmRelease = false

    var body: some View {
        if let c = store.career, let p = c.players[playerId], !p.retired {
            AppCard {
                VStack(alignment: .leading, spacing: DS.Space.md) {
                    if let k = p.contract {
                        Text("Contract: \(Money.format(k.wage)) a season, until the \(String(k.until)) mega auction")
                            .font(.subheadline)
                    } else {
                        Text("Free agent").font(.subheadline.weight(.bold)).foregroundStyle(Palette.accent)
                    }
                    if p.clubId == c.userClubId {
                        own(c, p)
                    } else {
                        bid(c, p)
                    }
                    if let message {
                        Text(message).font(.footnote.weight(.semibold)).foregroundStyle(Palette.accent)
                    }
                    if !c.windowOpen {
                        Text(c.windowLabel).font(.caption).foregroundStyle(Palette.muted)
                    }
                }
            }
            .onAppear {
                if !loaded {
                    fee = c.askingPrice(p)
                    wage = c.userWageDemand(p)
                    loaded = true
                }
            }
            .confirmationDialog("Release \(p.name)? You pay half his wage (\(Money.format((p.contract?.wage ?? 0) / 2))) as compensation.",
                                isPresented: $confirmRelease, titleVisibility: .visible) {
                Button("Release", role: .destructive) {
                    if store.careerRelease(playerId) { message = "\(p.name) released." }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    @ViewBuilder private func own(_ c: Career, _ p: CareerPlayer) -> some View {
        if let asking = c.market.listed[p.id] {
            Text("On your transfer list at \(Money.format(asking)).").font(.subheadline)
            Button("Take off the list") { store.careerUnlist(p.id) }
                .buttonStyle(SecondaryButtonStyle())
        } else {
            Button("List for transfer at \(Money.format(p.value(in: c.year)))") {
                store.careerList(p.id, asking: p.value(in: c.year))
                message = c.windowOpen ? "Listed. Check the Market tab for bids." : "Listed. Bids arrive when the window opens."
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        Button("Release…") { confirmRelease = true }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.wicket)
            .disabled(!c.windowOpen)
    }

    @ViewBuilder private func bid(_ c: Career, _ p: CareerPlayer) -> some View {
        let demand = c.userWageDemand(p)
        if p.clubId != nil {
            Text("Owner: \(p.clubId.flatMap { c.club($0)?.name } ?? "") · asking \(Money.format(c.askingPrice(p))) · wants \(Money.format(demand)) a season")
                .font(.caption).foregroundStyle(Palette.muted)
            Stepper("Fee \(Money.format(fee))", value: $fee, in: 0...50_000, step: fee < 500 ? 25 : 100)
        } else {
            Text("Free agent · wants \(Money.format(demand)) a season").font(.caption).foregroundStyle(Palette.muted)
        }
        Text("Form: \(Career.formLabel(p.form)) (\(CareerText.form(p.form)))\(c.averageRating(p.id).map { " · match rating \(String(format: "%.2f", $0))" } ?? "")")
            .font(.caption.weight(.semibold)).foregroundStyle(CareerText.formColor(p.form))
        Stepper("Wage \(Money.format(wage))", value: $wage, in: c.tuning.minWage...c.tuning.salaryCap, step: wage < 200 ? 5 : 25)
        MoodBar(value: c.offerMood(p, wage: wage), talksLeft: max(0, 3 - c.market.talks[p.id, default: 0]))
        Button("Pay asking price: \(p.clubId == nil ? "" : Money.format(c.askingPrice(p)) + " + ")\(Money.format(demand))/yr") {
            fee = c.askingPrice(p)
            wage = demand
            let outcome = store.careerMakeOffer(playerId: p.id, fee: p.clubId == nil ? 0 : fee, wage: wage)
            message = outcome.message
            if case .accepted = outcome { Haptics.success() } else { Haptics.warning() }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!c.windowOpen)
        Text("Or negotiate:").font(.caption).foregroundStyle(Palette.muted)
        Button(p.clubId == nil ? "Offer contract" : "Make offer") {
            let outcome = store.careerMakeOffer(playerId: p.id, fee: p.clubId == nil ? 0 : fee, wage: wage)
            message = outcome.message
            switch outcome {
            case .accepted: Haptics.success()
            case .counter(let f, let w, _):
                fee = f
                wage = w
                Haptics.tap()
            case .rejected: Haptics.warning()
            }
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(!c.windowOpen)
    }
}

// MARK: - Club finances

struct FinanceCard: View {
    let career: Career

    var body: some View {
        let c = career
        let ledger = c.clubs.isEmpty || c.userClubId >= c.finance.count ? [] : Array(c.finance[c.userClubId].ledger.prefix(12))
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Finances")
            PurseStrip(career: c)
            Text("Wages \(Money.format(c.payroll(c.userClubId))) of the \(Money.format(c.tuning.salaryCap)) salary cap. Ticket sales (stadium \(c.stadiumCapacity.formatted()) seats) come in after every home match and merchandise every week; central revenue and prize money after the final.")
                .font(.caption).foregroundStyle(Palette.muted)
            if !ledger.isEmpty {
                AppCard(padding: DS.Space.md) {
                    VStack(spacing: 6) {
                        ForEach(Array(ledger.enumerated()), id: \.offset) { _, e in
                            HStack {
                                Text(e.text).font(.caption).lineLimit(1)
                                Spacer()
                                Text((e.amount >= 0 ? "+" : "−") + Money.format(abs(e.amount)))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(e.amount >= 0 ? Palette.accent : Palette.wicket)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Negotiation: how happy the player would be with the offer on the table, and talks left.
struct MoodBar: View {
    let value: Double
    let talksLeft: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "hand.thumbsdown").foregroundStyle(Palette.wicket)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.stroke)
                        Capsule().fill(value >= 1 ? Palette.accent : (value >= 0.5 ? Color.orange : Palette.wicket))
                            .frame(width: max(6, g.size.width * value))
                    }
                }
                .frame(height: 8)
                Image(systemName: "hand.thumbsup").foregroundStyle(Palette.accent)
            }
            .font(.system(size: 14 * TextScale.factor, weight: .semibold))
            Text("\(value >= 1 ? "He'd sign this." : (value >= 0.5 ? "Close: he may counter." : "Too low: he'll walk away.")) · talks left \(talksLeft)/3")
                .font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
        }
    }
}
