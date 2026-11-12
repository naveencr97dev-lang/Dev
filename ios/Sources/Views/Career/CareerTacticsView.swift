import SwiftUI

/// Career › Squad › Tactics: game plans (one tap sets all six phase settings), the phase settings
/// themselves, the toss call, the captain and each batter's role. Used for your club and your
/// national side.
struct TacticsView: View {
    @EnvironmentObject var store: GameStore
    @State private var t = Tactics()
    @State private var loaded = false

    var body: some View {
        let c = store.career
        let xi = c?.userClub.xi.compactMap { store.player($0) } ?? []
        let pitch = c?.nextUserFixture?.pitch
        PaneScreen(title: "Tactics") {
            TacticsEditor(t: $t, pitch: pitch, xi: xi, part: .left)
        } right: {
            TacticsEditor(t: $t, pitch: pitch, xi: xi, part: .right)
        }
        .onAppear {
            if !loaded, let c = store.career {
                t = c.tactics
                loaded = true
            }
        }
        .onChange(of: t) { v in
            if loaded { store.careerSetTactics(v) }
        }
    }
}

/// The tactics boxes, shared by Squad › Tactics and the paused match (owner's request: change the
/// whole plan mid-match, e.g. after forgetting to set it for a turner). Left: game plan (and the
/// toss and captain before a match). Right: the phases and batting roles.
struct TacticsEditor: View {
    enum Part { case left, right }
    @Binding var t: Tactics
    /// The pitch the plan is for (the next match, or the one being played): marks the suggested plan.
    let pitch: Pitch?
    /// The XI, batting order, for the captain and batting roles.
    let xi: [Player]
    let part: Part
    /// Toss and captain: before a match only.
    var showToss = true

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            switch part {
            case .left:
                plans
                if showToss { tossAndCaptain }
            case .right:
                phases
                roles
            }
        }
    }

    // MARK: Game plan

    private var plans: some View {
        let suggested = pitch.map { GamePlan.suggested(for: $0) }
        return PaneBox(title: "Game plan",
                       note: t.matchingPlan == nil ? "Custom: your own phase settings." : "Sets batting and field for all three phases.") {
            ForEach(Array(GamePlan.allCases.enumerated()), id: \.element.id) { i, plan in
                if i > 0 { Hairline() }
                Button { t = plan.apply(to: t); Haptics.tap() } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: t.matchingPlan == plan ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 15 * TextScale.factor))
                                .foregroundStyle(t.matchingPlan == plan ? Palette.accent : Palette.muted)
                            Text(plan.label).font(.system(size: 14 * TextScale.factor, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                            if plan == suggested {
                                Text("SUITS \(pitch?.label.uppercased() ?? "")")
                                    .font(.system(size: 9 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.accent)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Capsule().stroke(Palette.accent, lineWidth: 1))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            AggressionBar(value: plan.aggression, compact: true).frame(width: 90)
                        }
                        Text(plan.blurb).font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(1)
                            .padding(.leading, 23)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plan.\(plan.rawValue)")
            }
        }
    }

    // MARK: Phases

    private var phases: some View {
        PaneBox(title: "Phases", note: "Field: where the fielders stand. Batting: how hard your batters go.") {
            HStack(spacing: 8) {
                Text("").frame(width: 96, alignment: .leading)
                Text("FIELD").frame(maxWidth: .infinity, alignment: .leading)
                Text("BATTING").frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
            ForEach(0..<3, id: \.self) { i in
                if i > 0 { Hairline() }
                HStack(spacing: 8) {
                    Text(Tactics.phases[i]).font(.system(size: 12 * TextScale.factor, weight: .semibold)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7).frame(width: 96, alignment: .leading)
                    MenuChip(title: t.field[i].label) {
                        ForEach(FieldSetting.allCases, id: \.self) { f in Button(f.label) { t.field[i] = f } }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    MenuChip(title: t.intent[i].label) {
                        ForEach(BatIntent.allCases, id: \.self) { b in Button(b.label) { t.intent[i] = b } }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: Toss, captain, roles

    private var tossAndCaptain: some View {
        PaneBox(title: "Toss and captain", note: "Captain's call reads the pitch. The captain gets +1 batting and bowling while he plays.") {
            HStack(spacing: 8) {
                Text("If you win the toss").font(.system(size: 13 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(1)
                Spacer(minLength: 4)
                MenuChip(title: t.toss?.label ?? "Captain's call") {
                    Button("Captain's call") { t.toss = nil }
                    ForEach(TossCall.allCases, id: \.self) { call in Button(call.label) { t.toss = call } }
                }
            }
            Hairline()
            HStack(spacing: 8) {
                Text("Captain").font(.system(size: 13 * TextScale.factor)).foregroundStyle(Palette.muted)
                Spacer(minLength: 4)
                MenuChip(title: xi.first { $0.id == t.captain }?.name ?? "None") {
                    Button("None") { t.captain = nil }
                    ForEach(xi, id: \.id) { p in Button(p.name) { t.captain = p.id } }
                }
            }
        }
    }

    private var roles: some View {
        PaneBox(title: "Batting roles",
                note: "\(BatRole.anchor.label): \(BatRole.anchor.blurb.lowercased()). \(BatRole.hitter.label): \(BatRole.hitter.blurb.lowercased()).") {
            ForEach(Array(xi.prefix(8).enumerated()), id: \.element.id) { i, p in
                HStack(spacing: 8) {
                    Text("\(i + 1)").font(.score(13)).foregroundStyle(Palette.muted).frame(width: 18, alignment: .trailing)
                    Text(p.name).font(.system(size: 13 * TextScale.factor, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker(p.name, selection: Binding(get: { t.roles?[p.id] ?? .normal }, set: { r in
                        var all = t.roles ?? [:]
                        all[p.id] = r == .normal ? nil : r
                        t.roles = all.isEmpty ? nil : all
                    })) {
                        ForEach(BatRole.allCases, id: \.self) { r in Text(r.label).tag(r) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                }
            }
        }
    }
}

/// Defence ↔ Attack bar for a game plan.
struct AggressionBar: View {
    let value: Int
    /// Bar only, no "Defence"/"Attack" words (a narrow column).
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            if !compact { Text("Defence").font(.display(10, weight: .semibold)).foregroundStyle(Palette.muted) }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.stroke)
                    Capsule().fill(Palette.accent).frame(width: max(4, g.size.width * CGFloat(value) / 100))
                }
            }
            .frame(height: 5)
            if !compact { Text("Attack").font(.display(10, weight: .semibold)).foregroundStyle(Palette.muted) }
        }
    }
}
