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
            .listRowBackground(Palette.surface)

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
            .listRowBackground(Palette.surface)
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
                    if let limit = c.auctionTopRivalLimit {
                        Text("🦈 Top rival limit: \(limit > 0 ? Money.format(limit) : "nobody interested")")
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
    @State private var roleIndex = 0
    @State private var freeOnly = false

    private static let roles: [Role?] = [nil, .BAT, .WK, .AR, .BOWL]

    var body: some View {
        if let c = store.career {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                PurseStrip(career: c)
                Text((c.windowOpen ? "🟢 " : "🔴 ") + c.windowLabel)
                    .font(.subheadline.weight(.semibold))
                NavigationLink { ScoutingView() } label: {
                    SquadAction(icon: "binoculars", text: "Scouts \(c.scouting.scouts.count)/\(c.scoutCap) · \(c.scouting.reports.count) reports")
                }
                .buttonStyle(.plain)

                if !c.market.offers.isEmpty {
                    SectionLabel(text: "Offers for your players")
                    VStack(spacing: DS.Space.sm) {
                        ForEach(c.market.offers) { o in
                            OfferRow(career: c, offer: o)
                        }
                    }
                }

                if !c.market.listed.isEmpty {
                    SectionLabel(text: "Your transfer list")
                    AppCard(padding: DS.Space.md) {
                        VStack(spacing: 8) {
                            ForEach(c.market.listed.keys.sorted(), id: \.self) { id in
                                HStack {
                                    Text(c.players[id]?.name ?? id).font(.subheadline)
                                    Spacer()
                                    Text(Money.format(c.market.listed[id] ?? 0)).font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                                    Button("Unlist") { store.careerUnlist(id) }.font(.caption.weight(.bold))
                                }
                            }
                        }
                    }
                }

                SectionLabel(text: "Find players")
                Picker("Role", selection: $roleIndex) {
                    Text("All").tag(0)
                    Text("BAT").tag(1)
                    Text("WK").tag(2)
                    Text("AR").tag(3)
                    Text("BOWL").tag(4)
                }
                .pickerStyle(.segmented)
                Toggle("Free agents only (no fee)", isOn: $freeOnly)
                    .font(.subheadline)
                let list = c.marketPlayers(role: Self.roles[roleIndex], freeAgentsOnly: freeOnly, limit: 50)
                VStack(spacing: DS.Space.sm) {
                    ForEach(list) { p in
                        NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                            MarketRow(career: c, player: p)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct MarketRow: View {
    let career: Career
    let player: CareerPlayer

    var body: some View {
        let c = career
        let club = player.clubId.flatMap { c.club($0) }
        VStack(alignment: .leading, spacing: 4) {
            CareerPlayerRow(player: player, year: c.year)
            HStack(spacing: 6) {
                if let club { TeamBadge(team: club, size: 18) }
                Text(club?.short ?? "FREE AGENT").font(.caption2.weight(.bold))
                    .foregroundStyle(club == nil ? Palette.accent : Palette.muted)
                Spacer()
                Text(club == nil ? "No fee" : "Fee ~\(Money.format(c.askingPrice(player)))")
                    .font(.caption2.monospacedDigit()).foregroundStyle(Palette.muted)
                Text("Wage ~\(Money.format(c.wageDemand(player)))")
                    .font(.caption2.monospacedDigit()).foregroundStyle(Palette.muted)
                Text("POT \(c.potentialLabel(player))")
                    .font(.caption2.weight(.bold).monospacedDigit()).foregroundStyle(Palette.four)
            }
        }
        .padding(DS.Space.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surface))
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
                    wage = c.wageDemand(p)
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
        if p.clubId != nil {
            Text("Asking about \(Money.format(c.askingPrice(p))) · wants \(Money.format(c.wageDemand(p))) a season")
                .font(.caption).foregroundStyle(Palette.muted)
            Stepper("Fee \(Money.format(fee))", value: $fee, in: 0...50_000, step: fee < 500 ? 25 : 100)
        } else {
            Text("Wants \(Money.format(c.wageDemand(p))) a season").font(.caption).foregroundStyle(Palette.muted)
        }
        Stepper("Wage \(Money.format(wage))", value: $wage, in: c.tuning.minWage...c.tuning.salaryCap, step: wage < 200 ? 5 : 25)
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
        .buttonStyle(PrimaryButtonStyle())
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
            Text("Wages \(Money.format(c.payroll(c.userClubId))) of the \(Money.format(c.tuning.salaryCap)) salary cap. The bank pays transfer fees; revenue and prize money arrive after the final.")
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
