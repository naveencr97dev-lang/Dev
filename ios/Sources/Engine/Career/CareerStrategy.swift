import Foundation

// Career › Squad › Tactics › Game plans: one tap sets all six phase settings (batting intent and
// field for the powerplay, middle and death), like a manager game's strategy presets. The pitch
// suggestions come from simulation (CareerTacticsTests.testGamePlansByPitch), not from guesses.

enum GamePlan: String, CaseIterable, Identifiable {
    case balanced, powerplayBlitz, seeItOff, buildAndLaunch, squeeze, allOut
    var id: String { rawValue }

    var label: String {
        switch self {
        case .balanced: return "Balanced"
        case .powerplayBlitz: return "Powerplay blitz"
        case .seeItOff: return "See off the new ball"
        case .buildAndLaunch: return "Build and launch"
        case .squeeze: return "Squeeze"
        case .allOut: return "All-out attack"
        }
    }

    var blurb: String {
        switch self {
        case .balanced: return "Normal cricket in every phase."
        case .powerplayBlitz: return "Go hard while the field is up, settle in the middle, finish hard. Attack with the new ball."
        case .seeItOff: return "Respect the new ball, then cash in late. Your own new-ball bowlers hunt wickets."
        case .buildAndLaunch: return "Keep wickets in hand and launch at the death. Bowl dry through the middle."
        case .squeeze: return "Strike early, then choke the runs. Bat safely and let the pressure tell."
        case .allOut: return "Attack everything, bat and ball. High risk, high reward."
        }
    }

    var tactics: (intent: [BatIntent], field: [FieldSetting]) {
        switch self {
        case .balanced: return ([.rotate, .rotate, .rotate], [.balanced, .balanced, .balanced])
        case .powerplayBlitz: return ([.attack, .rotate, .attack], [.attack, .balanced, .balanced])
        case .seeItOff: return ([.block, .rotate, .attack], [.attack, .balanced, .balanced])
        case .buildAndLaunch: return ([.rotate, .rotate, .attack], [.balanced, .defend, .defend])
        case .squeeze: return ([.rotate, .block, .rotate], [.attack, .defend, .defend])
        case .allOut: return ([.attack, .attack, .attack], [.attack, .attack, .attack])
        }
    }

    /// 0 (all defence) … 100 (all attack), for the Defence ↔ Attack bar.
    var aggression: Int {
        let t = tactics
        let bat = t.intent.map { $0 == .attack ? 100 : ($0 == .rotate ? 50 : 0) }
        let field = t.field.map { $0 == .attack ? 100 : ($0 == .balanced ? 50 : 0) }
        return (bat + field).reduce(0, +) / 6
    }

    /// Applies the plan's six settings, keeping the toss call, captain and batting roles.
    func apply(to t: Tactics) -> Tactics {
        var out = t
        out.intent = tactics.intent
        out.field = tactics.field
        out.plan = rawValue
        return out
    }

    /// The plan the simulations favour on each pitch (see the test above).
    static func suggested(for pitch: Pitch) -> GamePlan {
        suggestions[pitch] ?? .balanced
    }

    /// From the probe (win % vs neutral opponents, 600 matches per cell): flat, Build and launch 74.0
    /// (Balanced 71.2); seam, See off the new ball 67.7 (61.1); bounce, See off the new ball 72.4
    /// (71.2); turner, Squeeze 69.4 (61.8); slow, All-out attack 74.4 (66.6).
    static let suggestions: [Pitch: GamePlan] = [
        .indianFlat: .buildAndLaunch, .englishSeam: .seeItOff, .aussieBounce: .seeItOff,
        .dustyTurner: .squeeze, .caribbeanSlow: .allOut,
    ]
}

extension Tactics {
    /// The game plan these settings match, if any.
    var matchingPlan: GamePlan? {
        GamePlan.allCases.first { $0.tactics.intent == intent && $0.tactics.field == field }
    }
}
