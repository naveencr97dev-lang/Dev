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
    /// Speed multiplier; 1× = one ball every `ballSeconds`. Remembered between matches.
    /// Owner's request: 2× for everyone by default, and the last speed each player picks is kept
    /// (a new key, so every device starts on 2× once).
    @AppStorage("matchSpeedV4") private var speed: Double = 2
    static let speeds: [(label: String, value: Double)] = [("1×", 1), ("2×", 2), ("4×", 4)]
    /// Seconds for a big moment at 1×; dots and singles take a third to a half of this
    /// (about 7 minutes for a full match).
    static let ballSeconds = 2.2
    static let tick = 0.05

    /// Time since the last ball was revealed (at 1× scale).
    @State private var ballClock: Double = 0
    @State private var inningsBreak = false
    /// Innings whose break card has been shown (1 = the chase, 2/4… = super overs).
    @State private var lastBreakInnings = 0
    @State private var superOverBreak = false
    @State private var breakClock: Double = 0
    @State private var paused = false
    @State private var showReel = false
    /// Career: the match is previewed, changed while paused, and recorded at the end.
    @State private var changes: [LiveChange] = []
    @State private var pendingCommit = false
    @State private var showCentre = false
    /// Before the first ball: the Teams board (both XIs, the toss) until Start.
    @State private var prematch = true
    @Environment(\.dismiss) private var dismiss
    private let clock = Timer.publish(every: MatchView.tick, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let r = result {
                if !finished && !log.isEmpty && prematch {
                    let board = TeamsBoard(result: r, occasion: occasion(r), fill: vSize == .compact, onStart: {
                        withAnimation(.easeInOut) { prematch = false }
                        Haptics.tap()
                    }, onSkip: { finish() })
                    if vSize == .compact {
                        // Landscape (device feedback): the two XIs fill the screen; no gap at the foot.
                        board
                            .padding(.horizontal, DS.Space.md)
                            .padding(.vertical, DS.Space.sm)
                            .frame(maxWidth: 960, maxHeight: .infinity)
                            .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            board
                                .padding(.horizontal, DS.Space.md)
                                .padding(.vertical, DS.Space.sm)
                                .frame(maxWidth: 960)
                                .frame(maxWidth: .infinity)
                        }
                    }
                } else if !finished && !log.isEmpty {
                    live(r)
                } else if showReel && !(r.highlights ?? []).isEmpty {
                    HighlightsReel(result: r) { withAnimation(.easeInOut) { showReel = false } }
                        .transition(.opacity)
                } else {
                    MatchResultContent(result: r)
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
                    HStack {
                        Button { pauseForCentre() } label: { Image(systemName: "list.clipboard") }
                        Button("Skip ⏭") { finish() }
                    }
                } else if result != nil {
                    // Device feedback: a clear way on after the match (back to the hub's Continue).
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Next").fontWeight(.bold)
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                        }
                    }
                }
            }
        }
        .onAppear {
            start()
            GameAudio.shared.play(.crowd)
        }
        .onDisappear {
            if !showCentre {
                commitIfNeeded()
                GameAudio.shared.play(.theme)
            }
        }
        .onReceive(clock) { _ in advance() }
        .sheet(isPresented: $showCentre, onDismiss: { paused = false }) {
            if let r = result {
                MatchCentreView(result: r, log: log, shown: shown,
                                userTeam: pendingCommit ? store.careerUserTeam(in: fixtureId) : nil,
                                tactics: changes.last(where: { $0.tactics != nil })?.tactics ?? store.career?.tactics ?? Tactics(),
                                round: store.inCareer ? store.careerRoundResults(around: fixtureId) : [],
                                roundLater: store.inCareer ? store.careerRoundLater(around: fixtureId) : [],
                                apply: applyChange)
                    .environmentObject(store)
            }
        }
        .keepAwake()
    }

    private func start() {
        guard result == nil else { return }
        if store.inCareer, let p = store.careerPreview(fixtureId: fixtureId, changes: []) {
            // Not recorded yet: you can pause and change things; it's recorded at the end.
            result = p.0
            log = p.1
            pendingCommit = true
        } else {
            result = store.play(fixtureId: fixtureId)
            log = store.log(for: fixtureId)
        }
        if log.isEmpty { finished = true }
    }

    private func commitIfNeeded() {
        guard pendingCommit else { return }
        pendingCommit = false
        if let r = store.careerCommit(fixtureId: fixtureId, changes: changes) { result = r }
    }

    private func pauseForCentre() {
        paused = true
        showCentre = true
        Haptics.tap()
    }

    // MARK: Mentality on the match screen (owner's request)

    /// The tactics in force now: the last live change's, else the club's.
    private var liveTactics: Tactics {
        changes.last(where: { $0.tactics != nil })?.tactics ?? store.career?.tactics ?? Tactics()
    }

    /// Block / Rotate / Attack while you bat; Defensive / Balanced / Aggressive while you bowl. A tap
    /// applies from the next ball for the rest of the innings. Only in your own career matches.
    @ViewBuilder private func mentalityBar(_ r: MatchResult, current: BallEvent?, userTeam: Int?) -> some View {
        if pendingCommit, let team = userTeam, !finished {
            let innings = current?.innings ?? 0
            let batting = r.card(innings).teamId == team
            let over = current?.over ?? 0
            let phase = over < 6 ? 0 : (over < 16 ? 1 : 2)
            let t = liveTactics
            if batting {
                MentalityBar(title: "Batting", options: BatIntent.allCases.map(\.label),
                             selected: BatIntent.allCases.firstIndex(of: t.intent[phase]) ?? 1) { i in
                    setMentality(team: team, current: current) { $0.intent = Array(repeating: BatIntent.allCases[i], count: 3) }
                }
            } else {
                let fields: [FieldSetting] = [.defend, .balanced, .attack]
                MentalityBar(title: "Bowling", options: fields.map(\.label),
                             selected: fields.firstIndex(of: t.field[phase]) ?? 1) { i in
                    setMentality(team: team, current: current) { $0.field = Array(repeating: fields[i], count: 3) }
                }
            }
        }
    }

    private func setMentality(team: Int, current: BallEvent?, _ edit: (inout Tactics) -> Void) {
        var t = liveTactics
        edit(&t)
        t.plan = nil
        var change = LiveChange(innings: current?.innings ?? 0,
                                fromBall: current.map { $0.over * 6 + $0.ballInOver } ?? 0, teamId: team)
        change.tactics = t
        if applyChange(change) { Haptics.tap() } else { Haptics.warning() }
    }

    /// Re-plays the match with one more change; everything already shown must stay the same.
    private func applyChange(_ change: LiveChange) -> Bool {
        let next = changes + [change]
        guard let p = store.careerPreview(fixtureId: fixtureId, changes: next), p.1.count >= shown else { return false }
        let same = zip(log.prefix(shown), p.1.prefix(shown)).allSatisfy {
            $0.innings == $1.innings && $0.score == $1.score && $0.label == $1.label && $0.wickets == $1.wickets
        }
        guard same else { return false }
        changes = next
        result = p.0
        log = p.1
        return true
    }

    /// How long the ball just shown stays on screen: quick for dots and singles, long for
    /// boundaries, wickets and milestones, every ball counts in a tight finish.
    private var ballWait: Double {
        guard shown > 0 else { return MatchView.ballSeconds * 0.6 }
        let e = log[shown - 1]
        var f: Double
        switch e.label {
        case "wd": f = 0.3
        case "0": f = 0.35
        case "1": f = 0.45
        case "2", "3": f = 0.6
        case "4": f = 1.0
        case "6": f = 1.25
        case "W": f = 1.6
        default: f = 0.5
        }
        if e.text.contains("FIFTY") || e.text.contains("HUNDRED") { f = max(f, 1.6) }
        if isTense(e) { f = max(f, 0.9) }
        if MatchView.isOverEnd(e) { f += 1.2 }
        return MatchView.ballSeconds * f
    }

    /// Last 3 overs of a chase that's still alive: let every ball breathe.
    private func isTense(_ e: BallEvent) -> Bool {
        guard let r = result, let target = r.target(forInnings: e.innings) else { return false }
        let need = target - e.score
        let left = r.maxBalls(e.innings) - (e.over * 6 + e.ballInOver)
        if e.innings >= 2 { return need > 0 }   // every super-over chase ball is tense
        return need > 0 && left <= 18 && need <= left * 2 + 6
    }

    static func isOverEnd(_ e: BallEvent) -> Bool { e.ballInOver == 6 && e.label != "wd" }

    /// Runs and wickets per over so far in an innings, from the ball log.
    static func liveOvers(_ log: [BallEvent], upTo shown: Int, innings: Int) -> [(runs: Int, wickets: Int)] {
        var out: [(runs: Int, wickets: Int)] = []
        var start = 0, prevScore = 0, currentOver = -1
        for e in log[..<shown] where e.innings == innings {
            if e.over != currentOver {
                start = prevScore
                currentOver = e.over
                while out.count <= e.over { out.append((0, 0)) }
            }
            out[e.over].runs = e.score - start
            if e.label == "W" { out[e.over].wickets += 1 }
            prevScore = e.score
        }
        return out
    }

    /// "Round 26 of 36 · 7 Sep" in career, else the stage.
    private func occasion(_ r: MatchResult) -> String {
        if store.inCareer, let c = store.career, let f = c.fixtures.first(where: { $0.id == fixtureId }) {
            return CareerText.fixtureLabel(c, f)
        }
        return r.stage == .league ? "League match" : r.stage.label
    }

    private func advance() {
        guard !finished, !log.isEmpty, !paused, !prematch else { return }
        if inningsBreak {
            breakClock += MatchView.tick * speed
            if breakClock >= 7 { continueAfterBreak() }
            return
        }
        ballClock += MatchView.tick * speed
        guard ballClock >= ballWait else { return }
        ballClock = 0
        // Innings break before the chase starts.
        // Breaks before the chase and before each super over.
        if shown > 0, shown < log.count, log[shown].innings != log[shown - 1].innings,
           (log[shown].innings == 1 || (log[shown].innings >= 2 && log[shown].innings % 2 == 0)),
           log[shown].innings > lastBreakInnings {
            superOverBreak = log[shown].innings >= 2
            withAnimation(.spring()) { inningsBreak = true }
            lastBreakInnings = log[shown].innings
            breakClock = 0
            return
        }
        withAnimation(.easeOut(duration: 0.25)) { shown = min(log.count, shown + 1) }
        switch log[shown - 1].label {
        case "W": Haptics.heavy()
        case "6", "4": Haptics.tap()
        default: break
        }
        GameAudio.shared.ball(log[shown - 1].label)
        if shown >= log.count { finish() }
    }

    private func continueAfterBreak() {
        withAnimation(.spring()) { inningsBreak = false }
        ballClock = MatchView.ballSeconds * 0.4
    }

    private func finish() {
        withAnimation(.easeInOut) {
            shown = log.count
            finished = true
        }
        commitIfNeeded()
        Haptics.success()
        // The victory sting: your win in career, any finish in the pass-and-play game.
        let userTeam = store.inCareer ? store.career?.userTeam(in: fixtureId) : nil
        if !store.inCareer || (userTeam != nil && result?.winnerId == userTeam) { GameAudio.shared.effect(.win, volume: 0.8) }
    }

    // MARK: Live ticker

    @Environment(\.verticalSizeClass) private var vSize

    private func live(_ r: MatchResult) -> some View {
        let current = shown > 0 ? log[shown - 1] : nil
        let inningsNow = current?.innings ?? 0
        let thisOver = log[..<shown].filter { $0.innings == inningsNow && $0.over == (current?.over ?? 0) }
        let recent = Array(log[..<shown].suffix(8).reversed())
        let shots = log[..<shown].enumerated().filter { $0.element.innings == inningsNow }
            .map { WagonWheel.Shot(index: $0.offset, event: $0.element) }
        // Device feedback: the ⏸ Overview's numbers and the assistant on the match screen itself.
        let soFar = MatchEngine.scorecardSoFar(result: r, log: log, upTo: shown)
        let numbers = LiveReport.numbers(cards: soFar, log: log, upTo: shown)
        let userTeam = store.inCareer ? store.careerUserTeam(in: fixtureId) : nil
        let advice = userTeam.flatMap { LiveReport.advice(cards: soFar, log: log, upTo: shown, userTeam: $0).first }
        let mentality = mentalityBar(r, current: current, userTeam: userTeam)
        // Only build up to the next ball after something worth pausing on.
        let anticipating = !inningsBreak && shown < log.count && ballWait >= MatchView.ballSeconds * 0.85
            && ballClock > ballWait * 0.45

        let board = VStack(spacing: DS.Space.sm) {
            ScoreBug(result: r, event: current)
            statusLine(current: current, anticipating: anticipating)
            FieldOrWheel(shots: shots, latest: shown - 1)
                .frame(maxWidth: .infinity)
                .frame(height: vSize == .compact ? 210 : 280)
                .overlay {
                    if let e = current, !anticipating { BigCall(event: e).id(shown) }
                }
            if let e = current {
                CreaseCard(event: e, battingTeam: store.team(r.card(e.innings).teamId), order: r.card(e.innings).batters.map(\.name))
            }
            if let numbers { LiveNumbersGrid(numbers: numbers) }
            if let advice { AssistantTicker(text: advice) }
        }
        let feed = VStack(alignment: .leading, spacing: DS.Space.sm) {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionLabel(text: "This over")
                HStack(spacing: 6) {
                    ForEach(Array(thisOver.enumerated()), id: \.offset) { _, e in
                        BallChip(label: e.label)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: thisOver.count)
            }
            SectionLabel(text: "Runs per over")
            AppCard(padding: DS.Space.md) {
                LiveOverBars(perOver: MatchView.liveOvers(log, upTo: shown, innings: inningsNow),
                             color: Color(hex: store.team(r.card(inningsNow).teamId)?.colorHex ?? "#D7FF3A"))
            }
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
            mentality
            HStack(spacing: 10) {
                PauseButton(paused: paused) { if paused { paused = false } else { pauseForCentre() } }
                SpeedPicker(speed: $speed, options: MatchView.speeds.map(\.value),
                            labels: MatchView.speeds.map(\.label))
            }
        }

        return ZStack {
            Group {
                if vSize == .compact {
                    landscape(r, current: current, thisOver: thisOver, shots: shots, anticipating: anticipating,
                              numbers: numbers, advice: advice, mentality: mentality)
                } else {
                    ScrollView {
                        VStack(spacing: DS.Space.md) { board; feed }
                            .padding(DS.Space.lg)
                    }
                }
            }
            if inningsBreak && superOverBreak {
                SuperOverBreakCard(result: r, superOverIndex: max(0, (lastBreakInnings - 2) / 2), onContinue: continueAfterBreak)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else if inningsBreak {
                InningsBreakCard(result: r, onContinue: continueAfterBreak)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
    }

    /// Landscape (iPhone Pro Max is ~830 × 420 pt inside the safe area): scoreboard and controls
    /// on the left, the wagon wheel filling the right half at full height. No scrolling.
    private func landscape(_ r: MatchResult, current: BallEvent?, thisOver: [BallEvent],
                           shots: [WagonWheel.Shot], anticipating: Bool,
                           numbers: LiveReport.Numbers?, advice: String?, mentality: some View) -> some View {
        GeometryReader { geo in
            let gap: CGFloat = 12
            let col = max(0, (geo.size.width - gap) / 2)
            HStack(spacing: gap) {
                ScrollView(showsIndicators: false) {
                    // Device tour: with the navigation bar hidden, the landscape match screens sat ~20 pt
                    // too high (the line-ups title and this Back button were cut off). The standard
                    // bar (Back, Match, the centre and Skip) stays now, like every other screen.
                    VStack(spacing: 6) {
                        ScoreBug(result: r, event: current, compact: true)
                        statusLine(current: current, anticipating: anticipating, compact: true)
                        if let e = current {
                            CreaseCard(event: e, battingTeam: store.team(r.card(e.innings).teamId), compact: true,
                                       order: r.card(e.innings).batters.map(\.name))
                        }
                        if let numbers { LiveNumbersGrid(numbers: numbers, oneRow: true) }
                        if let advice { AssistantTicker(text: advice, compact: true) }
                        // Device feedback: the column centred itself; now it spans the ground panel,
                        // with the over and the controls at the foot.
                        Spacer(minLength: 6)
                        HStack(spacing: 5) {
                            ForEach(Array(thisOver.enumerated()), id: \.offset) { _, e in
                                BallChip(label: e.label, size: 24).transition(.scale.combined(with: .opacity))
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(height: 26)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: thisOver.count)
                        mentality
                        HStack(spacing: 8) {
                            PauseButton(paused: paused) { if paused { paused = false } else { pauseForCentre() } }
                            SpeedPicker(speed: $speed, options: MatchView.speeds.map(\.value),
                                        labels: MatchView.speeds.map(\.label))
                        }
                    }
                    .frame(width: col)
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
                .frame(width: col)

                FieldOrWheel(shots: shots, latest: shown - 1)
                    .frame(width: col, height: geo.size.height)
                    .overlay {
                        if let e = current, !anticipating { BigCall(event: e).id(shown) }
                    }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(.horizontal, DS.Space.sm)
        .padding(.vertical, 4)
    }

    /// "Bumrah runs in to Kohli…" before the ball, then the result.
    @ViewBuilder private func statusLine(current: BallEvent?, anticipating: Bool, compact: Bool = false) -> some View {
        let text: String = {
            if anticipating, shown < log.count {
                let next = log[shown]
                return "🏃 \(next.bowler.name) runs in to \(striker(before: shown))…"
            }
            if let c = current {
                if MatchView.isOverEnd(c) {
                    let rr = c.over >= 0 ? Double(c.score) * 6 / Double(max(1, (c.over + 1) * 6)) : 0
                    return "End of over \(c.over + 1) · \(c.score)/\(c.wickets) · RR \(String(format: "%.1f", rr))"
                }
                return c.text
            }
            return "Players walk out…"
        }()
        Text(text)
            .font(.display(compact ? 15 : 17, weight: .heavy))
            .foregroundStyle(anticipating ? Palette.muted : .white)
            .lineLimit(2).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: compact ? 34 : 40, alignment: .leading)
            .animation(.easeInOut(duration: 0.2), value: text)
    }

    /// Who faces the next ball.
    private func striker(before i: Int) -> String {
        guard i > 0, log[i - 1].innings == log[i].innings else {
            return log[i].batters.first(where: \.onStrike)?.name ?? ""
        }
        let prev = log[i - 1]
        let onStrike = MatchView.isOverEnd(prev) ? prev.batters.first { !$0.onStrike } : prev.batters.first(where: \.onStrike)
        return onStrike?.name ?? ""
    }

    private func overString(_ e: BallEvent) -> String {
        let balls = e.over * 6 + e.ballInOver
        return "\(balls / 6).\(balls % 6)"
    }
}

/// The live numbers (the ⏸ Overview's tiles) on the match screen: run rate, required rate or
/// projection, last five overs, partnership, 4s · 6s, dot balls. One row in landscape.
struct LiveNumbersGrid: View {
    let numbers: LiveReport.Numbers
    var oneRow = false

    var body: some View {
        let n = numbers
        let cols = Array(repeating: GridItem(.flexible(), spacing: 5), count: oneRow ? 6 : 3)
        LazyVGrid(columns: cols, spacing: 5) {
            tile(String(format: "%.2f", n.runRate), "Run rate")
            if let rrr = n.requiredRate {
                tile(String(format: "%.2f", rrr), "Required", rrr > n.runRate + 1.5 ? .orange : Palette.accent)
            } else {
                tile(n.projected.map { "\($0)" } ?? "–", "Projected")
            }
            tile("\(n.lastFive)", "Last 5 ov")
            tile("\(n.partnershipRuns) (\(n.partnershipBalls))", "Stand")
            tile("\(n.fours) · \(n.sixes)", "4s · 6s")
            tile("\(n.dotPercent)%", "Dots", n.dotPercent >= 45 ? .orange : .white)
        }
    }

    private func tile(_ value: String, _ label: String, _ color: Color = .white) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.score(oneRow ? 13 : 16)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased()).font(.system(size: (oneRow ? 7.5 : 9) * TextScale.factor, weight: .heavy))
                .foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, oneRow ? 5 : 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.surface))
    }
}

/// The assistant manager's top line, live on the match screen.
struct AssistantTicker: View {
    let text: String
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "person.wave.2.fill")
                .font(.system(size: (compact ? 12 : 14) * TextScale.factor, weight: .semibold))
                .foregroundStyle(Palette.accent)
            Text(text).font(.system(size: (compact ? 12 : 13) * TextScale.factor, weight: .semibold))
                .foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10).padding(.vertical, compact ? 6 : 9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surface))
        .animation(.easeInOut(duration: 0.2), value: text)
    }
}

/// Three-way mentality switch on the match screen: the current setting highlighted.
struct MentalityBar: View {
    let title: String
    let options: [String]
    let selected: Int
    let pick: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased()).font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
                .frame(width: 58, alignment: .leading)
            ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                Button { if i != selected { pick(i) } } label: {
                    Text(option).font(.system(size: 13 * TextScale.factor, weight: .semibold))
                        .foregroundStyle(i == selected ? Palette.ink : .white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(i == selected ? Palette.accent : Palette.surfaceHi))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("mentality.\(option)")
            }
        }
    }
}

/// Pause / play beside the speed picker, the segmented control's height so the row lines up.
struct PauseButton: View {
    let paused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: paused ? "play.fill" : "pause.fill")
                .font(.system(size: 15 * TextScale.factor, weight: .bold))
                .foregroundStyle(Palette.accent)
                .frame(width: 56, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.surfaceHi))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pause")
    }
}

/// TV-style score strip: batting team, score, overs, chase equation.
struct ScoreBug: View {
    @EnvironmentObject var store: GameStore
    let result: MatchResult
    let event: BallEvent?
    var compact = false

    var body: some View {
        let inn = event?.innings ?? 0
        let batting = store.team(result.card(inn).teamId)
        let bowling = store.team(result.fieldingTeam(inn))
        let balls = event.map { $0.over * 6 + $0.ballInOver } ?? 0
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    if let batting { TeamBadge(team: batting, size: compact ? 26 : 34) }
                    Text(batting?.short ?? "").font(.display(compact ? 19 : 24))
                }
                .padding(.horizontal, compact ? 8 : 12).padding(.vertical, compact ? 5 : 8)
                .background(Color(hex: batting?.colorHex ?? "#333333"))
                HStack(spacing: 6) {
                    Text("\(event?.score ?? 0)-\(event?.wickets ?? 0)").font(.score(compact ? 24 : 30)).lineLimit(1).minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.25), value: event?.score)
                    Text("\(balls / 6).\(balls % 6)").font(.score(16, weight: .semibold)).foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, compact ? 8 : 12)
                Spacer(minLength: 4)
                Text("v \(bowling?.short ?? "")").font(.display(compact ? 14 : 16, weight: .heavy)).foregroundStyle(Palette.muted)
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
            .padding(.horizontal, compact ? 8 : 12).padding(.vertical, compact ? 2 : 4)
            .background(Palette.accent)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(Palette.stroke))
    }

    private func equation(inn: Int, balls: Int) -> String {
        let tag = inn >= 2 ? "SUPER OVER · " : ""
        guard let target = result.target(forInnings: inn) else {
            let rr = balls > 0 ? Double(event?.score ?? 0) * 6 / Double(balls) : 0
            return tag + "RUN RATE \(String(format: "%.2f", rr))"
        }
        let need = max(0, target - (event?.score ?? 0))
        let left = result.maxBalls(inn) - balls
        if need == 0 { return tag + "TARGET REACHED" }
        return tag + "NEED \(need) OFF \(left) · TARGET \(target)"
    }
}

/// The two batters at the crease and the current bowler, like a broadcast lower third.
struct CreaseCard: View {
    let event: BallEvent
    let battingTeam: Franchise?
    var compact = false
    /// Batting order (names). The pair stays in this order and only the strike marker moves
    /// (device feedback: rows swapping places on every single was hard to follow).
    var order: [String] = []

    private var pair: [LiveBatter] {
        let index = { (b: LiveBatter) in order.firstIndex(of: b.name) ?? Int.max }
        return event.batters.sorted { index($0) != index($1) ? index($0) < index($1) : $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(pair, id: \.name) { b in
                HStack(spacing: 8) {
                    Rectangle().fill(b.onStrike ? Palette.accent : Color.clear).frame(width: 4, height: compact ? 18 : 22)
                    Text(b.name.uppercased() + (b.onStrike ? " *" : ""))
                        .font(.display(compact ? 15 : 18, weight: b.onStrike ? .black : .heavy)).lineLimit(1).minimumScaleFactor(0.6)
                    Spacer(minLength: 4)
                    Text("\(b.runs)").font(.score(compact ? 18 : 22)).lineLimit(1).fixedSize()
                        .contentTransition(.numericText())
                    Text("(\(b.balls))").font(.score(14, weight: .regular)).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.7).frame(width: 44, alignment: .leading)
                    Text("\(b.fours)×4 \(b.sixes)×6").font(.score(12, weight: .regular)).foregroundStyle(Palette.muted)
                        .lineLimit(1).minimumScaleFactor(0.6).frame(width: 52, alignment: .trailing)
                }
                .padding(.vertical, compact ? 3 : 6).padding(.trailing, compact ? 8 : 12)
            }
            Rectangle().fill(Palette.stroke).frame(height: 1)
            HStack(spacing: 8) {
                Image(systemName: "figure.cricket").foregroundStyle(Palette.muted).frame(width: 18)
                Text(event.bowler.name.uppercased()).font(.display(compact ? 14 : 17, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                Text("\(event.bowler.overs)-\(event.bowler.runs)-\(event.bowler.wickets)").font(.score(compact ? 17 : 20)).lineLimit(1).fixedSize()
                let econ = event.bowler.balls > 0 ? Double(event.bowler.runs) * 6 / Double(event.bowler.balls) : 0
                Text("ECON \(String(format: "%.1f", econ))").font(.score(12, weight: .regular)).foregroundStyle(Palette.muted)
                    .lineLimit(1).minimumScaleFactor(0.6).frame(width: 52, alignment: .trailing)
            }
            .padding(.vertical, compact ? 5 : 8).padding(.horizontal, compact ? 8 : 12)
        }
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(Palette.stroke))
        .animation(.spring(response: 0.3), value: event.batters.map(\.runs))
    }
}

struct BallChip: View {
    let label: String
    var size: CGFloat = 30
    var body: some View {
        let color: Color = label == "W" ? Palette.wicket : label == "6" ? Palette.six : label == "4" ? Palette.four : Color.white.opacity(0.14)
        Text(label)
            .font(.caption.weight(.heavy))
            .frame(width: size, height: size)
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
    /// Open on the highlights reel (straight after a quick-simmed match).
    var autoplay = false
    @State private var reelDone = false

    var body: some View {
        Group {
            if let r = store.result(resultId) {
                if autoplay && !reelDone && !(r.highlights ?? []).isEmpty {
                    HighlightsReel(result: r) { withAnimation(.easeInOut) { reelDone = true } }
                } else {
                    MatchResultContent(result: r)
                }
            } else {
                Text("Result not found").foregroundStyle(.secondary)
            }
        }
        .background(AppBackground())
        .navigationTitle("Scorecard")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// After the match: the broadcast-style summary board, then the full scorecard on demand.
/// Landscape: no scrolling, the board and its buttons fit the screen (device feedback).
struct MatchResultContent: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.verticalSizeClass) private var vSize
    let result: MatchResult
    @State private var showReel = false

    var body: some View {
        Group {
            if vSize == .compact {
                content
                    .padding(.horizontal, DS.Space.md)
                    .padding(.vertical, 6)
                    .frame(maxWidth: 900, maxHeight: .infinity, alignment: .top)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    content
                        .padding(.horizontal, DS.Space.md)
                        .padding(.vertical, DS.Space.sm)
                        .frame(maxWidth: 860)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .fullScreenCover(isPresented: $showReel) {
            HighlightsReel(result: result) { showReel = false }
                .environmentObject(store)
        }
    }

    private var content: some View {
        VStack(spacing: 8) {
            MatchSummaryBoard(result: result, compact: vSize == .compact)
            HStack(spacing: DS.Space.sm) {
                NavigationLink {
                    FullScorecardView(result: result)
                        .background(AppBackground())
                        .navigationTitle("Scorecard")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Full scorecard", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(SecondaryButtonStyle())
                if !(result.highlights ?? []).isEmpty {
                    Button { showReel = true } label: { Label("Highlights", systemImage: "play.fill") }
                        .buttonStyle(PrimaryButtonStyle())
                }
                if result.stage == .final, !store.inCareer, store.game?.phase == .season, store.game?.championId != nil {
                    Button("🏆 Trophy ceremony") { store.finishSeason() }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }
}

/// Broadcast-style summary (like a TV graphic): a title band, then for each innings a team band
/// with overs and score, the top three batters beside the top three bowlers against them, and a
/// result band at the foot.
struct MatchSummaryBoard: View {
    @EnvironmentObject var store: GameStore
    let result: MatchResult
    /// Landscape: tighter rows so the board and its buttons fit without scrolling.
    var compact = false

    var body: some View {
        let a = result.innings[0], b = result.innings.count > 1 ? result.innings[1] : result.innings[0]
        VStack(spacing: 0) {
            titleBand
            inningsBlock(a)
            inningsBlock(b)
            resultBand
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    }

    private var titleBand: some View {
        let home = store.team(result.teamA)?.short ?? "", away = store.team(result.teamB)?.short ?? ""
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(result.stage == .league ? "LEAGUE MATCH" : result.stage.label.uppercased())
                .font(.system(size: 20 * TextScale.factor, weight: .black))
                .foregroundStyle(.white)
            Text("\(home) v \(away) · \(result.pitch.icon) \(result.pitch.label)")
                .font(.system(size: 12 * TextScale.factor, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, compact ? 7 : 8)
        .background(Palette.surfaceHi)
    }

    private func inningsBlock(_ inn: InningsCard) -> some View {
        let team = store.team(inn.teamId)
        let batters = inn.batters.filter(\.batted)
            .sorted { $0.runs != $1.runs ? $0.runs > $1.runs : $0.balls < $1.balls }.prefix(3)
        let bowlers = inn.bowlers.filter { $0.balls > 0 }
            .sorted { $0.wickets != $1.wickets ? $0.wickets > $1.wickets : $0.runs < $1.runs }.prefix(3)
        let rows = max(batters.count, bowlers.count)
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let team { TeamBadge(team: team, size: 24) }
                Text(team?.name.uppercased() ?? "").font(.system(size: 15 * TextScale.factor, weight: .heavy)).lineLimit(1)
                Spacer(minLength: 6)
                Text("OVERS \(inn.overs)").font(.system(size: 11 * TextScale.factor, weight: .bold)).opacity(0.85)
                Text(inn.wickets >= 10 ? "\(inn.runs)" : "\(inn.runs)-\(inn.wickets)").font(.score(24))
                    .frame(minWidth: 70, alignment: .trailing)
                // The total's right edge lines up with the big figures below (star + balls columns).
                Color.clear.frame(width: MatchSummaryBoard.tailWidth - 10, height: 1)
            }
            .foregroundStyle(team.map { MatchSummaryBoard.isLight($0.colorHex) } == true ? Palette.ink : .white)
            .padding(.horizontal, 14).padding(.vertical, compact ? 5 : 6)
            .background(team.map { Color(hex: $0.colorHex) } ?? Palette.surfaceHi)
            ForEach(0..<rows, id: \.self) { i in
                HStack(spacing: 0) {
                    cell(name: i < batters.count ? batters[i].name : nil,
                         big: i < batters.count ? "\(batters[i].runs)" : "",
                         star: i < batters.count && batters[i].dismissal == nil,
                         small: i < batters.count ? "\(batters[i].balls)" : "")
                    Rectangle().fill(Palette.stroke).frame(width: 1)
                    cell(name: i < bowlers.count ? bowlers[i].name : nil,
                         big: i < bowlers.count ? "\(bowlers[i].wickets)-\(bowlers[i].runs)" : "",
                         star: false,
                         small: i < bowlers.count ? bowlers[i].overs : "")
                }
                .frame(height: compact ? 29 : 30)
                .background(i % 2 == 0 ? Palette.surface : Palette.surface.opacity(0.75))
            }
        }
    }

    /// Width after the big figure: the not-out star slot, a gap and the balls/overs column.
    static let tailWidth: CGFloat = 12 + 6 + 28

    /// "Will JACKS   96* 55": first names light, surname bold, big figure, small balls/overs. Fixed
    /// columns, so runs and figures line up down the board whatever the digits or the star.
    private func cell(name: String?, big: String, star: Bool, small: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let name {
                let parts = name.split(separator: " ")
                let last = parts.last.map(String.init) ?? name
                let first = parts.dropLast().joined(separator: " ")
                HStack(spacing: 4) {
                    if !first.isEmpty { Text(first).font(.system(size: 13 * TextScale.factor)).foregroundStyle(Palette.muted) }
                    Text(last.uppercased()).font(.system(size: 13 * TextScale.factor, weight: .bold))
                }
                .lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(big).font(.score(19)).frame(minWidth: 52, alignment: .trailing)
                    Text(star ? "*" : "").font(.score(15)).frame(width: 12, alignment: .leading)
                }
                Text(small).font(.score(11, weight: .regular)).foregroundStyle(Palette.muted).frame(width: 28, alignment: .leading)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
    }

    /// Light team colours (yellow, gold) need dark text on the band.
    static func isLight(_ hex: String) -> Bool {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count >= 6, let v = UInt32(h.prefix(6), radix: 16) else { return false }
        let r = Double((v >> 16) & 0xFF) / 255, g = Double((v >> 8) & 0xFF) / 255, b = Double(v & 0xFF) / 255
        return 0.299 * r + 0.587 * g + 0.114 * b > 0.6
    }

    private var resultBand: some View {
        HStack(spacing: 10) {
            Text("\(store.team(result.winnerId)?.short ?? "") \(result.margin)".uppercased())
                .font(.system(size: 14 * TextScale.factor, weight: .heavy))
            Spacer(minLength: 6)
            Label(result.potmName, systemImage: "star.fill").font(.system(size: 13 * TextScale.factor, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 14).padding(.vertical, compact ? 7 : 8)
        .background(Palette.accent)
    }
}

/// The complete scorecard: summary, bowling and batting panels with team toggles.
struct FullScorecardView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.verticalSizeClass) private var vSize
    let result: MatchResult
    @State private var showReel = false
    /// Which team's batting and bowling the two scorecard panels show (each has its own toggle).
    @State private var batTeam: Int? = nil
    @State private var bowlTeam: Int? = nil

    private var landscape: Bool { vSize == .compact }
    private var teams: [Int] { result.innings.prefix(2).map(\.teamId) }
    private var shownBat: Int { batTeam ?? teams.first ?? result.teamA }
    /// Default bowling view: the side that bowled to the batting innings on show.
    private var shownBowl: Int { bowlTeam ?? teams.last ?? result.teamB }

    var body: some View {
        Group {
            if landscape {
                // Device feedback: summary and bowling on the left, batting on the right; each scrolls on its own.
                HStack(alignment: .top, spacing: DS.Space.md) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Space.md) {
                            header
                            bowlingPanel
                            extras
                        }
                        .padding(.vertical, DS.Space.sm)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Space.md) { battingPanel }
                            .padding(.vertical, DS.Space.sm)
                    }
                }
                .padding(.horizontal, DS.Space.md)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.md) {
                        header
                        battingPanel
                        bowlingPanel
                        extras
                    }
                    .padding(DS.Space.md)
                }
            }
        }
        .fullScreenCover(isPresented: $showReel) {
            HighlightsReel(result: result) { showReel = false }
                .environmentObject(store)
        }
    }

    /// Winner, margin, player of the match, toss and pitch in a compact card.
    private var header: some View {
        let w = store.team(result.winnerId)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if let w { TeamBadge(team: w, size: 32) }
                VStack(alignment: .leading, spacing: 1) {
                    if result.stage != .league {
                        Text(result.stage.label.uppercased()).font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.accent)
                    }
                    Text("\(w?.short ?? "") \(result.margin)").font(.system(size: 17 * TextScale.factor, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                if !(result.highlights ?? []).isEmpty {
                    Button { showReel = true } label: { Label("Highlights", systemImage: "play.fill").font(.system(size: 12 * TextScale.factor, weight: .bold)) }
                }
            }
            Label("Player of the match: \(result.potmName)", systemImage: "star.fill")
                .font(.system(size: 13 * TextScale.factor, weight: .semibold))
            Text("\(store.team(result.tossWinner)?.short ?? "") won the toss · \(store.team(result.innings[0].teamId)?.short ?? "") batted first · \(result.pitch.icon) \(result.pitch.label)")
                .font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(2)
            if result.stage == .final, !store.inCareer, store.game?.phase == .season, store.game?.championId != nil {
                Button("🏆 Trophy ceremony") { store.finishSeason() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surface))
    }

    private var battingPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel(text: "Batting")
                Spacer()
                TeamToggle(teams: teams, selected: Binding(get: { shownBat }, set: { batTeam = $0 }), result: result)
            }
            if let inn = result.innings.prefix(2).first(where: { $0.teamId == shownBat }) {
                BattingTable(innings: inn)
            }
            if let so = result.superOvers, !so.isEmpty {
                SectionLabel(text: so.count > 2 ? "Super Overs" : "Super Over")
                ForEach(Array(so.enumerated()), id: \.offset) { _, inn in InningsCardView(innings: inn) }
            }
        }
    }

    private var bowlingPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel(text: "Bowling")
                Spacer()
                TeamToggle(teams: teams, selected: Binding(get: { shownBowl }, set: { bowlTeam = $0 }), result: result, showScore: false)
            }
            // A team's bowling is in the innings the other side batted.
            if let inn = result.innings.prefix(2).first(where: { $0.teamId != shownBowl }) {
                BowlingTable(innings: inn)
            }
        }
    }

    /// Runs per over and the highlights list, below the scorecards.
    @ViewBuilder private var extras: some View {
        manhattan
        if let moments = result.highlights, !moments.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionLabel(text: "Highlights")
                HighlightsList(moments: moments)
                Button { showReel = true } label: { Label("Watch highlights", systemImage: "play.fill") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    /// Manhattan: runs in every over for both sides, red dots for wickets.
    private var manhattan: some View {
        let a = result.innings[0], b = result.innings[1]
        let ta = store.team(a.teamId), tb = store.team(b.teamId)
        let nameA = ta?.short ?? "A", nameB = (tb?.short ?? "B") == nameA ? nameA + " " : (tb?.short ?? "B")
        let bars = a.perOver.enumerated().map { OverBar(team: nameA, over: $0.offset + 1, runs: $0.element.runs, wickets: $0.element.wickets) }
            + b.perOver.enumerated().map { OverBar(team: nameB, over: $0.offset + 1, runs: $0.element.runs, wickets: $0.element.wickets) }
        return VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Runs per over")
            AppCard(padding: DS.Space.md) {
                Chart(bars) { p in
                    BarMark(x: .value("Over", String(p.over)), y: .value("Runs", p.runs), width: .ratio(0.85))
                        .foregroundStyle(by: .value("Team", p.team))
                        .position(by: .value("Team", p.team))
                        .annotation(position: .top, spacing: 1) {
                            if p.wickets > 0 {
                                VStack(spacing: 1) {
                                    ForEach(0..<min(p.wickets, 3), id: \.self) { _ in
                                        Circle().fill(Palette.wicket).frame(width: 4, height: 4)
                                    }
                                }
                            }
                        }
                }
                .chartForegroundStyleScale(domain: [nameA, nameB],
                                           range: [ta.map { Color(hex: $0.colorHex) } ?? .blue,
                                                   tb.map { Color(hex: $0.colorHex) } ?? .orange])
                .chartXAxis {
                    AxisMarks(values: ["1", "5", "10", "15", "20"]) { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: 190)
                HStack(spacing: 6) {
                    Circle().fill(Palette.wicket).frame(width: 5, height: 5)
                    Text("= wicket in that over").font(.caption2).foregroundStyle(Palette.muted)
                }
            }
        }
    }
}

struct OverBar: Identifiable {
    var id: String { "\(team)-\(over)" }
    let team: String
    let over: Int
    let runs: Int
    let wickets: Int
}

/// Live over-by-over bars for the innings in progress (no Charts, updates every ball).
struct LiveOverBars: View {
    let perOver: [(runs: Int, wickets: Int)]
    let color: Color

    var body: some View {
        let maxRuns = max(12, perOver.map { $0.runs }.max() ?? 0)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<20, id: \.self) { i in
                    VStack(spacing: 2) {
                        if i < perOver.count, perOver[i].wickets > 0 {
                            Circle().fill(Palette.wicket).frame(width: 4, height: 4)
                        }
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < perOver.count ? color.opacity(i == perOver.count - 1 ? 1 : 0.7) : Color.white.opacity(0.06))
                            .frame(height: i < perOver.count ? max(2, CGFloat(perOver[i].runs) / CGFloat(maxRuns) * 60) : 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 70, alignment: .bottom)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: perOver.map { $0.runs })
            HStack {
                Text("1").font(.score(10)); Spacer(); Text("10").font(.score(10)); Spacer(); Text("20").font(.score(10))
            }
            .foregroundStyle(Palette.muted)
        }
    }
}

struct InningsCardView: View {
    @EnvironmentObject var store: GameStore
    let innings: InningsCard

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            BattingTable(innings: innings)
            BowlingTable(innings: innings)
        }
    }
}

/// Two-team switch for a scorecard panel (short name, and the score when it helps).
struct TeamToggle: View {
    @EnvironmentObject var store: GameStore
    let teams: [Int]
    @Binding var selected: Int
    let result: MatchResult
    var showScore = true

    var body: some View {
        HStack(spacing: 4) {
            ForEach(teams, id: \.self) { id in
                let on = id == selected
                Button { selected = id; Haptics.tap() } label: {
                    HStack(spacing: 5) {
                        if let t = store.team(id) { TeamBadge(team: t, size: 16) }
                        Text(store.team(id)?.short ?? "").font(.system(size: 12 * TextScale.factor, weight: .bold))
                        if showScore, let inn = result.innings.prefix(2).first(where: { $0.teamId == id }) {
                            Text(inn.score).font(.score(12))
                        }
                    }
                    .foregroundStyle(on ? Palette.ink : .white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(on ? Palette.accent : Palette.surface))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// One innings' batting: score line, batters, extras, did not bat. Compact type.
struct BattingTable: View {
    @EnvironmentObject var store: GameStore
    let innings: InningsCard

    var body: some View {
        let team = store.team(innings.teamId)
        let batted = innings.batters.filter(\.batted)
        let dnb = innings.batters.filter { !$0.batted }.map(\.name)
        VStack(spacing: 6) {
            HStack {
                if let team { TeamBadge(team: team, size: 22) }
                Text(team?.name ?? "").font(.system(size: 14 * TextScale.factor, weight: .bold)).lineLimit(1)
                Spacer()
                Text(innings.score).font(.score(18))
                Text("(\(innings.overs))").font(.score(12, weight: .regular)).foregroundStyle(Palette.muted)
            }
            HStack {
                Text("Batter").frame(maxWidth: .infinity, alignment: .leading)
                Text("R").frame(width: 36, alignment: .trailing)
                Text("B").frame(width: 32, alignment: .trailing)
                Text("4s").frame(width: 24, alignment: .trailing)
                Text("6s").frame(width: 24, alignment: .trailing)
                Text("SR").frame(width: 44, alignment: .trailing)
            }
            .font(.system(size: 11 * TextScale.factor, weight: .bold)).foregroundStyle(Palette.muted)
            ForEach(batted) { b in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(b.name).font(.system(size: 13 * TextScale.factor, weight: .semibold)).lineLimit(1)
                        Text(b.dismissal ?? "not out").font(.system(size: 11 * TextScale.factor))
                            .foregroundStyle(b.dismissal == nil ? Palette.four : Palette.muted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(b.runs)").fontWeight(.bold).frame(width: 36, alignment: .trailing)
                    Text("\(b.balls)").frame(width: 32, alignment: .trailing)
                    Text("\(b.fours)").frame(width: 24, alignment: .trailing)
                    Text("\(b.sixes)").frame(width: 24, alignment: .trailing)
                    Text(b.balls > 0 ? String(format: "%.0f", b.strikeRate) : "–").foregroundStyle(Palette.muted).frame(width: 44, alignment: .trailing)
                }
                .font(.system(size: 13 * TextScale.factor).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.8)
            }
            HStack {
                Text("Extras").foregroundStyle(Palette.muted)
                Spacer()
                Text("\(innings.extras)")
            }
            .font(.system(size: 12 * TextScale.factor))
            if !dnb.isEmpty {
                Text("Did not bat: " + dnb.joined(separator: ", "))
                    .font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surface))
    }
}

/// One innings' bowling (the fielding side's bowlers). Compact type.
struct BowlingTable: View {
    let innings: InningsCard

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Bowler").frame(maxWidth: .infinity, alignment: .leading)
                Text("O").frame(width: 32, alignment: .trailing)
                Text("R").frame(width: 32, alignment: .trailing)
                Text("W").frame(width: 24, alignment: .trailing)
                Text("Econ").frame(width: 42, alignment: .trailing)
            }
            .font(.system(size: 11 * TextScale.factor, weight: .bold)).foregroundStyle(Palette.muted)
            ForEach(innings.bowlers.filter { $0.balls > 0 }) { bw in
                HStack {
                    Text(bw.name).font(.system(size: 13 * TextScale.factor, weight: .semibold)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    Text(bw.overs).frame(width: 32, alignment: .trailing)
                    Text("\(bw.runs)").frame(width: 32, alignment: .trailing)
                    Text("\(bw.wickets)").fontWeight(.bold).frame(width: 24, alignment: .trailing)
                    Text(String(format: "%.1f", bw.economy)).frame(width: 42, alignment: .trailing)
                }
                .font(.system(size: 13 * TextScale.factor).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surface))
    }
}
