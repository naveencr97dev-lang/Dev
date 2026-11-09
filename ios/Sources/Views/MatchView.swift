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
    @AppStorage("matchSpeedV3") private var speed: Double = 1
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
    @Environment(\.dismiss) private var dismiss
    private let clock = Timer.publish(every: MatchView.tick, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let r = result {
                if !finished && !log.isEmpty {
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
        .toolbar(vSize == .compact && !finished && !log.isEmpty ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !finished && !log.isEmpty {
                    HStack {
                        Button { pauseForCentre() } label: { Image(systemName: "list.clipboard") }
                        Button("Skip ⏭") { finish() }
                    }
                }
            }
        }
        .onAppear(perform: start)
        .onDisappear { if !showCentre { commitIfNeeded() } }
        .onReceive(clock) { _ in advance() }
        .sheet(isPresented: $showCentre, onDismiss: { paused = false }) {
            if let r = result {
                MatchCentreView(result: r, log: log, shown: shown,
                                userTeam: pendingCommit ? store.careerUserTeam(in: fixtureId) : nil,
                                tactics: changes.last(where: { $0.tactics != nil })?.tactics ?? store.career?.tactics ?? Tactics(),
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

    private func advance() {
        guard !finished, !log.isEmpty, !paused else { return }
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
                CreaseCard(event: e, battingTeam: store.team(r.card(e.innings).teamId))
            }
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
            HStack(spacing: 10) {
                Button { if paused { paused = false } else { pauseForCentre() } } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill").frame(width: 30)
                }
                .buttonStyle(SecondaryButtonStyle()).frame(width: 64)
                SpeedPicker(speed: $speed, options: MatchView.speeds.map(\.value),
                            labels: MatchView.speeds.map(\.label))
            }
        }

        return ZStack {
            Group {
                if vSize == .compact {
                    landscape(r, current: current, thisOver: thisOver, shots: shots, anticipating: anticipating)
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
                           shots: [WagonWheel.Shot], anticipating: Bool) -> some View {
        GeometryReader { geo in
            let gap: CGFloat = 12
            let col = max(0, (geo.size.width - gap) / 2)
            HStack(spacing: gap) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        HStack {
                            Button { dismiss() } label: { Label("Back", systemImage: "chevron.left") }
                            Spacer()
                            Button { finish() } label: { Label("Skip", systemImage: "forward.end.fill") }
                        }
                        .font(.display(15, weight: .heavy))
                        .foregroundStyle(Palette.accent)
                        ScoreBug(result: r, event: current, compact: true)
                        statusLine(current: current, anticipating: anticipating, compact: true)
                        if let e = current {
                            CreaseCard(event: e, battingTeam: store.team(r.card(e.innings).teamId), compact: true)
                        }
                        HStack(spacing: 5) {
                            ForEach(Array(thisOver.enumerated()), id: \.offset) { _, e in
                                BallChip(label: e.label, size: 24).transition(.scale.combined(with: .opacity))
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(height: 26)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: thisOver.count)
                        HStack(spacing: 8) {
                            Button { if paused { paused = false } else { pauseForCentre() } } label: {
                                Image(systemName: paused ? "play.fill" : "pause.fill").frame(width: 24)
                            }
                            .buttonStyle(SecondaryButtonStyle()).frame(width: 56)
                            SpeedPicker(speed: $speed, options: MatchView.speeds.map(\.value),
                                        labels: MatchView.speeds.map(\.label))
                        }
                    }
                    .frame(width: col)
                    .frame(minHeight: geo.size.height)
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

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(event.batters.enumerated()), id: \.offset) { _, b in
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

struct MatchResultContent: View {
    @EnvironmentObject var store: GameStore
    let result: MatchResult
    @State private var showReel = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Space.lg) {
                header
                if result.stage == .final, !store.inCareer, store.game?.phase == .season, store.game?.championId != nil {
                    Button("🏆 Trophy ceremony") { store.finishSeason() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                // Post-match order: scorecard, then worm, then highlights.
                ForEach(Array(result.innings.prefix(2).enumerated()), id: \.offset) { _, inn in
                    InningsCardView(innings: inn)
                }
                if let so = result.superOvers, !so.isEmpty {
                    SectionLabel(text: so.count > 2 ? "Super Overs" : "Super Over")
                    ForEach(Array(so.enumerated()), id: \.offset) { _, inn in
                        InningsCardView(innings: inn)
                    }
                }
                manhattan
                if let moments = result.highlights, !moments.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        HStack {
                            SectionLabel(text: "Highlights")
                            Spacer()
                            Button { showReel = true } label: {
                                Label("Watch", systemImage: "play.fill").font(.display(15, weight: .heavy))
                            }
                        }
                        HighlightsList(moments: moments)
                        Button { showReel = true } label: { Label("Watch highlights", systemImage: "play.fill") }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            .padding(DS.Space.lg)
        }
        .fullScreenCover(isPresented: $showReel) {
            HighlightsReel(result: result) { showReel = false }
                .environmentObject(store)
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
                        Text("R").frame(width: 42, alignment: .trailing)
                        Text("B").frame(width: 36, alignment: .trailing)
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
                            Text("\(b.runs)").fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.7).frame(width: 42, alignment: .trailing)
                            Text("\(b.balls)").lineLimit(1).minimumScaleFactor(0.7).frame(width: 36, alignment: .trailing)
                            Text("\(b.fours)").lineLimit(1).minimumScaleFactor(0.7).frame(width: 26, alignment: .trailing)
                            Text("\(b.sixes)").lineLimit(1).minimumScaleFactor(0.7).frame(width: 26, alignment: .trailing)
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
                        Text("O").frame(width: 34, alignment: .trailing)
                        Text("R").frame(width: 34, alignment: .trailing)
                        Text("W").frame(width: 26, alignment: .trailing)
                        Text("Econ").frame(width: 42, alignment: .trailing)
                    }
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(innings.bowlers.filter { $0.balls > 0 }) { bw in
                        HStack {
                            Text(bw.name).font(.subheadline.weight(.semibold)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            Text(bw.overs).lineLimit(1).minimumScaleFactor(0.7).frame(width: 34, alignment: .trailing)
                            Text("\(bw.runs)").lineLimit(1).minimumScaleFactor(0.7).frame(width: 34, alignment: .trailing)
                            Text("\(bw.wickets)").fontWeight(.bold).lineLimit(1).frame(width: 26, alignment: .trailing)
                            Text(String(format: "%.1f", bw.economy)).lineLimit(1).minimumScaleFactor(0.7).frame(width: 42, alignment: .trailing)
                        }
                        .font(.subheadline.monospacedDigit())
                    }
                }
            }
        }
    }
}
