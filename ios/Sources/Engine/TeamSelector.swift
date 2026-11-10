import Foundation

enum TeamSelector {
    /// Picks a balanced XI: a keeper, at least five bowling options, max overseas, then best available.
    /// Returned in batting order. With a pitch, players are judged by what they are worth on it.
    static func autoXI(squad: [Player], rules: Rules, pitch: Pitch? = nil) -> [String] {
        var picked: [Player] = []
        func overseas() -> Int { picked.filter(\.overseas).count }
        func canAdd(_ p: Player) -> Bool {
            !picked.contains(p) && (!p.overseas || overseas() < rules.maxOverseasXI)
        }
        func bat(_ p: Player) -> Int { p.bat + (pitch?.batFit(p) ?? 0) }
        func bowl(_ p: Player) -> Int { p.bowl >= 25 ? p.bowl + (pitch?.bowlFit(p) ?? 0) : p.bowl }
        // The pitch decides which bowlers play, not how many: when filling the last places a
        // bowler's pitch bonus is measured against the best kind for the surface, so the bonus
        // never puts an extra bowler ahead of a batter (that left home sides short of batting).
        let best = pitch.map { max(0, $0.paceBonus, $0.spinBonus) } ?? 0
        func value(_ p: Player) -> Int {
            let w = p.bowl >= 25 ? bowl(p) - best : p.bowl
            return max(bat(p), w) + min(bat(p), w) / 2
        }

        if let wk = squad.filter({ $0.role == .WK }).sorted(by: { bat($0) > bat($1) }).first(where: canAdd) {
            picked.append(wk)
        }
        for p in squad.sorted(by: { bowl($0) > bowl($1) }) where p.isBowlingOption {
            if picked.filter(\.isBowlingOption).count >= 5 { break }
            if canAdd(p) { picked.append(p) }
        }
        for p in squad.sorted(by: { value($0) > value($1) }) where picked.count < 11 {
            if canAdd(p) { picked.append(p) }
        }
        // Not enough eligible players (overseas cap) — fill regardless.
        for p in squad where picked.count < 11 && !picked.contains(p) {
            picked.append(p)
        }
        return battingOrder(picked).map(\.id)
    }

    /// How many balls each position tends to face (relative), for ordering.
    static let positionWeight: [Double] = [1.0, 1.0, 0.95, 0.9, 0.82, 0.72, 0.62, 0.42, 0.28, 0.18, 0.1]

    static func orderScore(_ order: [Player]) -> Double {
        order.enumerated().reduce(0) { sum, e in
            let w = e.offset < positionWeight.count ? positionWeight[e.offset] : 0.05
            return sum + w * Double(e.element.bat + e.element.slot.fit(position: e.offset))
        }
    }

    /// Best batting order: strongest batters face the most balls, each in a slot that suits them.
    static func battingOrder(_ xi: [Player]) -> [Player] {
        var order = xi.sorted { ($0.slot.ordinal, -$0.bat) < ($1.slot.ordinal, -$1.bat) }
        var best = orderScore(order)
        var improved = true
        while improved {
            improved = false
            for i in order.indices {
                for j in order.indices where j > i {
                    order.swapAt(i, j)
                    let s = orderScore(order)
                    if s > best + 0.001 { best = s; improved = true } else { order.swapAt(i, j) }
                }
            }
        }
        return order
    }

    /// Problems that block saving an XI (empty = valid).
    static func blockingIssues(_ xi: [Player], rules: Rules) -> [String] {
        var issues: [String] = []
        if xi.count != 11 { issues.append("Pick exactly 11 (\(xi.count) selected)") }
        let os = xi.filter(\.overseas).count
        if os > rules.maxOverseasXI { issues.append("Max \(rules.maxOverseasXI) overseas (\(os) selected)") }
        return issues
    }

    /// Advice that doesn't block saving.
    static func warnings(_ xi: [Player]) -> [String] {
        var w: [String] = []
        if !xi.contains(where: { $0.role == .WK }) { w.append("No wicket-keeper") }
        let bowlers = xi.filter(\.isBowlingOption).count
        if bowlers < 5 { w.append("Only \(bowlers) proper bowlers — part-timers will bowl") }
        return w
    }
}
