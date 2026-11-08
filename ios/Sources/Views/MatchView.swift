import SwiftUI
import Charts

/// Plays a fixture with a fast ball-by-ball ticker, then shows the scorecard.
struct MatchView: View {
    @EnvironmentObject var store: GameStore
    let fixtureId: Int

    @State private var result: MatchResult?
    @State private var log: [BallEvent] = []
    @State private var shown = 0
    @State private var finished = false
    @State private var speed = 1
    private let clock = Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let r = result {
                if finished || log.isEmpty {
                    MatchResultContent(result: r)
                } else {
                    live(r)
                }
            } else {
                ProgressView()
            }
        }
        .background(AppBackground())
        .navigationTitle(result?.stage == .league ? "Match" : (result?.stage.label ?? "Match"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !finished && !log.isEmpty {
                    Button("Skip ⏭") { finish() }
                }
            }
        }
        .onAppear(perform: start)
        .onReceive(clock) { _ in advance() }
        .keepAwake()
    }

    private func start() {
        guard result == nil else { return }
        result = store.play(fixtureId: fixtureId)
        log = store.log(for: fixtureId)
        if log.isEmpty { finished = true }
    }

    private func advance() {
        guard !finished, !log.isEmpty else { return }
        let before = shown
        shown = min(log.count, shown + speed)
        if log[before..<shown].contains(where: { $0.label == "W" }) { Haptics.heavy() }
        else if log[before..<shown].contains(where: { $0.label == "6" }) { Haptics.tap() }
        if shown >= log.count { finish() }
    }

    private func finish() {
        withAnimation(.easeInOut) {
            shown = log.count
            finished = true
        }
        Haptics.success()
    }

    // MARK: Live ticker

    private func live(_ r: MatchResult) -> some View {
        let current = shown > 0 ? log[shown - 1] : nil
        let inningsNow = current?.innings ?? 0
        let thisOver = log[..<shown].filter { $0.innings == inningsNow && $0.over == (current?.over ?? 0) }
        let recent = log[..<shown].suffix(7).reversed()

        return ScrollView {
            VStack(spacing: DS.Space.md) {
                scoreLine(r.innings[0], live: inningsNow == 0 ? current : nil, finalCard: inningsNow > 0, target: nil)
                if inningsNow == 1 {
                    scoreLine(r.innings[1], live: current, finalCard: false, target: r.innings[0].runs + 1)
                } else if let t = store.team(r.innings[1].teamId) {
                    HStack {
                        TeamBadge(team: t, size: 30)
                        Text("\(t.name) — yet to bat").foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, DS.Space.sm)
                }

                if let e = current {
                    BigCall(event: e).id(shown)
                }

                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    SectionLabel(text: "This over")
                    HStack(spacing: 6) {
                        ForEach(Array(thisOver.enumerated()), id: \.offset) { _, e in
                            BallChip(label: e.label)
                        }
                        Spacer()
                    }
                }

                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    SectionLabel(text: "Commentary")
                    AppCard(padding: DS.Space.md) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(recent.enumerated()), id: \.offset) { _, e in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(overString(e)).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
                                    Text(e.text).font(.subheadline)
                                        .foregroundStyle(e.label == "W" ? Palette.wicket : (e.label == "6" ? Palette.six : (e.label == "4" ? Palette.four : Color.primary)))
                                }
                            }
                        }
                    }
                }

                Picker("Speed", selection: $speed) {
                    Text("1×").tag(1)
                    Text("2×").tag(2)
                    Text("4×").tag(4)
                }
                .pickerStyle(.segmented)
            }
            .padding(DS.Space.lg)
        }
    }

    private func overString(_ e: BallEvent) -> String {
        let balls = e.over * 6 + e.ballInOver
        return "\(balls / 6).\(balls % 6)"
    }

    private func scoreLine(_ inn: InningsCard, live e: BallEvent?, finalCard: Bool, target: Int?) -> some View {
        let team = store.team(inn.teamId)
        let runs = finalCard ? inn.runs : (e?.score ?? 0)
        let wkts = finalCard ? inn.wickets : (e?.wickets ?? 0)
        let balls = finalCard ? inn.balls : (e.map { $0.over * 6 + $0.ballInOver } ?? 0)
        return AppCard(tint: team.map { Color(hex: $0.colorHex) }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if let team { TeamBadge(team: team, size: 36) }
                    Text(team?.name ?? "").font(.headline)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(runs)/\(wkts)").font(.display(30, weight: .heavy)).monospacedDigit()
                        Text("\(balls / 6).\(balls % 6) ov").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                if let target {
                    let need = max(0, target - runs)
                    let left = 120 - balls
                    Text(need == 0 ? "Target reached!" : "Need \(need) from \(left) ball\(left == 1 ? "" : "s") · RRR \(left > 0 ? String(format: "%.1f", Double(need) * 6 / Double(left)) : "–")")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.gold)
                }
            }
        }
    }
}

struct BallChip: View {
    let label: String
    var body: some View {
        let color: Color = label == "W" ? Palette.wicket : label == "6" ? Palette.six : label == "4" ? Palette.four : Color.white.opacity(0.14)
        Text(label)
            .font(.caption.weight(.heavy))
            .frame(width: 30, height: 30)
            .background(Circle().fill(color))
    }
}

/// Flash for boundaries and wickets.
struct BigCall: View {
    let event: BallEvent
    @State private var pop = false

    private var text: String? {
        switch event.label {
        case "6": return "SIX!"
        case "4": return "FOUR!"
        case "W": return "WICKET!"
        default: return nil
        }
    }

    private var color: Color {
        switch event.label {
        case "6": return Palette.six
        case "4": return Palette.four
        default: return Palette.wicket
        }
    }

    var body: some View {
        ZStack {
            if let text {
                Text(text)
                    .font(.display(40, weight: .black))
                    .foregroundStyle(color)
                    .scaleEffect(pop ? 1 : 0.5)
                    .opacity(pop ? 1 : 0)
            }
        }
        .frame(height: 50)
        .onAppear { withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { pop = true } }
    }
}

// MARK: - Scorecard

struct ResultScreen: View {
    @EnvironmentObject var store: GameStore
    let resultId: UUID

    var body: some View {
        Group {
            if let r = store.game?.result(resultId) {
                MatchResultContent(result: r)
            } else {
                Text("Result not found").foregroundStyle(.secondary)
            }
        }
        .background(AppBackground())
        .navigationTitle("Scorecard")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MatchResultContent: View {
    @EnvironmentObject var store: GameStore
    let result: MatchResult

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Space.lg) {
                header
                if result.stage == .final, store.game?.phase == .season, store.game?.championId != nil {
                    Button("🏆 Trophy ceremony") { store.finishSeason() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                worm
                ForEach(Array(result.innings.prefix(2).enumerated()), id: \.offset) { _, inn in
                    InningsCardView(innings: inn)
                }
            }
            .padding(DS.Space.lg)
        }
    }

    private var header: some View {
        let w = store.team(result.winnerId)
        return AppCard(tint: w.map { Color(hex: $0.colorHex) }) {
            VStack(alignment: .leading, spacing: 8) {
                if result.stage != .league {
                    Text(result.stage.label.uppercased()).font(.caption.weight(.heavy)).foregroundStyle(Palette.gold)
                }
                HStack(spacing: 12) {
                    if let w { TeamBadge(team: w, size: 50) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w?.name ?? "").font(.display(22))
                        Text(result.margin).font(.headline).foregroundStyle(Palette.gold)
                    }
                }
                Divider().overlay(Color.white.opacity(0.2))
                Label("Player of the Match: \(result.potmName)", systemImage: "star.fill").font(.subheadline.weight(.semibold))
                Text("\(store.team(result.tossWinner)?.short ?? "") won the toss · \(store.team(result.innings[0].teamId)?.short ?? "") batted first")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var worm: some View {
        let a = result.innings[0], b = result.innings[1]
        let ta = store.team(a.teamId), tb = store.team(b.teamId)
        let nameA = ta?.short ?? "A", nameB = (tb?.short ?? "B") == nameA ? nameA + " " : (tb?.short ?? "B")
        let points = a.overRuns.enumerated().map { WormPoint(team: nameA, over: $0.offset + 1, runs: $0.element) }
            + b.overRuns.enumerated().map { WormPoint(team: nameB, over: $0.offset + 1, runs: $0.element) }
        return VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Worm")
            AppCard(padding: DS.Space.md) {
                Chart(points) { p in
                    LineMark(x: .value("Over", p.over), y: .value("Runs", p.runs))
                        .foregroundStyle(by: .value("Team", p.team))
                        .interpolationMethod(.monotone)
                }
                .chartForegroundStyleScale(domain: [nameA, nameB],
                                           range: [ta.map { Color(hex: $0.colorHex) } ?? .blue,
                                                   tb.map { Color(hex: $0.colorHex) } ?? .orange])
                .chartXScale(domain: 0...20)
                .frame(height: 170)
            }
        }
    }
}

struct WormPoint: Identifiable {
    var id: String { "\(team)-\(over)" }
    let team: String
    let over: Int
    let runs: Int
}

struct InningsCardView: View {
    @EnvironmentObject var store: GameStore
    let innings: InningsCard

    var body: some View {
        let team = store.team(innings.teamId)
        let batted = innings.batters.filter(\.batted)
        let dnb = innings.batters.filter { !$0.batted }.map(\.name)
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack {
                if let team { TeamBadge(team: team, size: 28) }
                Text(team?.name ?? "").font(.headline)
                Spacer()
                Text("\(innings.score) (\(innings.overs))").font(.display(20)).monospacedDigit()
            }
            AppCard(padding: DS.Space.md) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Batter").frame(maxWidth: .infinity, alignment: .leading)
                        Text("R").frame(width: 34, alignment: .trailing)
                        Text("B").frame(width: 30, alignment: .trailing)
                        Text("4s").frame(width: 26, alignment: .trailing)
                        Text("6s").frame(width: 26, alignment: .trailing)
                    }
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(batted) { b in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(b.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Text(b.dismissal ?? "not out").font(.caption2).foregroundStyle(b.dismissal == nil ? Palette.four : Color.secondary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(b.runs)").fontWeight(.bold).frame(width: 34, alignment: .trailing)
                            Text("\(b.balls)").frame(width: 30, alignment: .trailing)
                            Text("\(b.fours)").frame(width: 26, alignment: .trailing)
                            Text("\(b.sixes)").frame(width: 26, alignment: .trailing)
                        }
                        .font(.subheadline.monospacedDigit())
                    }
                    HStack {
                        Text("Extras").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(innings.extras)")
                    }
                    .font(.footnote)
                    if !dnb.isEmpty {
                        Text("Did not bat: " + dnb.joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            AppCard(padding: DS.Space.md) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Bowler").frame(maxWidth: .infinity, alignment: .leading)
                        Text("O").frame(width: 32, alignment: .trailing)
                        Text("R").frame(width: 32, alignment: .trailing)
                        Text("W").frame(width: 26, alignment: .trailing)
                        Text("Econ").frame(width: 40, alignment: .trailing)
                    }
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(innings.bowlers.filter { $0.balls > 0 }) { bw in
                        HStack {
                            Text(bw.name).font(.subheadline.weight(.semibold)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            Text(bw.overs).frame(width: 32, alignment: .trailing)
                            Text("\(bw.runs)").frame(width: 32, alignment: .trailing)
                            Text("\(bw.wickets)").fontWeight(.bold).frame(width: 26, alignment: .trailing)
                            Text(String(format: "%.1f", bw.economy)).frame(width: 40, alignment: .trailing)
                        }
                        .font(.subheadline.monospacedDigit())
                    }
                }
            }
        }
    }
}
