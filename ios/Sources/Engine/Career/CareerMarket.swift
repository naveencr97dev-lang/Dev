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
    /// Mega auction: the user's players released at retention, and Right to Match cards left
    /// (retentions + RTM cards = maxRetentions, as in the IPL). Optional, so older saves load.
    var released: [String]? = nil
    var rtmLeft: Int? = nil
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
        if clubId == userClubId { trackMoney(text, amount) }
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
            let mult = club.id == userClubId ? difficulty.incomeMult : 1
            post(club.id, "Season \(year) central revenue", Career.round5(Double(tuning.seasonRevenue) * mult))
            if let place = places.firstIndex(where: { $0 == club.id }), place < tuning.prizeMoney.count {
                post(club.id, "Prize money (\(["champions", "runners-up", "Qualifier 2", "Eliminator"][place]))",
                     Career.round5(Double(tuning.prizeMoney[place]) * mult))
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

    /// How much a club wants to keep a player at a mega auction (players who suit the home pitch more).
    func keepScore(_ p: CareerPlayer) -> Double {
        let age = p.age(in: year)
        let fit = p.clubId.map { seasonFit(p, clubId: $0) * PitchFit.squadWeight } ?? 0
        return Double(p.rating) + fit + (age <= 23 ? Double(max(0, p.potential - p.rating)) * 0.5 : 0) - (age >= 33 ? 6 : 0)
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
            if club.id == userClubId, offseason?.mega == true {
                offseason?.released = club.squad.filter { !keepIds.contains($0) }
                offseason?.rtmLeft = max(0, tuning.maxRetentions - keepIds.count)
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
        // The user's staff (auto-bid) chase players who walk into the XI, like a manager would.
        if club.id == userClubId, scoutAdvice(p).text.hasPrefix("Walks into") { need = max(need, 1.35) * 1.15 }
        if squad.count < tuning.minSquad { need *= 1.15 }
        if squad.count >= tuning.auctionSquadTarget { need *= 0.5 }
        // Personality nudges bids (±10%) without letting one club buy every star.
        let temper = (1 + (club.personality - 1) * 0.5) * difficulty.aiBidMult
        // Clubs pay more for players who suit their home pitch, and less for those who don't.
        let v = Double(p.value(in: year)) * need * temper * pitchValueFactor(p, clubId: club.id) * rng.range(0.8, 1.2)
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
            (winner, price) = aiSettle(a, base: base)
        }
        // Staff in charge: they use a Right to Match card on a former player worth keeping.
        if a.userAuto, let w = winner, w != userClubId, isRTMLot(id), (offseason?.rtmLeft ?? 0) > 0,
           Double(price) <= Double(p.value(in: year)) * 1.3, canAfford(userClubId, p, amount: price), scoutAdvice(p).good {
            winner = userClubId
            let cards = offseason?.rtmLeft ?? 1
            offseason?.rtmLeft = cards - 1
            addNews(.squad, "🃏 Right to Match: your staff keep \(p.name) at \(Money.format(price)).")
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

    /// Who the AI clubs would sell the current lot to, and for how much, if the user stops now.
    func aiSettle(_ a: CareerAuctionState, base: Int) -> (Int?, Int) {
        let floor = a.bid ?? base
        let interested = clubs.indices.filter { a.aiMax[$0] >= floor }
            .sorted { a.aiMax[$0] != a.aiMax[$1] ? a.aiMax[$0] > a.aiMax[$1] : $0 < $1 }
        guard let top = interested.first else { return (nil, 0) }
        var price = floor
        if interested.count > 1 {
            let second = a.aiMax[interested[1]]
            price = min(a.aiMax[top], second + increment(after: second))
        }
        return (clubs[top].id, max(price, floor))
    }

    /// Right to Match price: what the winning AI club would pay for the current lot (nil if no AI
    /// club wants him, or the user already leads).
    var rtmPrice: Int? {
        guard let a = offseason?.auction, let id = a.currentId, let p = players[id], a.leader != userClubId else { return nil }
        let (winner, price) = aiSettle(a, base: p.basePrice(in: year))
        guard let w = winner, w != userClubId else { return nil }
        return price
    }

    /// Was this lot the user's player last season (mega auction)?
    func isRTMLot(_ playerId: String) -> Bool { offseason?.released?.contains(playerId) ?? false }

    /// The user can match the leading AI bid on a former player with a Right to Match card.
    var canUseRTM: Bool {
        guard let os = offseason, os.stage == .auction, !os.auction.userAuto, let id = os.auction.currentId,
              isRTMLot(id), (os.rtmLeft ?? 0) > 0, let price = rtmPrice, let p = players[id] else { return false }
        return userBidBlock(p, amount: price) == nil
    }

    /// Uses a Right to Match card: the player stays at the current bid.
    @discardableResult
    mutating func useRTM() -> SaleLine? {
        guard canUseRTM, let id = offseason?.auction.currentId, let price = rtmPrice else { return nil }
        offseason?.auction.bid = price
        offseason?.auction.leader = userClubId
        let cards = offseason?.rtmLeft ?? 1
            offseason?.rtmLeft = cards - 1
        addNews(.squad, "🃏 Right to Match: you keep \(players[id]?.name ?? id).")
        return passLot()
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
        if settings.marketAlwaysOpen && phase != .seasonEnd { return true }
        if phase == .offseason { return offseason?.stage == .window }
        guard phase == .season, let f = nextFixture, let r = round(of: f) else { return false }
        return r <= 2 || r == 25
    }

    var windowLabel: String {
        if settings.marketAlwaysOpen && windowOpen { return "Market always open (test setting)" }
        if windowOpen { return phase == .offseason ? "Window open until the season starts" : "Window open this round" }
        return "Window closed · opens before round 25 and in the off-season"
    }

    /// What an AI club wants for a player (free agents cost no fee).
    func askingPrice(_ p: CareerPlayer) -> Int {
        guard let cid = p.clubId, let club = club(cid) else { return 0 }
        let mult = club.xi.contains(p.id) ? tuning.askXIMultiplier : tuning.askBenchMultiplier
        let userPrice = club.id == userClubId ? 1 : difficulty.priceMult
        return Career.round5(Double(p.value(in: year)) * mult * userPrice)
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

        let demand = userWageDemand(p)
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
        var added = false
        while clubs[ci].xi.count < 11 {
            let xi = clubs[ci].xi
            let inXI = xi.compactMap { player($0) }
            let overseas = inXI.filter(\.overseas).count
            let options = clubs[ci].squad.compactMap { player($0) }
                .filter { !xi.contains($0.id) && (!$0.overseas || overseas < tuning.maxOverseasXI) }
            // Fill what the XI is missing first (a keeper, five bowling options), then the best player.
            // Panel round 3: filling by rating alone put bowlers in the top order and caused collapses.
            let needKeeper = !inXI.contains { $0.role == .WK }
            let needBowler = inXI.filter(\.isBowlingOption).count < 5
            // With a keeper and five bowlers in, the place left is a batter's: fill it by batting
            // (panel 2: a sixth bowler took a top-order place and batted in the top six).
            let value = { (p: Player) in needKeeper || needBowler ? max(p.bat, p.bowl) + min(p.bat, p.bowl) / 2 : p.bat * 2 + p.bowl / 4 }
            let fits = options.filter { (needKeeper && $0.role == .WK) || (!needKeeper && needBowler && $0.isBowlingOption) }
            let pool = fits.isEmpty ? options : fits
            guard let pick = pool.max(by: { value($0) != value($1) ? value($0) < value($1) : $0.id > $1.id }) else { break }
            clubs[ci].xi.append(pick.id)
            added = true
        }
        // Newcomers bat where they bat best (as in Pick XI), so nobody bats out of position.
        if added { clubs[ci].xi = TeamSelector.battingOrder(clubs[ci].xi.compactMap { player($0) }).map(\.id) }
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
                // Of the best few free agents, the one who suits the home pitch.
                let cid = clubs[ci].id
                guard let best = candidates.prefix(6).enumerated().max(by: { a, b in
                    let (sa, sb) = (pitchRating(a.element, clubId: cid), pitchRating(b.element, clubId: cid))
                    return sa != sb ? sa < sb : a.offset > b.offset
                })?.element else { break }
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
        aiTransfers()
    }

    /// AI-to-AI transfers: clubs with money to spare buy an upgrade from another AI club, which keeps
    /// the market alive and stops AI banks piling up. Deterministic (sorted, no dictionary order).
    mutating func aiTransfers() {
        var moved = Set<String>()
        var sellers: [Int: Int] = [:]
        let buyers = clubs.filter(\.isCPU).map(\.id).sorted { bank($0) > bank($1) }
        for buyer in buyers {
            for _ in 0..<tuning.aiDealsPerWindow {
                let spare = bank(buyer) - tuning.aiReserveBank
                guard spare > 0, let bi = clubs.firstIndex(where: { $0.id == buyer }),
                      squad(buyer).count < tuning.maxSquad else { break }
                let xi = clubs[bi].xi.compactMap { players[$0] }
                let overseas = squad(buyer).filter(\.overseas).count
                // Ratings as the buyer sees them: overall plus fit to the buyer's home pitch.
                func seen(_ p: CareerPlayer) -> Double { pitchRating(p, clubId: buyer) }
                func weakest(_ r: Role) -> Double { xi.filter { $0.role == r }.map(seen).min() ?? 0 }
                let candidates = players.values.filter { p in
                    guard let cid = p.clubId, cid != buyer, cid != userClubId, !p.retired, !moved.contains(p.id),
                          club(cid)?.isCPU == true, sellers[cid, default: 0] < 1,
                          squad(cid).count > tuning.minSquad + 1 else { return false }
                    return seen(p) >= weakest(p.role) + Double(tuning.aiUpgradeMargin)
                        && (!p.overseas || overseas < tuning.maxOverseasSquad)
                        && aiFee(p) <= spare && wageDemand(p) <= capRoom(buyer)
                }
                guard let t = candidates.max(by: { a, b in
                    let ga = seen(a) - weakest(a.role), gb = seen(b) - weakest(b.role)
                    return ga != gb ? ga < gb : a.id > b.id
                }), let seller = t.clubId else { break }
                moved.insert(t.id)
                sellers[seller, default: 0] += 1
                completeTransfer(playerId: t.id, to: buyer, fee: aiFee(t), wage: wageDemand(t))
            }
        }
    }

    /// Staff advice for an auction lot or a transfer target: does the player improve the XI, fill
    /// a gap in the squad shape, or only add depth? (Panel feedback: blind bidding wrecked squads.)
    func scoutAdvice(_ p: CareerPlayer, fee: Int? = nil) -> (text: String, good: Bool) {
        let mine = squad(userClubId)
        if mine.count >= tuning.maxSquad { return ("Squad full (\(tuning.maxSquad)): sell or release first", false) }
        if p.overseas && !mine.contains(where: { $0.id == p.id }) && mine.filter(\.overseas).count >= tuning.maxOverseasSquad {
            return ("No overseas slot left (\(tuning.maxOverseasSquad)/\(tuning.maxOverseasSquad))", false)
        }
        if let fee, fee > bank(userClubId) { return ("Can't afford: fee \(Money.format(fee)), bank \(Money.format(bank(userClubId)))", false) }
        if let fee, userWageDemand(p) > capRoom(userClubId) { _ = fee; return ("His wage would break the salary cap", false) }
        let xi = userClub.xi.compactMap { id in players[id].flatMap { $0.clubId == userClubId ? $0 : nil } }
        let sameRole = mine.filter { $0.role == p.role }.count
        let shapeIndex = [Role.WK, .BAT, .AR, .BOWL].firstIndex(of: p.role) ?? 0
        let want = shapeIndex < tuning.squadShape.count ? tuning.squadShape[shapeIndex] : 4
        if let w = xi.filter({ $0.role == p.role && $0.id != p.id }).min(by: { $0.rating < $1.rating }), p.rating > w.rating + 1 {
            return ("Walks into your XI: better than \(w.name) (\(w.rating))", true)
        }
        if sameRole < want { return ("Fills a gap: \(sameRole) \(p.role.label.lowercased())s in the squad, you want \(want)", true) }
        if mine.count >= tuning.auctionSquadTarget { return ("Squad is full (\(mine.count)): depth only", false) }
        return ("Depth only: \(sameRole) \(p.role.label.lowercased())s already", false)
    }

    /// What one AI club pays another (no difficulty markup: that only applies to the user).
    func aiFee(_ p: CareerPlayer) -> Int {
        guard let cid = p.clubId, let c = club(cid) else { return 0 }
        let mult = c.xi.contains(p.id) ? tuning.askXIMultiplier : tuning.askBenchMultiplier
        return Career.round5(Double(p.value(in: year)) * mult)
    }

    /// Called as matches are played: opens the mid-season window and closes offers when it shuts.
    mutating func marketTick() {
        guard phase == .season else { return }
        if settings.marketAlwaysOpen {
            // Open market: bids for listed players keep coming in.
            for id in market.listed.keys.sorted() where rng.unit() < 0.15 { generateOffers(for: id, attempts: 1) }
        }
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
