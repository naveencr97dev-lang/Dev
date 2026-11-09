import Foundation

// MARK: - Types

/// IPL-style contract: the wage is the yearly salary (the auction price), and every contract runs to
/// the next mega auction.
struct Contract: Codable, Hashable {
    var wage: Int
    /// First season the player is no longer contracted (a mega-auction year).
    var until: Int
}

struct LedgerEntry: Codable, Hashable {
    let year: Int
    let day: Int
    let text: String
    let amount: Int
}

struct ClubFinance: Codable, Hashable {
    /// Cash for transfer fees and compensation (wages count against the salary cap instead).
    var bank: Int
    var ledger: [LedgerEntry] = []
}

/// An AI club's bid for one of the user's players.
struct TransferOffer: Codable, Hashable, Identifiable {
    let id: Int
    let playerId: String
    let fromClub: Int
    let fee: Int
}

struct MarketState: Codable, Hashable {
    /// The user's transfer list: player id → asking price.
    var listed: [String: Int] = [:]
    var offers: [TransferOffer] = []
    /// Negotiation attempts per player this window.
    var talks: [String: Int] = [:]
    var nextOfferId = 1
    /// Windows in which the AI clubs already did their business ("2028-pre", "2028-mid").
    var aiWindowsDone: [String] = []
}

enum OffseasonStage: String, Codable {
    case retention, auction, window
}

struct SaleLine: Codable, Hashable {
    let playerId: String
    let clubId: Int?
    let price: Int
}

/// Turn-based auction: the user bids, the AI replies at once; passing lets the AI settle the lot.
struct CareerAuctionState: Codable, Hashable {
    var queue: [String] = []
    var index = 0
    var bid: Int? = nil
    var leader: Int? = nil
    /// Each AI club's limit for the current lot, by club index (0 = not interested).
    var aiMax: [Int] = []
    var sales: [SaleLine] = []
    var finished = false
    /// The user handed bidding to their staff: their club bids like an AI club.
    var userAuto = false

    var currentId: String? { finished || index >= queue.count ? nil : queue[index] }
    var remaining: Int { max(0, queue.count - index) }
}

struct OffseasonState: Codable, Hashable {
    var stage: OffseasonStage
    var mega: Bool
    var auction = CareerAuctionState()
}

enum OfferOutcome: Hashable {
    case accepted(String)
    case counter(fee: Int, wage: Int, String)
    case rejected(String)

    var message: String {
        switch self {
        case .accepted(let m), .rejected(let m): return m
        case .counter(_, _, let m): return m
        }
    }
}

// MARK: - Money and contracts

extension Career {
    func payroll(_ clubId: Int) -> Int { squad(clubId).reduce(0) { $0 + ($1.contract?.wage ?? 0) } }
    func capRoom(_ clubId: Int) -> Int { tuning.salaryCap - payroll(clubId) }
    func bank(_ clubId: Int) -> Int { clubId < finance.count ? finance[clubId].bank : 0 }

    mutating func post(_ clubId: Int, _ text: String, _ amount: Int) {
        guard clubId < finance.count else { return }
        finance[clubId].bank += amount
        finance[clubId].ledger.insert(LedgerEntry(year: year, day: currentDay, text: text, amount: amount), at: 0)
        if finance[clubId].ledger.count > 40 { finance[clubId].ledger.removeLast(finance[clubId].ledger.count - 40) }
    }

    func isMegaYear(_ y: Int) -> Bool { y > startYear && (y - startYear) % tuning.megaAuctionEvery == 0 }

    /// The first mega-auction season after `y`.
    func nextMegaYear(after y: Int) -> Int {
        let n = tuning.megaAuctionEvery
        return startYear + ((y - startYear) / n + 1) * n
    }

    static func round5(_ v: Double) -> Int { Int((v / 5).rounded()) * 5 }

    /// What a player asks to be paid per season.
    func wageDemand(_ p: CareerPlayer) -> Int {
        let current = p.contract?.wage ?? 0
        return max(tuning.minWage, Career.round5(Double(p.value(in: year))), Career.round5(Double(current) * 1.1))
    }

    /// Draft squads get value-based wages, scaled to fit under the cap.
    mutating func assignDraftContracts() {
        for club in clubs {
            let squad = club.squad.compactMap { players[$0] }
            let wages = squad.map { Double(max(tuning.minWage, $0.value(in: year))) }
            let total = wages.reduce(0, +)
            let scale = min(1, Double(tuning.salaryCap) * 0.9 / max(1, total))
            let until = nextMegaYear(after: year)
            let minWage = tuning.minWage
            for (p, w) in zip(squad, wages) {
                players[p.id]?.contract = Contract(wage: max(minWage, Career.round5(w * scale)), until: until)
            }
        }
    }

    /// After loading an older save: give contracted players a contract and every club a bank.
    mutating func repairContracts() {
        while finance.count < clubs.count { finance.append(ClubFinance(bank: tuning.startingBank)) }
        let missing = players.values.contains { $0.clubId != nil && $0.contract == nil && !$0.retired }
        if missing { assignDraftContracts() }
    }

    mutating func payPrizeMoney() {
        let final = results.first { $0.stage == .final }
        let q2 = results.first { $0.stage == .qualifier2 }
        let elim = results.first { $0.stage == .eliminator }
        let places = [final?.winnerId, final?.loserId, q2?.loserId, elim?.loserId]
        for club in clubs {
            post(club.id, "Season \(year) central revenue", tuning.seasonRevenue)
            if let place = places.firstIndex(where: { $0 == club.id }), place < tuning.prizeMoney.count {
                post(club.id, "Prize money (\(["champions", "runners-up", "Qualifier 2", "Eliminator"][place]))", tuning.prizeMoney[place])
            }
        }
    }

    // MARK: - Off-season

    /// Season over → age, develop, retire, youth intake; then retentions (mega year) or the mini auction.
    @discardableResult
    mutating func beginOffseason() -> RolloverReport {
        guard phase == .seasonEnd else { return RolloverReport() }
        settleSeasonAccounts()
        facilityTick(weeks: 4)
        var report = ageAndRefreshPool()
        market = MarketState(nextOfferId: market.nextOfferId, aiWindowsDone: market.aiWindowsDone)
        payScouts()
        refreshScoutCandidates()
        academy = academy.filter { players[$0] != nil && players[$0]?.retired == false }
        generateJobOffers()
        let kids = academyIntake()
        if !kids.isEmpty {
            addNews(.squad, "🎓 Academy intake: \(kids.joined(separator: ", ")).")
            report.academy = kids
        }
        let mega = isMegaYear(year)
        offseason = OffseasonState(stage: mega ? .retention : .auction, mega: mega)
        phase = .offseason
        if mega {
            addNews(.squad, "Mega auction year! Every contract has ended: keep up to \(tuning.maxRetentions) players, the rest go into the auction.")
        } else {
            prepareAuction()
            addNews(.squad, "Mini auction: \(offseason?.auction.queue.count ?? 0) players go under the hammer.")
        }
        return report
    }

    /// How much a club wants to keep a player at a mega auction.
    func keepScore(_ p: CareerPlayer) -> Double {
        let age = p.age(in: year)
        return Double(p.rating) + (age <= 23 ? Double(max(0, p.potential - p.rating)) * 0.5 : 0) - (age >= 33 ? 6 : 0)
    }

    /// Retention price: what the player would ask on the open market.
    func retentionWage(_ p: CareerPlayer) -> Int { max(tuning.minWage, Career.round5(Double(p.value(in: year)))) }

    /// The user's best keepers (used for auto-play and as the default selection).
    func suggestedRetentions() -> [String] {
        Array(squad(userClubId).sorted { keepScore($0) > keepScore($1) }.prefix(4).map(\.id))
    }

    mutating func confirmRetention(userKeeps: [String]) {
        guard phase == .offseason, offseason?.stage == .retention else { return }
        for ci in clubs.indices {
            let club = clubs[ci]
            let ranked = club.squad.compactMap { players[$0] }.sorted { keepScore($0) > keepScore($1) || (keepScore($0) == keepScore($1) && $0.id < $1.id) }
            var keep: [CareerPlayer]
            if club.id == userClubId {
                keep = ranked.filter { userKeeps.contains($0.id) }
            } else {
                let n = Int(2 + club.personality * 2.5)
                keep = Array(ranked.filter { $0.rating >= 74 || ($0.age(in: year) <= 23 && $0.potential >= 82) }.prefix(n))
            }
            keep = Array(keep.prefix(tuning.maxRetentions))
            // Retentions can't eat more than 60% of the cap.
            var spent = 0
            keep = keep.filter { p in
                let w = retentionWage(p)
                guard spent + w <= tuning.salaryCap * 6 / 10 else { return false }
                spent += w
                return true
            }
            let keepIds = Set(keep.map(\.id))
            for id in club.squad {
                if keepIds.contains(id), let p = players[id] {
                    let contract = Contract(wage: retentionWage(p), until: nextMegaYear(after: year))
                    players[id]?.contract = contract
                } else {
                    players[id]?.clubId = nil
                    players[id]?.contract = nil
                }
            }
            clubs[ci].squad = club.squad.filter { keepIds.contains($0) }
            clubs[ci].xi = club.xi.filter { keepIds.contains($0) }
            clubs[ci].bowlingOrder = []
        }
        let names = squad(userClubId).map(\.name)
        addNews(.squad, names.isEmpty ? "You kept nobody — a full rebuild at the auction." : "Retained: \(names.joined(separator: ", ")).")
        offseason?.stage = .auction
        prepareAuction()
    }

    // MARK: Auction

    func increment(after bid: Int) -> Int { bid < 100 ? 10 : (bid < 500 ? 25 : (bid < 1000 ? 50 : 100)) }

    /// Auction Shark perk: the highest rival limit on the current lot.
    var auctionTopRivalLimit: Int? {
        guard manager.has(.auctionShark), let a = offseason?.auction, a.currentId != nil else { return nil }
        return clubs.indices.filter { clubs[$0].id != userClubId }.map { a.aiMax[$0] }.max()
    }

    var auctionNextBid: Int? {
        guard let a = offseason?.auction, let id = a.currentId, let p = players[id] else { return nil }
        return a.bid.map { $0 + increment(after: $0) } ?? p.basePrice(in: year)
    }

    /// Money a club must keep back to reach the minimum squad at minimum wage.
    func auctionReserve(_ clubId: Int) -> Int {
        max(0, tuning.minSquad - squad(clubId).count - 1) * tuning.minWage
    }

    func canAfford(_ clubId: Int, _ p: CareerPlayer, amount: Int) -> Bool {
        let s = squad(clubId)
        guard s.count < tuning.maxSquad else { return false }
        if p.overseas && s.filter(\.overseas).count >= tuning.maxOverseasSquad { return false }
        return amount <= capRoom(clubId) - auctionReserve(clubId)
    }

    /// Why the user can't bid (nil = can).
    func userBidBlock(_ p: CareerPlayer, amount: Int) -> String? {
        let s = squad(userClubId)
        if s.count >= tuning.maxSquad { return "Squad full (\(tuning.maxSquad))" }
        if p.overseas && s.filter(\.overseas).count >= tuning.maxOverseasSquad { return "Overseas slots full" }
        if amount > capRoom(userClubId) - auctionReserve(userClubId) { return "Not enough purse left" }
        return nil
    }

    mutating func prepareAuction() {
        let pool = freeAgents.sorted { $0.value(in: year) != $1.value(in: year) ? $0.value(in: year) > $1.value(in: year) : $0.id < $1.id }
        let open = clubs.reduce(0) { $0 + max(0, tuning.auctionSquadTarget - $1.squad.count) }
        let queue = pool.prefix(min(pool.count, open + 25)).map(\.id)
        offseason?.auction = CareerAuctionState(queue: Array(queue))
        openLot()
    }

    private mutating func openLot() {
        guard var a = offseason?.auction else { return }
        a.bid = nil
        a.leader = nil
        guard let id = a.currentId, let p = players[id] else {
            a.finished = true
            offseason?.auction = a
            return
        }
        let auto = a.userAuto
        a.aiMax = clubs.indices.map { ci in clubs[ci].id == userClubId && !auto ? 0 : aiValuation(ci, p) }
        offseason?.auction = a
    }

    private mutating func aiValuation(_ ci: Int, _ p: CareerPlayer) -> Int {
        let club = clubs[ci]
        let base = p.basePrice(in: year)
        guard canAfford(club.id, p, amount: base) else { return 0 }
        let squad = self.squad(club.id)
        let roles: [Role] = [.WK, .BAT, .AR, .BOWL]
        let i = roles.firstIndex(of: p.role) ?? 3
        let deficit = tuning.squadShape[i] - squad.filter { $0.role == p.role }.count
        var need = deficit > 0 ? 1.35 : (deficit <= -2 ? 0.6 : 1.0)
        if squad.count < tuning.minSquad { need *= 1.15 }
        if squad.count >= tuning.auctionSquadTarget { need *= 0.5 }
        // Personality nudges bids (±10%) without letting one club buy every star.
        let temper = 1 + (club.personality - 1) * 0.5
        let v = Double(p.value(in: year)) * need * temper * rng.range(0.8, 1.2)
        let limit = min(Int(v), capRoom(club.id) - auctionReserve(club.id))
        return limit >= base ? limit : 0
    }

    /// The user raises. The AI answers straight away. Returns false if the user can't bid.
    @discardableResult
    mutating func userBid() -> Bool {
        guard phase == .offseason, let next = auctionNextBid, let id = offseason?.auction.currentId, let p = players[id],
              userBidBlock(p, amount: next) == nil, offseason?.auction.leader != userClubId else { return false }
        offseason?.auction.bid = next
        offseason?.auction.leader = userClubId
        aiRespond()
        return true
    }

    private mutating func aiRespond() {
        guard let a = offseason?.auction, let next = auctionNextBid else { return }
        var best: Int? = nil
        for ci in clubs.indices where a.aiMax[ci] >= next {
            if best == nil || a.aiMax[ci] > a.aiMax[best!] { best = ci }
        }
        if let b = best {
            offseason?.auction.bid = next
            offseason?.auction.leader = clubs[b].id
        }
    }

    /// The user stops bidding on this lot: the AI clubs settle it. Returns the sale.
    @discardableResult
    mutating func passLot() -> SaleLine? {
        guard phase == .offseason, var a = offseason?.auction, let id = a.currentId, let p = players[id] else { return nil }
        let base = p.basePrice(in: year)
        var winner: Int? = nil
        var price = 0
        if a.leader == userClubId, let bid = a.bid, !a.userAuto {
            winner = userClubId
            price = bid
        } else {
            let floor = a.bid ?? base
            let interested = clubs.indices.filter { a.aiMax[$0] >= floor }.sorted { a.aiMax[$0] != a.aiMax[$1] ? a.aiMax[$0] > a.aiMax[$1] : $0 < $1 }
            if let top = interested.first {
                winner = clubs[top].id
                if interested.count > 1 {
                    let second = a.aiMax[interested[1]]
                    price = min(a.aiMax[top], second + increment(after: second))
                } else {
                    price = floor
                }
                price = max(price, floor)
            }
        }
        let sale = SaleLine(playerId: id, clubId: winner, price: price)
        a.sales.append(sale)
        a.index += 1
        offseason?.auction = a
        if let w = winner, let ci = clubs.firstIndex(where: { $0.id == w }) {
            sign(id, to: ci, wage: price)
            if w == userClubId { addNews(.squad, "🔨 \(a.userAuto ? "Your staff bought" : "You bought") \(p.name) for \(Money.format(price)).") }
        }
        openLot()
        if offseason?.auction.finished == true { afterAuction() }
        return sale
    }

    /// Settles every remaining lot. With `autoBid`, the user's staff bid for them like an AI club.
    mutating func simRestOfAuction(autoBid: Bool = false) {
        if autoBid, offseason?.auction.finished == false {
            offseason?.auction.userAuto = true
            openLot()
        }
        var guardCount = 0
        while phase == .offseason, offseason?.stage == .auction, offseason?.auction.finished == false, guardCount < 2000 {
            passLot()
            guardCount += 1
        }
        if offseason?.stage == .auction { afterAuction() }
    }

    private mutating func afterAuction() {
        guard offseason?.stage == .auction else { return }
        offseason?.auction.finished = true
        offseason?.stage = .window
        aiWindowActivity(key: "\(year)-pre")
        unsolicitedOffers()
        addNews(.squad, "Auction over. The transfer window is open until the season starts.")
    }

    /// Off-season done: fill squads, pick XIs, start the league.
    @discardableResult
    mutating func startSeasonFromOffseason() -> [String] {
        guard phase == .offseason else { return [] }
        if offseason?.stage == .retention { confirmRetention(userKeeps: suggestedRetentions()) }
        if offseason?.stage == .auction { simRestOfAuction() }
        aiWindowActivity(key: "\(year)-pre")
        let signed = topUpSquads()
        for i in clubs.indices where clubs[i].isCPU || !xiIssues(clubs[i].id).isEmpty {
            autoPickXI(clubIndex: i)
        }
        offseason = nil
        market.offers = []
        market.talks = [:]
        startSeason()
        addNews(.season, "Season \(year) begins!")
        return signed
    }

    // MARK: - Transfer market

    /// Windows: the off-season (after the auction), the first two league rounds, and the
    /// mid-season break before round 25.
    var windowOpen: Bool {
        if phase == .offseason { return offseason?.stage == .window }
        guard phase == .season, let f = nextFixture, let r = round(of: f) else { return false }
        return r <= 2 || r == 25
    }

    var windowLabel: String {
        if windowOpen { return phase == .offseason ? "Window open until the season starts" : "Window open this round" }
        return "Window closed · opens before round 25 and in the off-season"
    }

    /// What an AI club wants for a player (free agents cost no fee).
    func askingPrice(_ p: CareerPlayer) -> Int {
        guard let cid = p.clubId, let club = club(cid) else { return 0 }
        let mult = club.xi.contains(p.id) ? tuning.askXIMultiplier : tuning.askBenchMultiplier
        return Career.round5(Double(p.value(in: year)) * mult)
    }

    /// Players the user could sign, best first.
    func marketPlayers(role: Role? = nil, freeAgentsOnly: Bool = false, limit: Int = 80) -> [CareerPlayer] {
        players.values
            .filter { !$0.retired && $0.clubId != userClubId && (role == nil || $0.role == role) && (!freeAgentsOnly || $0.clubId == nil) }
            .sorted { $0.rating != $1.rating ? $0.rating > $1.rating : $0.id < $1.id }
            .prefix(limit).map { $0 }
    }

    /// The user bids for a player: fee to their club (none for free agents) and a wage.
    mutating func makeOffer(playerId: String, fee: Int, wage: Int) -> OfferOutcome {
        guard windowOpen else { return .rejected("The transfer window is closed.") }
        guard let p = players[playerId], !p.retired, p.clubId != userClubId else { return .rejected("Not available.") }
        let mine = squad(userClubId)
        if mine.count >= tuning.maxSquad { return .rejected("Your squad is full (\(tuning.maxSquad)). Release or sell someone first.") }
        if p.overseas && mine.filter(\.overseas).count >= tuning.maxOverseasSquad { return .rejected("No overseas slots left.") }
        if wage > capRoom(userClubId) { return .rejected("That wage takes you over the salary cap (room \(Money.format(capRoom(userClubId)))).") }
        if fee > bank(userClubId) { return .rejected("You only have \(Money.format(bank(userClubId))) in the bank.") }
        let used = market.talks[playerId, default: 0]
        if used >= 3 { return .rejected("They've stopped talking to you until the next window.") }
        market.talks[playerId] = used + 1

        let demand = Career.round5(Double(wageDemand(p)) * (manager.has(.negotiator) ? 0.9 : 1))
        let accept = manager.has(.starMagnet) ? 0.8 : 1.0
        var counterFee = fee
        if let cid = p.clubId, let seller = club(cid) {
            let ask = askingPrice(p)
            if Double(fee) < Double(ask) * tuning.counterThreshold { return .rejected("\(seller.short) turned it down. They value him around \(Money.format(ask)).") }
            if fee < ask { counterFee = ask }
        }
        if Double(wage) < Double(demand) * 0.85 { return .rejected("\(p.name) isn't interested at that wage. He wants about \(Money.format(demand)).") }
        if counterFee != fee || Double(wage) < Double(demand) * accept {
            return .counter(fee: counterFee, wage: max(wage, demand),
                            "Close! They'd do it for \(Money.format(counterFee)) with a wage of \(Money.format(max(wage, demand))).")
        }
        completeTransfer(playerId: playerId, to: userClubId, fee: fee, wage: wage)
        return .accepted("Done! \(p.name) joins for \(fee > 0 ? Money.format(fee) : "free") on \(Money.format(wage)) a season.")
    }

    /// Keeps a club's XI at 11 after someone leaves: the order stays, the best available player fills in.
    mutating func patchXI(clubId: Int) {
        guard let ci = clubs.firstIndex(where: { $0.id == clubId }) else { return }
        clubs[ci].xi = clubs[ci].xi.filter { clubs[ci].squad.contains($0) }
        while clubs[ci].xi.count < 11 {
            let xi = clubs[ci].xi
            let overseas = xi.compactMap { players[$0] }.filter(\.overseas).count
            let options = clubs[ci].squad.compactMap { players[$0] }
                .filter { !xi.contains($0.id) && (!$0.overseas || overseas < tuning.maxOverseasXI) }
                .sorted { $0.rating != $1.rating ? $0.rating > $1.rating : $0.id < $1.id }
            guard let pick = options.first else { break }
            clubs[ci].xi.append(pick.id)
        }
        clubs[ci].bowlingOrder = clubs[ci].bowlingOrder.filter { clubs[ci].xi.contains($0) }
        if clubs[ci].bowlingOrder.count != 5 { clubs[ci].bowlingOrder = [] }
    }

    private mutating func completeTransfer(playerId: String, to buyer: Int, fee: Int, wage: Int) {
        guard let p = players[playerId], let bi = clubs.firstIndex(where: { $0.id == buyer }) else { return }
        if let seller = p.clubId, let si = clubs.firstIndex(where: { $0.id == seller }) {
            clubs[si].squad.removeAll { $0 == playerId }
            clubs[si].xi.removeAll { $0 == playerId }
            clubs[si].bowlingOrder.removeAll { $0 == playerId }
            if fee > 0 { post(seller, "Sold \(p.name)", fee) }
            players[playerId]?.clubId = nil
            patchXI(clubId: seller)
        }
        if fee > 0 { post(buyer, "Signed \(p.name)", -fee) }
        sign(playerId, to: bi, wage: wage)
        market.listed[playerId] = nil
        market.offers.removeAll { $0.playerId == playerId }
        let buyerName = club(buyer)?.short ?? ""
        addNews(.squad, "✍️ \(p.name) joins \(buyerName)\(fee > 0 ? " for \(Money.format(fee))" : " on a free").")
    }

    mutating func listForTransfer(_ playerId: String, asking: Int) {
        guard players[playerId]?.clubId == userClubId else { return }
        market.listed[playerId] = asking
        if windowOpen { generateOffers(for: playerId, attempts: 2) }
    }

    mutating func unlist(_ playerId: String) {
        market.listed[playerId] = nil
        market.offers.removeAll { $0.playerId == playerId }
    }

    mutating func rejectOffer(_ id: Int) { market.offers.removeAll { $0.id == id } }

    @discardableResult
    mutating func acceptOffer(_ id: Int) -> Bool {
        guard windowOpen, let o = market.offers.first(where: { $0.id == id }), let p = players[o.playerId],
              p.clubId == userClubId, let buyer = club(o.fromClub) else { return false }
        let wage = p.contract?.wage ?? wageDemand(p)
        guard bank(buyer.id) >= o.fee, capRoom(buyer.id) >= wage, squad(buyer.id).count < tuning.maxSquad else {
            market.offers.removeAll { $0.id == id }
            return false
        }
        completeTransfer(playerId: o.playerId, to: buyer.id, fee: o.fee, wage: wage)
        return true
    }

    /// Releases a player; the club pays part of his wage as compensation.
    @discardableResult
    mutating func release(_ playerId: String) -> Bool {
        guard windowOpen, let p = players[playerId], p.clubId == userClubId,
              let ci = clubs.firstIndex(where: { $0.id == userClubId }) else { return false }
        let comp = Int(Double(p.contract?.wage ?? 0) * tuning.releaseCompensation)
        if comp > 0 { post(userClubId, "Released \(p.name) (compensation)", -comp) }
        clubs[ci].squad.removeAll { $0 == playerId }
        clubs[ci].xi.removeAll { $0 == playerId }
        clubs[ci].bowlingOrder.removeAll { $0 == playerId }
        players[playerId]?.clubId = nil
        players[playerId]?.contract = nil
        market.listed[playerId] = nil
        market.offers.removeAll { $0.playerId == playerId }
        patchXI(clubId: userClubId)
        addNews(.squad, "\(p.name) released.")
        return true
    }

    /// AI bids for a listed player.
    mutating func generateOffers(for playerId: String, attempts: Int) {
        guard let p = players[playerId], p.clubId == userClubId else { return }
        let asking = market.listed[playerId] ?? p.value(in: year)
        let value = Double(p.value(in: year))
        let wage = p.contract?.wage ?? wageDemand(p)
        // Overpriced listings attract fewer bids.
        let appetite = max(0.1, min(0.8, 0.8 - (Double(asking) / max(1, value) - 1) * 0.8))
        for _ in 0..<attempts {
            guard rng.unit() < appetite else { continue }
            let buyers = clubs.filter { c in
                c.id != userClubId && capRoom(c.id) >= wage && squad(c.id).count < tuning.maxSquad
                    && (!p.overseas || squad(c.id).filter(\.overseas).count < tuning.maxOverseasSquad)
                    && !market.offers.contains { $0.playerId == playerId && $0.fromClub == c.id }
            }
            guard let buyer = buyers.randomElement(using: &rng) else { continue }
            let deal = manager.has(.dealmaker) ? 1.1 : 1.0
            let fee = min(bank(buyer.id), Career.round5(value * rng.range(0.8, 1.15) * deal))
            guard fee >= Career.round5(value * 0.5) else { continue }
            market.offers.append(TransferOffer(id: market.nextOfferId, playerId: playerId, fromClub: buyer.id, fee: fee))
            market.nextOfferId += 1
        }
    }

    /// AI clubs chase the user's stars when a window opens.
    mutating func unsolicitedOffers() {
        for p in squad(userClubId).sorted(by: { $0.id < $1.id }) where p.rating >= 78 {
            guard rng.unit() < 0.25 else { continue }
            let wage = p.contract?.wage ?? wageDemand(p)
            let buyers = clubs.filter { $0.id != userClubId && capRoom($0.id) >= wage && squad($0.id).count < tuning.maxSquad }
            guard let buyer = buyers.randomElement(using: &rng) else { continue }
            let fee = min(bank(buyer.id), Career.round5(Double(p.value(in: year)) * rng.range(1.1, 1.5) * (manager.has(.dealmaker) ? 1.1 : 1)))
            guard fee > 0 else { continue }
            market.offers.append(TransferOffer(id: market.nextOfferId, playerId: p.id, fromClub: buyer.id, fee: fee))
            market.nextOfferId += 1
            addNews(.squad, "📨 \(buyer.short) bid \(Money.format(fee)) for \(p.name).")
        }
    }

    /// Once per window: AI clubs sign free agents to fill and strengthen their squads.
    mutating func aiWindowActivity(key: String) {
        guard !market.aiWindowsDone.contains(key) else { return }
        market.aiWindowsDone.append(key)
        if market.aiWindowsDone.count > 12 { market.aiWindowsDone.removeFirst(market.aiWindowsDone.count - 12) }
        for ci in clubs.indices where clubs[ci].isCPU {
            for _ in 0..<2 {
                let squad = self.squad(clubs[ci].id).sorted { $0.rating < $1.rating }
                let overseas = squad.filter(\.overseas).count
                let room = capRoom(clubs[ci].id) - max(0, tuning.minSquad - squad.count - 1) * tuning.minWage
                let weakest = squad.first
                let candidates = freeAgents.filter { fa in
                    let osOK = !fa.overseas || overseas < tuning.maxOverseasSquad
                        || (weakest?.overseas ?? false && squad.count >= 22)
                    return osOK && wageDemand(fa) <= room + (squad.count >= 22 ? (weakest?.contract?.wage ?? 0) : 0)
                }
                guard let best = candidates.first else { break }
                if squad.count < 22 {
                    guard best.rating >= (squad.map(\.rating).sorted().dropFirst(squad.count / 2).first ?? 0) - 6 else { break }
                    sign(best.id, to: ci, wage: wageDemand(best))
                } else if let w = weakest, best.rating >= w.rating + 5 {
                    clubs[ci].squad.removeAll { $0 == w.id }
                    clubs[ci].xi.removeAll { $0 == w.id }
                    players[w.id]?.clubId = nil
                    players[w.id]?.contract = nil
                    sign(best.id, to: ci, wage: wageDemand(best))
                } else {
                    break
                }
            }
        }
    }

    /// Called as matches are played: opens the mid-season window and closes offers when it shuts.
    mutating func marketTick() {
        guard phase == .season else { return }
        if windowOpen, let f = nextFixture, round(of: f) == 25, !market.aiWindowsDone.contains("\(year)-mid") {
            aiWindowActivity(key: "\(year)-mid")
            unsolicitedOffers()
            for id in market.listed.keys.sorted() { generateOffers(for: id, attempts: 2) }
            addNews(.squad, "Mid-season transfer window is open this round.")
        } else if !windowOpen && (!market.offers.isEmpty || !market.talks.isEmpty) {
            market.offers = []
            market.talks = [:]
        }
    }
}
