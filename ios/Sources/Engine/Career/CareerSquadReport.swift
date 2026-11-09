import Foundation

// Career › Squad › Form and the squad report. Form (-10…+10, from recent performances) is the one
// measure of a player's state: it moves his batting and bowling by up to 3 in matches. (Morale and
// squad roles were tried in schema 12 and replaced by form in schema 13.)

struct SquadReport {
    var averageRating = 0
    var averageAge = 0.0
    var totalValue = 0
    var stars: [CareerPlayer] = []
    var strengths: [String] = []
    var weaknesses: [String] = []
}

extension Career {
    /// Plain-words form: "Red hot" … "Out of form".
    static func formLabel(_ form: Int) -> String {
        switch form {
        case 6...: return "Red hot"
        case 3..<6: return "In form"
        case -2..<3: return "Steady"
        case -5 ..< -2: return "Patchy"
        default: return "Out of form"
        }
    }

    /// Is his form rising or falling? Last five match ratings against his season average.
    func formTrend(_ id: String) -> Int {
        guard let avg = averageRating(id), matchRatings(id).count >= 6 else { return 0 }
        let recent = recentRatings(id)
        let r = recent.reduce(0, +) / Double(recent.count)
        return r >= avg + 0.4 ? 1 : (r <= avg - 0.4 ? -1 : 0)
    }

    /// 0…1: how close the offer is to what the player asks (the negotiation bar).
    func offerMood(_ p: CareerPlayer, wage: Int) -> Double {
        let demand = Double(userWageDemand(p))
        guard demand > 0, Double(wage) < demand else { return 1 }   // meeting the demand is a full bar
        return max(0, min(0.99, (Double(wage) / demand - 0.8) / 0.2))
    }

    // MARK: Squad report (Squad › Squad report)

    func squadReport() -> SquadReport {
        var r = SquadReport()
        let s = squad(userClubId)
        guard !s.isEmpty else { return r }
        r.averageRating = s.map(\.rating).reduce(0, +) / s.count
        r.averageAge = Double(s.map { $0.age(in: year) }.reduce(0, +)) / Double(s.count)
        r.totalValue = s.map { $0.value(in: year) }.reduce(0, +)
        r.stars = Array(s.sorted { $0.rating != $1.rating ? $0.rating > $1.rating : $0.id < $1.id }.prefix(3))

        let ranked = clubs.map(\.id).sorted { strength($0) > strength($1) }
        let pos = (ranked.firstIndex(of: userClubId) ?? 5) + 1
        if pos <= 3 { r.strengths.append("The XI is one of the strongest in the league (\(Career.ordinal(pos))).") }
        if pos >= clubs.count - 2 { r.weaknesses.append("The XI is one of the weakest in the league (\(Career.ordinal(pos))).") }

        // Batting and bowling against the league.
        func topBat(_ id: Int) -> Int {
            let xs = squad(id).map(\.bat).sorted(by: >).prefix(7)
            return xs.isEmpty ? 0 : xs.reduce(0, +) / xs.count
        }
        func topBowl(_ id: Int) -> Int {
            let xs = squad(id).map(\.bowl).sorted(by: >).prefix(5)
            return xs.isEmpty ? 0 : xs.reduce(0, +) / xs.count
        }
        let leagueBat = clubs.map { topBat($0.id) }.reduce(0, +) / max(1, clubs.count)
        let leagueBowl = clubs.map { topBowl($0.id) }.reduce(0, +) / max(1, clubs.count)
        let (bat, bowl) = (topBat(userClubId), topBowl(userClubId))
        if bat >= leagueBat + 2 { r.strengths.append("Batting is a strength (top seven average \(bat), league \(leagueBat)).") }
        if bat <= leagueBat - 2 { r.weaknesses.append("Batting is a weak area (top seven average \(bat), league \(leagueBat)).") }
        if bowl >= leagueBowl + 2 { r.strengths.append("The bowling attack is a strength (best five average \(bowl), league \(leagueBowl)).") }
        if bowl <= leagueBowl - 2 { r.weaknesses.append("The bowling attack is a weak area (best five average \(bowl), league \(leagueBowl)).") }

        // Conditions: spin and pace options for the home pitch.
        let spinners = s.filter { $0.bowlType == .spin && $0.bowl >= 60 }.count
        let seamers = s.filter { $0.bowlType == .pace && $0.bowl >= 60 }.count
        let home = info(userClubId)?.homePitch ?? .indianFlat
        if spinners < 2 { r.weaknesses.append("Only \(spinners) spinner\(spinners == 1 ? "" : "s") of quality\(home == .dustyTurner || home == .caribbeanSlow ? ", on a home pitch that turns" : "").") }
        if seamers < 3 { r.weaknesses.append("Only \(seamers) seamer\(seamers == 1 ? "" : "s") of quality\(home == .englishSeam || home == .aussieBounce ? ", on a home pitch for pace" : "").") }
        if spinners >= 3 && seamers >= 4 { r.strengths.append("Bowling options for every surface.") }

        // Shape, age, size, form.
        let keepers = s.filter { $0.role == .WK }.count
        if keepers == 0 { r.weaknesses.insert("No wicket-keeper in the squad: someone else keeps wicket. Sign one.", at: 0) }
        else if keepers < 2 { r.weaknesses.append("No backup wicket-keeper.") }
        if r.averageAge >= 30 { r.weaknesses.append("An ageing squad (average \(String(format: "%.1f", r.averageAge))). Plan for retirements.") }
        else if r.averageAge <= 25.5 { r.strengths.append("A young squad with room to grow (average \(String(format: "%.1f", r.averageAge))).") }
        else { r.strengths.append("A good mix of youth and experience.") }
        if s.count <= tuning.minSquad + 1 { r.weaknesses.append("A thin squad (\(s.count)): one injury crisis from trouble.") }
        else if s.count <= tuning.maxSquad - 2 { r.strengths.append("The squad is a manageable size (\(s.count)).") }
        let xi = Set(userClub.xi)
        let hot = s.filter { xi.contains($0.id) && $0.form >= 4 }.sorted { $0.form > $1.form }
        let cold = s.filter { xi.contains($0.id) && $0.form <= -4 }.sorted { $0.form < $1.form }
        if !hot.isEmpty { r.strengths.append("In form: \(hot.prefix(3).map { "\($0.name) (+\($0.form))" }.joined(separator: ", ")).") }
        if !cold.isEmpty { r.weaknesses.append("Out of form in the XI: \(cold.prefix(3).map { "\($0.name) (\($0.form))" }.joined(separator: ", ")).") }
        return r
    }
}
