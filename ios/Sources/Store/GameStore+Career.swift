import Foundation
import SwiftUI

/// Career mode: its own save file, and the actions the career screens call.
extension GameStore {
    // MARK: Persistence

    func loadCareer() {
        guard let data = try? Data(contentsOf: careerURL), var c = try? CareerSave.decode(data) else { return }
        c.tuning = careerTuning
        // A save from before objectives existed: the board sets this season's now.
        if c.phase == .season && c.board.year != c.year { c.setObjectives() }
        for id in c.userClub.squad + c.academy where c.players[id]?.seasonStartRating == nil {
            let r = c.players[id]?.rating
            c.players[id]?.seasonStartRating = r
        }
        career = c
    }

    func saveCareer() {
        guard let career else {
            try? FileManager.default.removeItem(at: careerURL)
            return
        }
        if let data = try? CareerSave.encode(career) {
            try? data.write(to: careerURL, options: .atomic)
        }
    }

    func mutateCareer(save shouldSave: Bool = true, _ change: (inout Career) -> Void) {
        guard var c = career else { return }
        change(&c)
        career = c
        if shouldSave { saveCareer() }
    }

    // MARK: Lifecycle

    var hasCareer: Bool { career != nil }

    /// Drafts squads for a new career; the user then picks a club from it.
    func draftPreview(legendsEra: Bool) -> Career {
        Career.new(managerName: "Manager", clubIndex: 0, seed: UInt64.random(in: 1...UInt64.max), year: 2027,
                   curated: book.all, born: careerBorn, tuning: careerTuning,
                   flags: CareerFlags(legendsEra: legendsEra))
    }

    func startCareer(_ draft: Career, clubId: Int, managerName: String, difficulty: Difficulty = .normal) {
        var c = draft
        let name = managerName.trimmingCharacters(in: .whitespaces)
        c.takeCharge(clubId: clubId, managerName: name.isEmpty ? "The Gaffer" : name)
        c.settings.difficulty = difficulty
        career = c
        logs = [:]
        inCareer = true
        saveCareer()
    }

    func continueCareer() {
        guard career != nil else { return }
        logs = [:]
        inCareer = true
    }

    func exitCareer() {
        saveCareer()
        logs = [:]
        inCareer = false
    }

    func deleteCareer() {
        career = nil
        inCareer = false
        logs = [:]
        saveCareer()
    }

    // MARK: Season

    func playCareer(fixtureId: Int) -> MatchResult? {
        guard let c = career else { return nil }
        if let r = c.playedResult(fixtureId: fixtureId) { return r }
        var out: (MatchResult, [BallEvent])?
        mutateCareer { out = $0.play(fixtureId: fixtureId) }
        if let out { logs[fixtureId] = out.1 }
        return out?.0
    }

    /// Simulates the other clubs' matches up to the user's next one.
    @discardableResult
    func careerSimUntilUserMatch() -> Int {
        var n = 0
        mutateCareer { n = $0.simUntilUserMatch() }
        return n
    }

    func careerSimToSeasonEnd() {
        mutateCareer { $0.simToSeasonEnd() }
    }

    // MARK: Off-season

    @discardableResult
    func careerBeginOffseason() -> Career.RolloverReport {
        var report = Career.RolloverReport()
        mutateCareer { report = $0.beginOffseason() }
        logs = [:]
        return report
    }

    func careerConfirmRetention(_ ids: [String]) {
        mutateCareer { $0.confirmRetention(userKeeps: ids) }
    }

    @discardableResult
    func careerUserBid() -> Bool {
        var ok = false
        mutateCareer(save: false) { ok = $0.userBid() }
        return ok
    }

    @discardableResult
    func careerUseRTM() -> SaleLine? {
        var sale: SaleLine?
        mutateCareer { sale = $0.useRTM() }
        return sale
    }

    @discardableResult
    func careerPassLot() -> SaleLine? {
        var sale: SaleLine?
        mutateCareer { sale = $0.passLot() }
        return sale
    }

    func careerSimAuction(autoBid: Bool) {
        mutateCareer { $0.simRestOfAuction(autoBid: autoBid) }
    }

    @discardableResult
    func careerStartSeason() -> [String] {
        var signed: [String] = []
        mutateCareer { signed = $0.startSeasonFromOffseason() }
        return signed
    }

    // MARK: Transfers

    func careerMakeOffer(playerId: String, fee: Int, wage: Int) -> OfferOutcome {
        var out = OfferOutcome.rejected("No career")
        mutateCareer { out = $0.makeOffer(playerId: playerId, fee: fee, wage: wage) }
        return out
    }

    func careerList(_ id: String, asking: Int) { mutateCareer { $0.listForTransfer(id, asking: asking) } }
    func careerUnlist(_ id: String) { mutateCareer { $0.unlist(id) } }
    func careerAcceptOffer(_ id: Int) -> Bool {
        var ok = false
        mutateCareer { ok = $0.acceptOffer(id) }
        return ok
    }
    func careerRejectOffer(_ id: Int) { mutateCareer { $0.rejectOffer(id) } }
    func careerRelease(_ id: String) -> Bool {
        var ok = false
        mutateCareer { ok = $0.release(id) }
        return ok
    }

    // MARK: Development

    func careerSetTraining(_ plan: TrainingPlan) { mutateCareer { $0.setTraining(plan) } }

    func careerHireScout(_ id: Int) -> String? {
        var err: String?
        mutateCareer { err = $0.hireScout(id) }
        return err
    }

    func careerFireScout(_ id: Int) { mutateCareer { $0.fireScout(id) } }

    func careerAssignScout(_ id: Int, region: String, role: Role?, youthOnly: Bool) {
        mutateCareer { $0.assignScout(id, region: region, role: role, youthOnly: youthOnly) }
    }

    func careerPromote(_ id: String) -> String? {
        var err: String?
        mutateCareer { err = $0.promote(id) }
        return err
    }

    func careerReleaseAcademy(_ id: String) { mutateCareer { $0.releaseFromAcademy(id) } }

    func careerSetTactics(_ t: Tactics) { mutateCareer { $0.tactics = t } }

    // MARK: Settings

    func careerSetTicketPrice(_ t: TicketPrice) { mutateCareer { $0.settings.ticketPrice = t } }

    /// Runs this week's training now; returns who improved.
    func careerRunTraining() -> [String] {
        var lines: [String] = []
        mutateCareer { lines = $0.runTrainingSession() }
        return lines
    }

    func careerSetDifficulty(_ d: Difficulty) { mutateCareer { $0.settings.difficulty = d } }
    func careerSetMarketAlwaysOpen(_ on: Bool) { mutateCareer { $0.settings.marketAlwaysOpen = on } }
    @discardableResult
    func careerSwapLineup(_ a: String, _ b: String) -> String? {
        var why: String?
        mutateCareer { why = $0.swapLineup(a, b) }
        return why
    }

    // Squad planner
    func careerAutoPlan() { mutateCareer { $0.autoPlan() } }
    func careerPlanAdd(_ slot: PlanSlot, _ id: String) { mutateCareer { $0.planAdd(slot, id) } }
    func careerPlanRemove(_ slot: PlanSlot, _ id: String) { mutateCareer { $0.planRemove(slot, id) } }
    func careerPlanMove(_ slot: PlanSlot, _ id: String, by step: Int) { mutateCareer { $0.planMove(slot, id, by: step) } }
    func careerPlanClear(_ slot: PlanSlot) { mutateCareer { $0.planClear(slot) } }
    @discardableResult
    func careerApplyPlan() -> [String] {
        var issues: [String] = []
        mutateCareer { issues = $0.applyPlan() }
        return issues
    }
    func careerSetAssistantPicksXI(_ on: Bool) { mutateCareer { $0.settings.assistantPicksXI = on } }
    func careerExchangeGold(_ amount: Int) -> String? {
        var err: String?
        mutateCareer { err = $0.exchangeGold(amount) }
        return err
    }

    // MARK: Live matches (pause and change)

    func careerPreview(fixtureId: Int, changes: [LiveChange]) -> (MatchResult, [BallEvent])? {
        career?.previewMatch(fixtureId: fixtureId, changes: changes)
    }

    /// Records the match exactly as previewed with these changes.
    func careerCommit(fixtureId: Int, changes: [LiveChange]) -> MatchResult? {
        var out: (MatchResult, [BallEvent])?
        mutateCareer { out = $0.play(fixtureId: fixtureId, changes: changes) }
        if let out { logs[fixtureId] = out.1 }
        return out?.0
    }

    func careerUserTeam(in fixtureId: Int) -> Int? { career?.userTeam(in: fixtureId) }

    // MARK: International

    @discardableResult
    func careerSimWindow(stopAtUser: Bool) -> Int {
        var n = 0
        mutateCareer { n = $0.simWindow(stopAtUser: stopAtUser) }
        return n
    }

    func careerEnsureWindow() { mutateCareer { $0.ensureWindow() } }
    func careerAcceptJob(_ code: String) { mutateCareer { $0.acceptJob(code) } }
    func careerResignJob() { mutateCareer { $0.resignJob() } }
    func careerSetNationalSquad(_ ids: [String]) { mutateCareer { $0.setNationalSquad(ids) } }

    // MARK: Club, manager, gold

    func careerUpgrade(_ k: FacilityKind) -> String? {
        var err: String?
        mutateCareer { err = $0.upgrade(k) }
        return err
    }

    func careerLearn(_ p: Perk) -> String? {
        var err: String?
        mutateCareer { err = $0.learn(p) }
        return err
    }

    func careerSpendGold(_ item: GoldItem, playerId: String? = nil) -> String? {
        var err: String?
        mutateCareer { err = $0.spendGold(item, playerId: playerId) }
        return err
    }

    func careerBuy(_ pack: StorePack) { mutateCareer { $0.buy(pack) } }

    /// Picks the best XI and order for the user's club, for the next match's pitch.
    func careerAutoXI() {
        mutateCareer { c in c.autoPickXI(clubIndex: c.userClubIndex, pitch: c.nextUserFixture?.pitch) }
    }

    /// Sets the user's XI from a selection, keeping the old batting order for players who stay.
    func careerPickXI(_ selected: Set<String>) {
        mutateCareer { c in
            let old = c.userClub.xi.filter { selected.contains($0) }
            let added = c.userClub.squad.filter { selected.contains($0) && !old.contains($0) }
            let players = (old + added).compactMap { c.player($0) }
            // New faces go where they bat best; existing players keep their places.
            let ids = added.isEmpty ? old : TeamSelector.battingOrder(players).map(\.id)
            c.setXI(clubId: c.userClubId, ids: ids)
            c.settings.assistantPicksXI = false   // the manager picks now
        }
    }

    func careerPlayer(_ id: String) -> CareerPlayer? { career?.players[id] }
}

extension GameStore {
    /// The rest of this fixture's round (career only), for the match centre.
    func careerRoundResults(around fixtureId: Int) -> [MatchResult] { career?.roundResults(around: fixtureId) ?? [] }
    /// The round's matches still to play (after the user's).
    func careerRoundLater(around fixtureId: Int) -> [Fixture] {
        career?.roundFixtures(around: fixtureId).filter { !$0.played } ?? []
    }
}
