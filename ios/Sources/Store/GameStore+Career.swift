import Foundation
import SwiftUI

/// Career mode: its own save file, and the actions the career screens call.
extension GameStore {
    // MARK: Persistence

    func loadCareer() {
        guard let data = try? Data(contentsOf: careerURL), var c = try? CareerSave.decode(data) else { return }
        c.tuning = careerTuning
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

    func startCareer(_ draft: Career, clubId: Int, managerName: String) {
        var c = draft
        let name = managerName.trimmingCharacters(in: .whitespaces)
        c.takeCharge(clubId: clubId, managerName: name.isEmpty ? "The Gaffer" : name)
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
        if let f = c.fixtures.first(where: { $0.id == fixtureId }), let r = c.result(f.resultId) { return r }
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

    @discardableResult
    func careerStartNextSeason() -> Career.RolloverReport {
        var report = Career.RolloverReport()
        mutateCareer { report = $0.startNextSeason() }
        logs = [:]
        return report
    }

    /// Picks the best XI and order for the user's club.
    func careerAutoXI() {
        mutateCareer { c in c.autoPickXI(clubIndex: c.userClubIndex) }
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
        }
    }

    func careerPlayer(_ id: String) -> CareerPlayer? { career?.players[id] }
}
