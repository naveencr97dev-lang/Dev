import Foundation

enum TeamSelector {
    /// Picks a balanced XI: a keeper, at least five bowling options, max overseas, then best available.
    /// Returned in batting order.
    static func autoXI(squad: [Player], rules: Rules) -> [String] {
        var picked: [Player] = []
        func overseas() -> Int { picked.filter(\.overseas).count }
        func canAdd(_ p: Player) -> Bool {
            !picked.contains(p) && (!p.overseas || overseas() < rules.maxOverseasXI)
        }
        func value(_ p: Player) -> Int { max(p.bat, p.bowl) + min(p.bat, p.bowl) / 2 }

        if let wk = squad.filter({ $0.role == .WK }).sorted(by: { $0.bat > $1.bat }).first(where: canAdd) {
            picked.append(wk)
        }
        for p in squad.sorted(by: { $0.bowl > $1.bowl }) where p.isBowlingOption {
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

    static func battingOrder(_ xi: [Player]) -> [Player] {
        xi.sorted { $0.bat == $1.bat ? $0.bowl < $1.bowl : $0.bat > $1.bat }
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
