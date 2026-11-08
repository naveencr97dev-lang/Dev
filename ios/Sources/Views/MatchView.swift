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

    @Environment(\.verticalSizeClass) private var vSize

    private func live(_ r: MatchResult) -> some View {
        let current = shown > 0 ? log[shown - 1] : nil
        let inningsNow = current?.innings ?? 0
        let thisOver = log[..<shown].filter { $0.innings == inningsNow && $0.over == (current?.over ?? 0) }
        let recent = Array(log[..<shown].suffix(8).reversed())

        let board = VStack(spacing: DS.Space.md) {
            ScoreBug(result: r, event: current)
            if let e = current {
                CreaseCard(event: e, battingTeam: store.team(r.innings[e.innings].teamId))
            }
            ZStack {
                if let e = current { BigCall(event: e).id(shown) }
            }
            .frame(height: 50)
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionLabel(text: "This over")
                HStack(spacing: 6) {
                    ForEach(Array(thisOver.enumerated()), id: \.offset) { i, e in
                        BallChip(label: e.label)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: thisOver.count)
            }
        }
        let feed = VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Commentary")
            AppCard(padding: DS.Space.md) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(recent.enumerated()), id: \.offset) { i, e in
                        HStack(alignment: .top, spacing: 8) {
                            Text(overString(e)).font(.score(13)).foregroundStyle(Palette.muted).frame(width: 34, alignment: .leading)
                            Text(e.text).font(.subheadline.weight(i == 0 ? .semibold : .regular))
                                .foregroundStyle(e.label == "W" ? Palette.wicket : (e.label == "6" ? Palette.six : (e.label == "4" ? Palette.four : Color.white)))
                        }
                        .opacity(i == 0 ? 1 : 0.7)
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

        return Group {
            if vSize == .compact {
                TwoColumns { board } right: { feed }
            } else {
                ScrollView {
                    VStack(spacing: DS.Space.md) { board; feed }
                        .padding(DS.Space.lg)
                }
            }
        }
    }

    private func overString(_ e: BallEvent) -> String {
        let balls = e.over * 6 + e.ballInOver
        return "\(balls / 6).\(balls % 6)"
    }
}

/// TV-style score strip: batting team, score, overs, chase equation.
struct ScoreBug: View {
    @EnvironmentObject var store: GameStore
    let result: MatchResult
    let event: BallEvent?

    var body: some View {
        let inn = event?.innings ?? 0
        let batting = store.team(result.innings[min(inn, 1)].teamId)
        let bowling = store.team(result.innings[min(inn, 1) == 0 ? 1 : 0].teamId)
        let balls = event.map { $0.over * 6 + $0.ballInOver } ?? 0
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    if let batting { TeamBadge(team: batting, size: 34) }
                    Text(batting?.short ?? "").font(.display(24))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(hex: batting?.colorHex ?? "#333333"))
                HStack(spacing: 6) {
                    Text("\(event?.score ?? 0)-\(event?.wickets ?? 0)").font(.score(30)).lineLimit(1).minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.25), value: event?.score)
                    Text("\(balls / 6).\(balls % 6)").font(.score(16, weight: .semibold)).foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, 12)
                Spacer(minLength: 4)
                Text("v \(bowling?.short ?? "")").font(.display(16, weight: .heavy)).foregroundStyle(Palette.muted)
                    .lineLimit(1).padding(.trailing, 12)
            }
            .background(Palette.surface)
            HStack {
                Text("\(result.pitch.icon) \(result.pitch.label.uppercased())").font(.display(12, weight: .heavy))
                Spacer(minLength: 4)
                Text(equation(inn: inn, balls: balls)).font(.display(13, weight: .heavy))
            }
            .lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(Palette.accent)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(Palette.stroke))
    }

    private func equation(inn: Int, balls: Int) -> String {
        if inn == 0 {
            let rr = balls > 0 ? Double(event?.score ?? 0) * 6 / Double(balls) : 0
            return "RUN RATE \(String(format: "%.2f", rr))"
        }
        let target = result.innings[0].runs + 1
        let need = max(0, target - (event?.score ?? 0))
        let left = 120 - balls
        if need == 0 { return "TARGET REACHED" }
        return "NEED \(need) OFF \(left) · TARGET \(target)"
    }
}

/// The two batters at the crease and the current bowler, like a broadcast lower third.
struct CreaseCard: View {
    let event: BallEvent
    let battingTeam: Franchise?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(event.batters.enumerated()), id: \.offset) { _, b in
                HStack(spacing: 8) {
                    Rectangle().fill(b.onStrike ? Palette.accent : Color.clear).frame(width: 4, height: 22)
                    Text(b.name.uppercased() + (b.onStrike ? " *" : ""))
                        .font(.display(18, weight: b.onStrike ? .black : .heavy)).lineLimit(1).minimumScaleFactor(0.6)
                    Spacer()
                    Text("\(b.runs)").font(.score(22))
                        .contentTransition(.numericText())
                    Text("(\(b.balls))").font(.score(14, weight: .regular)).foregroundStyle(Palette.muted).frame(width: 40, alignment: .leading)
                    Text("\(b.fours)×4 \(b.sixes)×6").font(.score(12, weight: .regular)).foregroundStyle(Palette.muted)
                        .lineLimit(1).minimumScaleFactor(0.6).frame(width: 52, alignment: .trailing)
                }
                .padding(.vertical, 6).padding(.trailing, 12)
            }
            Rectangle().fill(Palette.stroke).frame(height: 1)
            HStack(spacing: 8) {
                Image(systemName: "figure.cricket").foregroundStyle(Palette.muted).frame(width: 18)
                Text(event.bowler.name.uppercased()).font(.display(17, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
                Spacer()
                Text("\(event.bowler.overs)-\(event.bowler.runs)-\(event.bowler.wickets)").font(.score(20))
                let econ = event.bowler.balls > 0 ? Double(event.bowler.runs) * 6 / Double(event.bowler.balls) : 0
                Text("ECON \(String(format: "%.1f", econ))").font(.score(12, weight: .regular)).foregroundStyle(Palette.muted)
                    .lineLimit(1).minimumScaleFactor(0.6).frame(width: 52, alignment: .trailing)
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
        }
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(Palette.stroke))
        .animation(.spring(response: 0.3), value: event.batters.map(\.runs))
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
                    Text(result.stage.label.uppercased()).font(.caption.weight(.heavy)).foregroundStyle(Palette.accent)
                }
                HStack(spacing: 12) {
                    if let w { TeamBadge(team: w, size: 50) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w?.name.uppercased() ?? "").font(.display(26))
                        Text(result.margin.uppercased()).font(.display(17, weight: .heavy)).foregroundStyle(Palette.accent)
                    }
                }
                Divider().overlay(Color.white.opacity(0.2))
                Label("Player of the Match: \(result.potmName)", systemImage: "star.fill").font(.subheadline.weight(.semibold))
                Text("\(store.team(result.tossWinner)?.short ?? "") won the toss · \(store.team(result.innings[0].teamId)?.short ?? "") batted first")
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(result.pitch.icon) \(result.pitch.label) — \(result.pitch.blurb)")
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
                Text(team?.name.uppercased() ?? "").font(.display(18, weight: .heavy))
                Spacer()
                Text(innings.score).font(.score(24))
                Text("(\(innings.overs))").font(.score(14, weight: .regular)).foregroundStyle(Palette.muted)
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
