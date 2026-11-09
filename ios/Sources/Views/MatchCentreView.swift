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
                .padding(DS.Space.md)
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
        List {
            Section {
                Picker("Field", selection: $field) {
                    ForEach([FieldSetting.defend, .balanced, .attack], id: \.self) { f in Text(f.label).tag(f) }
                }
                .pickerStyle(.segmented)
                Text(field.blurb).font(.caption).foregroundStyle(Palette.muted)
            } header: { Text("Field (when you bowl)") }
            .listRowBackground(Palette.surface)
            Section {
                Picker("Batting", selection: $intent) {
                    ForEach(BatIntent.allCases, id: \.self) { b in Text(b.label).tag(b) }
                }
                .pickerStyle(.segmented)
                Text(intent.blurb).font(.caption).foregroundStyle(Palette.muted)
            } header: { Text("Batting intent (when you bat)") }
            .listRowBackground(Palette.surface)
            Section {
                Button("Apply from the next ball") {
                    var ch = change()
                    // Keep the toss call, captain and batting roles; only the phase settings change.
                    var t = tactics
                    t.field = [field, field, field]
                    t.intent = [intent, intent, intent]
                    t.plan = nil
                    ch.tactics = t
                    send(ch, "Tactics changed: \(field.label) field, \(intent.label) batting.")
                }
                .buttonStyle(PrimaryButtonStyle())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .darkList()
    }

    private var battingTab: some View {
        let done = battedSoFar
        return List {
            Section {
                ForEach(order.filter { done.contains($0) }, id: \.self) { id in
                    batterRow(id, fixed: true)
                }
                ForEach(order.filter { !done.contains($0) }, id: \.self) { id in
                    batterRow(id, fixed: false)
                }
                .onMove { from, to in
                    var rest = order.filter { !done.contains($0) }
                    rest.move(fromOffsets: from, toOffset: to)
                    order = order.filter { done.contains($0) } + rest
                }
            } header: {
                Text("Drag the batters still to come")
            } footer: {
                Text("Batters already in (or out) stay where they are. Before your innings starts, you can move the openers too.")
            }
            .listRowBackground(Palette.surface)
            Section {
                Button("Apply new order") {
                    var ch = change()
                    ch.battingOrder = order
                    send(ch, "Batting order changed.")
                }
                .buttonStyle(PrimaryButtonStyle())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .environment(\.editMode, .constant(.active))
        .darkList()
    }

    private var bowlingTab: some View {
        let figures = bowlInnings.flatMap { i in cards.first { $0.teamId == result.card(i).teamId } }
        let bowlingNow = current.flatMap { e in bowlInnings == e.innings && e.ballInOver < 6 ? e.bowlerId : nil }
        return List {
            Section {
                Picker("Next over", selection: $nextBowler) {
                    Text("Keep the plan").tag("")
                    ForEach(plan.filter { id in id != bowlingNow && overs(id, figures) < 4 }, id: \.self) { id in
                        Text("\(name(id)) · \(oversText(id, figures))").tag(id)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Who bowls the next over")
            } footer: {
                Text("Max 4 overs each, and nobody bowls two overs in a row.")
            }
            .listRowBackground(Palette.surface)
            Section {
                ForEach(Array(plan.enumerated()), id: \.element) { i, id in
                    HStack {
                        Text(i < 5 ? "\(i + 1)" : "–").font(.display(18)).frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name(id)).font(.subheadline.weight(i < 5 ? .semibold : .regular))
                            Text("BOWL \(store.player(id)?.bowl ?? 0) · \(oversText(id, figures))")
                                .font(.caption2).foregroundStyle(Palette.muted)
                        }
                    }
                    .opacity(i < 5 ? 1 : 0.6)
                }
                .onMove { plan.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text("Bowling plan · top 5 bowl")
            } footer: {
                Text("Slots 1–2 take the new ball and the death overs, 3–5 the middle overs.")
            }
            .listRowBackground(Palette.surface)
            Section {
                Button("Apply bowling changes") {
                    var ch = change()
                    ch.bowlingPlan = Array(plan.prefix(5))
                    if !nextBowler.isEmpty { ch.nextOverBowler = nextBowler }
                    send(ch, nextBowler.isEmpty ? "Bowling plan changed." : "\(name(nextBowler)) bowls the next over.")
                }
                .buttonStyle(PrimaryButtonStyle())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .environment(\.editMode, .constant(.active))
        .darkList()
    }

    // MARK: Helpers

    private var battedSoFar: Set<String> {
        guard let bi = batInnings, let card = cards.first(where: { $0.teamId == result.card(bi).teamId }) else { return [] }
        return Set(card.batters.filter(\.batted).map(\.id))
    }

    private func batterRow(_ id: String, fixed: Bool) -> some View {
        HStack {
            Text("\((order.firstIndex(of: id) ?? 0) + 1)").font(.display(18)).frame(width: 24)
            Text(name(id)).font(.subheadline.weight(.semibold))
            Spacer()
            Text(fixed ? "in / out" : "BAT \(store.player(id)?.bat ?? 0)").font(.caption).foregroundStyle(Palette.muted)
        }
        .opacity(fixed ? 0.5 : 1)
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
