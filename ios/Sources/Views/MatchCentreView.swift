import SwiftUI

/// Opened by ⏸ during a live match: the scorecard so far, and (in your own career matches)
/// field, batting intent, batting order and bowling changes that apply from the next ball.
struct MatchCentreView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let result: MatchResult
    let log: [BallEvent]
    let shown: Int
    /// The user's team in this match, if changes are allowed.
    let userTeam: Int?
    let tactics: Tactics
    /// Applies a change; returns false if it couldn't be applied.
    let apply: (LiveChange) -> Bool

    @Environment(\.verticalSizeClass) private var vSize
    @State private var tab = 0
    @State private var field: FieldSetting = .balanced
    @State private var intent: BatIntent = .rotate
    @State private var order: [String] = []
    @State private var plan: [String] = []
    @State private var nextBowler = ""
    @State private var message: String? = nil
    @State private var loaded = false

    private var current: BallEvent? { shown > 0 && shown <= log.count ? log[shown - 1] : nil }
    private var cards: [InningsCard] { MatchEngine.scorecardSoFar(result: result, log: log, upTo: shown) }
    private var batInnings: Int? { userTeam.flatMap { t in [0, 1].first { result.card($0).teamId == t } } }
    private var bowlInnings: Int? { batInnings.map { 1 - $0 } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $tab) {
                    Text("Scorecard").tag(0)
                    if userTeam != nil {
                        Text("Tactics").tag(1)
                        Text("Batting").tag(2)
                        Text("Bowling").tag(3)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, DS.Space.sm)
                if let message {
                    Text(message).font(.caption.weight(.bold)).foregroundStyle(Palette.accent).padding(.bottom, 4)
                }
                switch tab {
                case 1: tacticsTab
                case 2: battingTab
                case 3: bowlingTab
                default: scorecardTab
                }
            }
            .background(AppBackground())
            .navigationTitle(current.map { "Paused · \($0.score)/\($0.wickets) (\($0.over).\($0.ballInOver))" } ?? "Paused")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Resume ▶︎") { dismiss() }.font(.body.weight(.bold))
                }
            }
            .onAppear(perform: load)
        }
    }

    // MARK: Tabs

    private var scorecardTab: some View {
        ScrollView {
            VStack(spacing: DS.Space.md) {
                if cards.isEmpty {
                    Text("No balls bowled yet.").foregroundStyle(.secondary)
                }
                ForEach(Array(cards.enumerated()), id: \.offset) { i, inn in
                    if i >= 2 { SectionLabel(text: "Super Over") }
                    InningsCardView(innings: inn)
                }
            }
            .padding(DS.Space.lg)
        }
    }

    private var tacticsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                let boxes = vSize == .compact ? AnyLayout(HStackLayout(alignment: .top, spacing: DS.Space.md))
                                              : AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.sm))
                boxes {
                    PaneBox(title: "Field (when you bowl)", note: field.blurb) {
                        Picker("Field", selection: $field) {
                            ForEach([FieldSetting.defend, .balanced, .attack], id: \.self) { f in Text(f.label).tag(f) }
                        }
                        .pickerStyle(.segmented)
                    }
                    PaneBox(title: "Batting intent (when you bat)", note: intent.blurb) {
                        Picker("Batting", selection: $intent) {
                            ForEach(BatIntent.allCases, id: \.self) { b in Text(b.label).tag(b) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                HStack {
                    TableNote(text: "Applies to all three phases from the next ball. Toss, captain and roles stay.")
                    Spacer(minLength: 4)
                    ActionChip(icon: "checkmark", title: "Apply from the next ball", primary: true) {
                        var ch = change()
                        // Keep the toss call, captain and batting roles; only the phase settings change.
                        var t = tactics
                        t.field = [field, field, field]
                        t.intent = [intent, intent, intent]
                        t.plan = nil
                        ch.tactics = t
                        send(ch, "Tactics changed: \(field.label) field, \(intent.label) batting.")
                    }
                }
            }
            .padding(.horizontal, DS.Space.md)
        }
    }

    private var battingTab: some View {
        let done = battedSoFar
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                TableNote(text: "Drag ≡ to move the batters still to come. Batters already in or out stay put.")
                Spacer(minLength: 4)
                ActionChip(icon: "checkmark", title: "Apply new order", primary: true) {
                    var ch = change()
                    ch.battingOrder = order
                    send(ch, "Batting order changed.")
                }
            }
            TableHead {
                Text("#").frame(width: TCol.num, alignment: .center)
                Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
                Text("ROLE").frame(width: TCol.role, alignment: .leading)
                Text("BAT").frame(width: TCol.stat, alignment: .trailing)
                Text("").frame(width: 70)
            }
            .padding(.trailing, TCol.handle)
            ReorderList {
                ForEach(order.filter { done.contains($0) }, id: \.self) { id in
                    batterRow(id, fixed: true).reorderRow()
                }
                ForEach(order.filter { !done.contains($0) }, id: \.self) { id in
                    batterRow(id, fixed: false).reorderRow()
                }
                .onMove { from, to in
                    var rest = order.filter { !done.contains($0) }
                    rest.move(fromOffsets: from, toOffset: to)
                    order = order.filter { done.contains($0) } + rest
                }
            }
        }
        .padding(.horizontal, DS.Space.md)
    }

    private var bowlingTab: some View {
        let figures = bowlInnings.flatMap { i in cards.first { $0.teamId == result.card(i).teamId } }
        let bowlingNow = current.flatMap { e in bowlInnings == e.innings && e.ballInOver < 6 ? e.bowlerId : nil }
        let options = plan.filter { id in id != bowlingNow && overs(id, figures) < 4 }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Next over").font(.system(size: 12 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted)
                MenuChip(title: nextBowler.isEmpty ? "Keep the plan" : name(nextBowler)) {
                    Button("Keep the plan") { nextBowler = "" }
                    ForEach(options, id: \.self) { id in Button("\(name(id)) · \(oversText(id, figures))") { nextBowler = id } }
                }
                TableNote(text: "Max 4 overs each; nobody bowls two in a row. Top 5 bowl.")
                Spacer(minLength: 4)
                ActionChip(icon: "checkmark", title: "Apply", primary: true) {
                    var ch = change()
                    ch.bowlingPlan = Array(plan.prefix(5))
                    if !nextBowler.isEmpty { ch.nextOverBowler = nextBowler }
                    send(ch, nextBowler.isEmpty ? "Bowling plan changed." : "\(name(nextBowler)) bowls the next over.")
                }
            }
            TableHead {
                Text("#").frame(width: TCol.num, alignment: .center)
                if vSize == .compact { Text("JOB").frame(width: 104, alignment: .leading) }
                Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
                Text("TYPE").frame(width: TCol.role, alignment: .leading)
                Text("BOWL").frame(width: TCol.stat, alignment: .trailing)
                Text("FIGURES").frame(width: 70, alignment: .trailing)
            }
            .padding(.trailing, TCol.handle)
            ReorderList {
                ForEach(Array(plan.enumerated()), id: \.element) { i, id in
                    let p = store.player(id)
                    HStack(spacing: 8) {
                        TNum(text: i < 5 ? "\(i + 1)" : "–", width: TCol.num, color: i < 5 ? .white : Palette.muted, align: .center)
                        if vSize == .compact {
                            Text(i < 5 ? BowlingPlanView.slotInfo[i].0 : "Not bowling")
                                .font(.system(size: 11 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted)
                                .lineLimit(1).minimumScaleFactor(0.7).frame(width: 104, alignment: .leading)
                        }
                        TName(text: name(id), overseas: p?.overseas ?? false, bold: i < 5)
                        Text(p?.bowlType == .spin ? "Spin" : "Pace")
                            .font(.system(size: 11 * TextScale.factor, weight: .heavy))
                            .foregroundStyle(p?.bowlType == .spin ? Palette.six : Palette.four)
                            .frame(width: TCol.role, alignment: .leading)
                        TNum(text: "\(p?.bowl ?? 0)", width: TCol.stat, color: strengthColor(p?.bowl ?? 0))
                        TNum(text: oversText(id, figures), width: 70, color: Palette.muted)
                    }
                    .tableRow(selected: id == nextBowler, dimmed: i >= 5)
                    .reorderRow()
                }
                .onMove { plan.move(fromOffsets: $0, toOffset: $1) }
            }
        }
        .padding(.horizontal, DS.Space.md)
    }

    // MARK: Helpers

    private var battedSoFar: Set<String> {
        guard let bi = batInnings, let card = cards.first(where: { $0.teamId == result.card(bi).teamId }) else { return [] }
        return Set(card.batters.filter(\.batted).map(\.id))
    }

    private func batterRow(_ id: String, fixed: Bool) -> some View {
        let p = store.player(id)
        return HStack(spacing: 8) {
            TNum(text: "\((order.firstIndex(of: id) ?? 0) + 1)", width: TCol.num, align: .center)
            TName(text: name(id), overseas: p?.overseas ?? false)
            if let p { TRole(role: p.role) } else { Text("").frame(width: TCol.role) }
            TNum(text: "\(p?.bat ?? 0)", width: TCol.stat, color: strengthColor(p?.bat ?? 0))
            Text(fixed ? "In / out" : "To come").font(.system(size: 11 * TextScale.factor, weight: .semibold))
                .foregroundStyle(Palette.muted).frame(width: 70, alignment: .trailing)
        }
        .tableRow(dimmed: fixed)
    }

    private func name(_ id: String) -> String { store.player(id)?.name ?? id }

    private func overs(_ id: String, _ card: InningsCard?) -> Int {
        (card?.bowlers.first { $0.id == id }?.balls ?? 0) / 6
    }

    private func oversText(_ id: String, _ card: InningsCard?) -> String {
        guard let b = card?.bowlers.first(where: { $0.id == id }), b.balls > 0 else { return "0 overs" }
        return "\(b.overs)-\(b.runs)-\(b.wickets)"
    }

    private func change() -> LiveChange {
        LiveChange(innings: current?.innings ?? 0,
                   fromBall: current.map { $0.over * 6 + $0.ballInOver } ?? 0,
                   teamId: userTeam ?? -1)
    }

    private func send(_ ch: LiveChange, _ ok: String) {
        if apply(ch) {
            message = ok
            Haptics.success()
        } else {
            message = "Couldn't apply that change here."
            Haptics.warning()
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        field = tactics.field[1]
        intent = tactics.intent[1]
        if let bi = batInnings {
            order = result.card(bi).batters.map(\.id)
            let xi = order
            let used = result.card(1 - bi).bowlers.map(\.id).filter { xi.contains($0) }
            let others = xi.filter { !used.contains($0) }.sorted { (store.player($0)?.bowl ?? 0) > (store.player($1)?.bowl ?? 0) }
            plan = used + others
        }
    }
}
