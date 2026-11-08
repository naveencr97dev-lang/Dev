import Foundation
import SwiftUI

/// UI-facing wrapper around `GameState`: owns the auction clock, CPU pacing and the save file.
@MainActor
final class GameStore: ObservableObject {
    let book: PlayerBook

    @Published private(set) var game: GameState?
    // Auction clock (not saved).
    @Published var timeLeft: Double = 0
    @Published var banner: SaleRecord? = nil
    @Published var lastAction: String = ""
    @Published var paused = false

    /// Ball-by-ball logs for matches played this session, by fixture id (not saved).
    private(set) var logs: [Int: [BallEvent]] = [:]

    private var cpuDelay: Double = 1
    private var bannerDelay: Double = 0
    private let fileURL: URL

    init() {
        let url = Bundle.main.url(forResource: "players", withExtension: "json")!
        let players = (try? PlayerDB.decode(Data(contentsOf: url))) ?? []
        book = PlayerBook(players)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("auctionxi-game.json")
        load()
        if game?.phase == .auction {
            // Saved right after a hammer: move on to the next lot.
            if game?.auction.lotClosed == true { mutate { $0.nextLot(book: book) } }
            paused = true
            resetLotClock()
        }
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        game = try? JSONDecoder().decode(GameState.self, from: data)
    }

    func save() {
        guard let game else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        if let data = try? JSONEncoder().encode(game) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func mutate(save shouldSave: Bool = true, _ change: (inout GameState) -> Void) {
        guard var g = game else { return }
        change(&g)
        game = g
        if shouldSave { save() }
    }

    // MARK: Lookups

    func team(_ id: Int) -> Franchise? { game?.team(id) }
    func player(_ id: String) -> Player? { book[id] }

    var currentPlayer: Player? {
        guard let id = game?.auction.currentPlayerId, game?.auction.finished == false else { return nil }
        return book[id]
    }

    func teamColor(_ id: Int) -> Color { Color(hex: team(id)?.colorHex ?? "#64748B") }

    // MARK: Game lifecycle

    func newGame() {
        game = GameState.newSetup(seed: UInt64.random(in: 1...UInt64.max))
        logs = [:]
        save()
    }

    func reset() {
        game = nil
        logs = [:]
        banner = nil
        paused = false
        save()
    }

    func startAuction(teams: [Franchise], rules: Rules) {
        mutate { g in
            g.teams = teams.enumerated().map { i, t in
                var t = t
                t.id = i
                if t.short.trimmingCharacters(in: .whitespaces).isEmpty {
                    t.short = String(t.name.replacingOccurrences(of: " ", with: "").prefix(3)).uppercased()
                }
                return t
            }
            g.rules = rules
            g.startAuction(book: book)
        }
        lastAction = "Auction is open!"
        resetLotClock()
    }

    // MARK: Auction clock

    private func resetLotClock() {
        timeLeft = game?.rules.bidSeconds ?? 8
        cpuDelay = Double.random(in: 1.0...2.2)
    }

    /// Called ~10x a second by the auction screen.
    func tick(_ dt: Double) {
        guard let g = game, g.phase == .auction, !paused else { return }

        if banner != nil {
            bannerDelay -= dt
            if bannerDelay <= 0 {
                banner = nil
                mutate { $0.nextLot(book: book) }
                resetLotClock()
            }
            return
        }

        if g.auction.lotClosed {
            // Hammer already fell (e.g. restored save) — just move on.
            mutate { $0.nextLot(book: book) }
            resetLotClock()
            return
        }

        timeLeft -= dt
        cpuDelay -= dt
        if !anyHumanCanBid(g) {
            // Nobody at the table can bid: let the CPUs settle it quickly.
            timeLeft = min(timeLeft, 2.0)
            cpuDelay = min(cpuDelay, 0.5)
        }
        if cpuDelay <= 0 {
            cpuDelay = Double.random(in: 0.7...1.9)
            var copy = g
            if let id = copy.cpuBid(book: book) {
                game = copy
                announceBid(teamId: id)
                timeLeft = max(timeLeft, min(g.rules.bidSeconds, 5))
            }
        }
        if timeLeft <= 0 { hammerNow() }
    }

    private func anyHumanCanBid(_ g: GameState) -> Bool {
        guard let pid = g.auction.currentPlayerId, let p = book[pid], let next = g.nextBidAmount(book: book) else { return false }
        return g.teams.contains { t in
            !t.isCPU && t.id != g.auction.leader
                && AuctionEngine.canBid(t, on: p, amount: next, rules: g.rules, players: book.byId)
        }
    }

    private func announceBid(teamId: Int) {
        guard let g = game, let bid = g.auction.currentBid, let t = g.team(teamId) else { return }
        lastAction = "\(t.short) bids \(Money.format(bid))"
    }

    func humanBid(_ teamId: Int) {
        guard banner == nil, var g = game else { return }
        if g.bid(teamId: teamId, book: book) {
            game = g
            Haptics.tap()
            announceBid(teamId: teamId)
            timeLeft = game?.rules.bidSeconds ?? 8
            cpuDelay = Double.random(in: 0.9...2.0)
        } else {
            Haptics.warning()
        }
    }

    /// Skip watching this lot: CPU teams settle it instantly.
    func skipLot() {
        guard banner == nil, game?.auction.lotClosed == false else { return }
        var record: SaleRecord?
        mutate { record = $0.skipLot(book: book) }
        showSale(record)
    }

    func hammerNow() {
        guard banner == nil else { return }
        var record: SaleRecord?
        mutate { record = $0.hammer() }
        showSale(record)
    }

    private func showSale(_ record: SaleRecord?) {
        guard let record else { return }
        banner = record
        bannerDelay = 1.8
        if record.teamId != nil { Haptics.success() } else { Haptics.heavy() }
        if let p = book[record.playerId] {
            if let tid = record.teamId, let t = team(tid) {
                lastAction = "\(p.name) SOLD to \(t.short) for \(Money.format(record.price))"
            } else {
                lastAction = "\(p.name) unsold"
            }
        }
    }

    /// Change the raise per bid mid-auction.
    func setBidStep(_ step: Int) {
        mutate { $0.rules.bidStep = step }
        lastAction = step == 0 ? "Bids now rise IPL-style" : "Bids now rise by \(Money.format(step))"
        Haptics.tap()
    }

    func simRestOfAuction() {
        banner = nil
        mutate { $0.simRestOfAuction(book: book) }
    }

    // MARK: Squads

    func setXI(teamId: Int, ids: [String]) {
        mutate { $0.setXI(teamId: teamId, ids: ids) }
    }

    func startSeason() {
        mutate { $0.startSeason() }
    }

    // MARK: Matches

    /// Plays the fixture if it hasn't been played yet; returns its result.
    @discardableResult
    func play(fixtureId: Int) -> MatchResult? {
        guard let g = game else { return nil }
        if let f = g.fixtures.first(where: { $0.id == fixtureId }), let r = g.result(f.resultId) { return r }
        var out: (MatchResult, [BallEvent])?
        mutate { out = $0.play(fixtureId: fixtureId, book: book) }
        if let out { logs[fixtureId] = out.1 }
        return out?.0
    }

    func finishSeason() {
        mutate { $0.finishSeason() }
    }

    func reopenSeason() {
        mutate { $0.reopenSeason() }
    }

    func needs(_ teamId: Int) -> AuctionEngine.Needs {
        game?.needs(teamId, book: book) ?? .init()
    }

    /// Label for the current lot's set (Marquee, Bowlers, ...).
    var currentSetName: String {
        guard let g = game, let p = currentPlayer else { return "" }
        if g.auction.round == 2 { return "Accelerated round" }
        return AuctionEngine.setName(for: p, index: g.auction.index, teamCount: g.teams.count)
    }

    func log(for fixtureId: Int) -> [BallEvent] { logs[fixtureId] ?? [] }

    /// Simulates upcoming matches that have no human team, up to the next human match.
    func simCPUMatches() -> Int {
        var count = 0
        while let g = game, g.phase == .season, let f = g.nextFixture, !g.isHumanFixture(f), count < 100 {
            play(fixtureId: f.id)
            count += 1
        }
        return count
    }
}
