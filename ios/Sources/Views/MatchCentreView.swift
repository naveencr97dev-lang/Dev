import SwiftUI

/// Opened by ⏸ during a live match, laid out like Soccer Manager's in-match panel: a tab rail
/// (left in landscape, chips in portrait) over Overview (the key numbers and the assistant's
/// advice), live Ratings for both XIs, Around the league (the round's other results), the
/// scorecard so far and, in your own career matches, tactics, batting order and bowling changes
/// that apply from the next ball.
struct MatchCentreView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let result: MatchResult
    let log: [BallEvent]
    let shown: Int
    /// The user's team in this match, if changes are allowed.
    let userTeam: Int?
    let tactics: Tactics
    /// The round's other results (career), for Around the league, and its matches still to come.
    var round: [MatchResult] = []
    var roundLater: [Fixture] = []
    /// The tab to open on (the match screen's Order and Plan buttons).
    var initialTab: Tab = .tactics
    /// Applies a change; returns false if it couldn't be applied.
    let apply: (LiveChange) -> Bool

    enum Tab: String, CaseIterable, Identifiable {
        case ratings = "Ratings", league = "Around the league", scorecard = "Scorecard"
        case tactics = "Tactics", batting = "Batting", bowling = "Bowling"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .ratings: return "star"
            case .league: return "trophy"
            case .scorecard: return "list.bullet.rectangle"
            case .tactics: return "slider.horizontal.3"
            case .batting: return "arrow.up.arrow.down"
            case .bowling: return "figure.cricket"
            }
        }
        var short: String { self == .league ? "Scores" : rawValue }
    }

    @Environment(\.verticalSizeClass) private var vSize
    @State private var tab: Tab = .ratings
    /// The whole tactics set, edited on the Tactics tab (owner's request: the full screen mid-match).
    @State private var live = Tactics()
    @State private var order: [String] = []
    @State private var plan: [String] = []
    @State private var nextBowler = ""
    @State private var message: String? = nil
    @State private var loaded = false

    private var current: BallEvent? { shown > 0 && shown <= log.count ? log[shown - 1] : nil }
    private var cards: [InningsCard] { MatchEngine.scorecardSoFar(result: result, log: log, upTo: shown) }
    private var batInnings: Int? { userTeam.flatMap { t in [0, 1].first { result.card($0).teamId == t } } }
    private var bowlInnings: Int? { batInnings.map { 1 - $0 } }

    private var tabs: [Tab] {
        // Owner's request: tactics first, so a change is one tap away (the numbers and the
        // assistant are on the match screen itself; the Overview tab is gone).
        var t: [Tab] = userTeam != nil ? [.tactics, .batting, .bowling, .ratings] : [.ratings]
        if !round.isEmpty || !roundLater.isEmpty { t.append(.league) }
        t.append(.scorecard)
        return t
    }

    var body: some View {
        NavigationStack {
            Group {
                if vSize == .compact {
                    HStack(spacing: 0) {
                        rail
                        Rectangle().fill(Palette.stroke).frame(width: 0.5)
                        page.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                } else {
                    VStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(tabs) { t in
                                    FilterChip(title: t.short, on: tab == t) { tab = t }.accessibilityIdentifier("centre.\(t.rawValue)")
                                }
                            }
                            .padding(.horizontal, DS.Space.md)
                        }
                        .padding(.vertical, DS.Space.sm)
                        page.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
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

    /// Landscape: the tabs down the left, icon over label (like the hub rail).
    private var rail: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(tabs) { t in
                    Button { tab = t; Haptics.tap() } label: {
                        VStack(spacing: 3) {
                            Image(systemName: t.icon).font(.system(size: 16 * TextScale.factor, weight: .semibold))
                            Text(t.short).font(.system(size: 10 * TextScale.factor, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(tab == t ? Palette.accent : Palette.muted)
                        .frame(width: 72, height: 46)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tab == t ? Palette.accent.opacity(0.14) : Color.clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("centre.\(t.rawValue)")
                }
            }
            .padding(.vertical, DS.Space.sm)
            .padding(.horizontal, 6)
        }
        .frame(width: 84)
    }

    @ViewBuilder private var page: some View {
        VStack(spacing: 0) {
            if let message {
                Text(message).font(.system(size: 12 * TextScale.factor, weight: .bold)).foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.Space.md).padding(.top, DS.Space.sm)
            }
            switch tab {
            case .ratings: ratingsTab
            case .league: leagueTab
            case .tactics: tacticsTab
            case .batting: battingTab.padding(.top, DS.Space.sm)
            case .bowling: bowlingTab.padding(.top, DS.Space.sm)
            case .scorecard: scorecardTab
            }
        }
    }

    // MARK: Ratings: both XIs side by side

    private var ratingsTab: some View {
        let sides = [0, 1].map { result.card($0) }
        let wide = vSize == .compact
        let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: DS.Space.md))
                          : AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.md))
        return ScrollView {
            layout {
                ForEach(Array(sides.enumerated()), id: \.offset) { i, inn in
                    PanelBox(fill: false) { ratingsColumn(inn) }
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
        }
    }

    /// One XI: name, what he's done so far, and the live rating (3-10).
    private func ratingsColumn(_ inn: InningsCard) -> some View {
        let team = store.team(inn.teamId)
        let soFar = cards
        let batting = soFar.first { $0.teamId == inn.teamId }
        let bowled = soFar.first { $0.teamId != inn.teamId }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let team { TeamBadge(team: team, size: 22) }
                Text(team?.name.uppercased() ?? "").font(.system(size: 12 * TextScale.factor, weight: .heavy)).lineLimit(1)
                Spacer()
                Text("RATING").font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 10)
            ForEach(inn.batters) { b in
                let bat = batting?.batters.first { $0.id == b.id }
                let bowl = bowled?.bowlers.first { $0.id == b.id }
                let did = [bat.flatMap { $0.batted ? "\($0.runs)\($0.dismissal == nil ? "*" : "") (\($0.balls))" : nil },
                           bowl.flatMap { $0.balls > 0 ? "\($0.wickets)-\($0.runs)" : nil }].compactMap { $0 }
                let rating = LiveReport.involved(b.id, cards: soFar) ? LiveReport.rating(b.id, cards: soFar) : nil
                HStack(spacing: 8) {
                    TName(text: b.name, overseas: store.player(b.id)?.overseas ?? false, bold: rating != nil)
                    Text(did.joined(separator: " · ")).font(.score(11, weight: .semibold)).foregroundStyle(Palette.muted)
                        .lineLimit(1).frame(width: 96, alignment: .trailing)
                    TNum(text: rating.map { String(format: "%.1f", $0) } ?? "–", width: TCol.stat,
                         color: rating.map { RatingStyle.color($0) } ?? Palette.muted)
                }
                .tableRow(dimmed: rating == nil)
            }
        }
    }

    // MARK: Around the league

    private var leagueTab: some View {
        ScrollView {
            PanelBox(fill: false) {
                TableNote(text: "The round's other matches: results so far, and those still to play.")
                    .padding(.bottom, 2)
                ForEach(round) { r in
                    let a = r.innings.first, b = r.innings.count > 1 ? r.innings[1] : nil
                    HStack(spacing: 8) {
                        scoreSide(a, winner: r.winnerId)
                        Text("v").font(.system(size: 11 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted)
                        scoreSide(b, winner: r.winnerId)
                        Text("\(store.team(r.winnerId)?.short ?? "") \(r.margin)")
                            .font(.system(size: 11 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(width: vSize == .compact ? 200 : 120, alignment: .trailing)
                    }
                    .tableRow()
                }
                ForEach(roundLater) { f in
                    HStack(spacing: 8) {
                        fixtureSide(f.home)
                        Text("v").font(.system(size: 11 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted)
                        fixtureSide(f.away)
                        Text("After your match").font(.system(size: 11 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted)
                            .lineLimit(1).frame(width: vSize == .compact ? 200 : 120, alignment: .trailing)
                    }
                    .tableRow(dimmed: true)
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
        }
    }

    private func fixtureSide(_ teamId: Int) -> some View {
        HStack(spacing: 6) {
            if let t = store.team(teamId) {
                TeamBadge(team: t, size: 22)
                Text(t.short).font(.system(size: 13 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreSide(_ inn: InningsCard?, winner: Int) -> some View {
        HStack(spacing: 6) {
            if let inn, let t = store.team(inn.teamId) {
                TeamBadge(team: t, size: 22)
                Text(t.short).font(.system(size: 13 * TextScale.factor, weight: inn.teamId == winner ? .heavy : .semibold))
                    .foregroundStyle(inn.teamId == winner ? .white : Palette.muted)
                Spacer(minLength: 4)
                Text(inn.wickets >= 10 ? "\(inn.runs)" : "\(inn.runs)-\(inn.wickets)").font(.score(14))
                    .foregroundStyle(inn.teamId == winner ? .white : Palette.muted)
            }
        }
        .frame(maxWidth: .infinity)
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
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
        }
    }

    /// Powerplay, middle or death, from the ball shown.
    private var phaseNow: Int {
        guard let e = current else { return 0 }
        let over = e.ballInOver >= 6 ? e.over + 1 : e.over
        return over < 6 ? 0 : (over >= 16 ? 2 : 1)
    }

    /// The batting XI for roles: the user's side in this match, in batting order.
    private var userXI: [Player] {
        guard let bi = batInnings else { return [] }
        return result.card(bi).batters.compactMap { store.player($0.id) }
    }

    private var tacticsTab: some View {
        let wide = vSize == .compact
        let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: DS.Space.md))
                          : AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.sm))
        return ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(spacing: 6) {
                    TableNote(text: "Changes apply from the next ball. Toss and captain stay as they are for this match.")
                    Spacer(minLength: 4)
                    ActionChip(icon: "checkmark", title: "Apply", primary: true) { applyTactics(keep: false) }
                    ActionChip(icon: "square.and.arrow.down", title: "Apply and keep") { applyTactics(keep: true) }
                }
                layout {
                    TacticsEditor(t: $live, pitch: result.pitch, xi: userXI, part: .left, showToss: false)
                    TacticsEditor(t: $live, pitch: result.pitch, xi: userXI, part: .right, showToss: false)
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
        }
    }

    /// Sends the whole set from the next ball; "keep" also saves it for the next matches.
    private func applyTactics(keep: Bool) {
        var t = live
        // The toss and captain were settled before the first ball.
        t.toss = tactics.toss
        t.captain = tactics.captain
        var ch = change()
        ch.tactics = t
        let name = t.matchingPlan?.label ?? "Custom tactics"
        send(ch, keep ? "\(name) from the next ball, and saved for the next matches." : "\(name) from the next ball.")
        if keep, store.inCareer { store.careerSetTactics(t) }
    }

    private var battingTab: some View {
        let done = battedSoFar
        return PanelBox {
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
        return PanelBox {
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
        tab = tabs.contains(initialTab) ? initialTab : tabs[0]
        live = tactics
        if let bi = batInnings {
            order = result.card(bi).batters.map(\.id)
            let xi = order
            let used = result.card(1 - bi).bowlers.map(\.id).filter { xi.contains($0) }
            let others = xi.filter { !used.contains($0) }.sorted { (store.player($0)?.bowl ?? 0) > (store.player($1)?.bowl ?? 0) }
            plan = used + others
        }
    }
}
