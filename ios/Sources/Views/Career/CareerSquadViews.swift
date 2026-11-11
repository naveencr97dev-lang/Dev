import SwiftUI

// MARK: - Squad tab

struct CareerSquadTab: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.compactLandscape) private var compact
    @State private var selected: String? = nil
    @State private var message: String? = nil

    var body: some View {
        if let c = store.career {
            let club = c.userClub
            let squad = c.squad(club.id)
            let issues = c.xiIssues(club.id)
            let bench = squad.filter { !club.xi.contains($0.id) }.sorted { $0.rating > $1.rating }.map(\.id)
            // Device feedback: the XI is a fixed list on the left; tools and the bench on the right.
            // Device feedback: the XI fills the left; the bench and squad tools on the right.
            AdaptiveColumns(leftScrolls: false, rightScrolls: false) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Squad").font(.display(compact ? 18 : 28, weight: .bold))
                    Text("\(squad.count) players · \(squad.filter(\.overseas).count)/\(c.tuning.maxOverseasSquad) overseas · strength \(c.strength(club.id)) · home: \(c.homePitch(club.id).label)")
                        .font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(1)
                }
                EditableLineup(title: "Playing XI · batting order", ids: club.xi, fill: compact, selected: $selected, message: $message)
                    .frame(maxHeight: compact ? .infinity : nil)
                HStack(spacing: 8) {
                    Text(message ?? (selected == nil ? "Drag a bench player onto someone to swap, or tap one then the other." : "Now tap who to swap with."))
                        .font(.system(size: 11 * TextScale.factor, weight: message == nil ? .regular : .semibold))
                        .foregroundStyle(message == nil ? Palette.muted : Color.orange)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if let id = selected {
                        NavigationLink { CareerPlayerView(playerId: id) } label: {
                            Text("Open profile ›").font(.system(size: 11 * TextScale.factor, weight: .bold)).foregroundStyle(Palette.accent)
                        }
                    }
                }
            } right: {
                if !issues.isEmpty {
                    ForEach(issues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.triangle.fill").font(.display(12, weight: .semibold)).foregroundStyle(.orange)
                    }
                }
                if compact {
                    ScrollView {
                        EditableLineup(title: "Bench · \(bench.count)", ids: bench, numbered: false, selected: $selected, message: $message)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    EditableLineup(title: "Bench · \(bench.count)", ids: bench, numbered: false, selected: $selected, message: $message)
                }
                // Squad tools only; development, training, stats and reports live in Club.
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    NavigationLink { PickXIView() } label: { MiniTile(icon: "checklist", title: "Pick XI") }
                    NavigationLink { BattingOrderView(teamId: club.id) } label: { MiniTile(icon: "arrow.up.arrow.down", title: "Batting order") }
                    NavigationLink { BowlingPlanView(teamId: club.id) } label: { MiniTile(icon: "figure.cricket", title: "Bowling plan") }
                    NavigationLink { TacticsView() } label: { MiniTile(icon: "slider.horizontal.3", title: "Tactics") }
                    NavigationLink { SquadPlannerView() } label: {
                        MiniTile(icon: "square.grid.3x3", title: "Squad planner")
                    }
                    Button {
                        store.careerAutoXI()
                        Haptics.success()
                    } label: { MiniTile(icon: "sparkles", title: "Auto-pick XI", accent: true) }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Small grid tile: icon and title (the Squad tab's tools).
struct MiniTile: View {
    let icon: String
    let title: String
    var accent = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14 * TextScale.factor, weight: .medium))
                .foregroundStyle(accent ? Palette.ink : Palette.accent)
            Text(title).font(.system(size: 13 * TextScale.factor, weight: .semibold))
                .foregroundStyle(accent ? Palette.ink : .white).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(accent ? Palette.accent : Palette.surface))
        .contentShape(Rectangle())
    }
}

struct SquadAction: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3)
            Text(text.uppercased()).font(.display(12, weight: .heavy))
        }
        .foregroundStyle(Palette.accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surfaceHi))
    }
}

/// Compact career row: role, name, age, form and overall rating.
struct CareerPlayerRow: View {
    let player: CareerPlayer
    let year: Int
    @EnvironmentObject private var store: GameStore
    /// Home-pitch fit for the user's club: true suits, false struggles, nil neither (or not shown).
    var pitchFit: Bool? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(player.name).font(.body.weight(.semibold)).lineLimit(1)
                    if player.overseas { Image(systemName: "airplane").font(.caption2).foregroundStyle(Palette.muted) }
                    PitchFitMark(fit: pitchFit, size: 10)
                    if player.legend { Image(systemName: "star.fill").font(.caption2).foregroundStyle(CareerPalette.gold) }
                    if !player.traits.isEmpty { Text(player.traits.map(\.icon).joined()).font(.caption) }
                }
                HStack(spacing: 6) {
                    RoleChip(role: player.role)
                    Text("Age \(player.age(in: year)) · BAT \(player.bat) · BOWL \(player.bowl)")
                        .font(.caption2).foregroundStyle(Palette.muted)
                    Text("FORM \(FormStyle.text(store.career?.formScore(player.id)))")
                        .font(.caption2.weight(.bold)).foregroundStyle(FormStyle.color(store.career?.formScore(player.id)))
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(player.rating)").font(.display(26)).foregroundStyle(strengthColor(player.rating))
                Text(player.contract.map { Money.format($0.wage) } ?? "OVR")
                    .font(.display(10, weight: .heavy)).foregroundStyle(Palette.muted).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// MARK: - Pick XI

struct PickXIView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var loaded = false
    @State private var roleIndex = 0
    @State private var byRating = false

    private static let roles: [Role?] = [nil, .WK, .BAT, .AR, .BOWL]

    /// Device feedback: sort by type, openers first: batters by their slot (openers, top order,
    /// middle, finishers), then pace and spin bowlers.
    static func typeRank(_ p: CareerPlayer) -> Int {
        if p.role == .BOWL { return p.bowlType == .spin ? 11 : 10 }
        return p.slot.ordinal
    }

    static func typeName(_ p: CareerPlayer) -> String {
        if p.role == .BOWL { return p.bowlType == .spin ? "Spin bowlers" : "Pace bowlers" }
        switch p.slot {
        case .open: return "Openers"
        case .top: return "Top order"
        case .middle: return "Middle order"
        case .finish: return "Finishers"
        case .lower: return "Lower order"
        }
    }
    private static let roleLabels = ["All", "WK", "BAT", "AR", "BOWL"]

    var body: some View {
        let c = store.career
        let year = c?.year ?? 0
        let all = c.map { $0.squad($0.userClubId) } ?? []
        let squad = all
            .filter { p in Self.roles[roleIndex].map { p.role == $0 } ?? true }
            .sorted { a, b in
                if !byRating {
                    let (ta, tb) = (Self.typeRank(a), Self.typeRank(b))
                    if ta != tb { return ta < tb }
                }
                return a.rating != b.rating ? a.rating > b.rating : a.id < b.id
            }
        let picked = all.filter { selected.contains($0.id) }.compactMap { store.player($0.id) }
        let rules = c?.rules ?? Rules()
        let blocking = TeamSelector.blockingIssues(picked, rules: rules)
        let issues = blocking + TeamSelector.warnings(picked)
        let strength = picked.isEmpty ? 0 : picked.map { max($0.bat, $0.bowl) }.reduce(0, +) / picked.count
        TableScreen(title: "Pick XI") {
            SummaryLine(cells: [
                SummaryCell(value: "\(picked.count)/11", label: "picked", color: picked.count == 11 ? Palette.accent : .orange),
                SummaryCell(value: "\(picked.filter(\.overseas).count)/\(rules.maxOverseasXI)", label: "overseas"),
                SummaryCell(value: "\(picked.filter(\.isBowlingOption).count)", label: "bowlers",
                            color: picked.filter(\.isBowlingOption).count >= 5 ? .white : .orange),
                SummaryCell(value: "\(strength)", label: "strength", color: strengthColor(strength)),
            ])
            HStack(spacing: 6) {
                ForEach(0..<Self.roleLabels.count, id: \.self) { i in
                    FilterChip(title: Self.roleLabels[i], on: roleIndex == i) { roleIndex = i }
                }
                MenuChip(title: byRating ? "Sort: Rating" : "Sort: Type") {
                    Button("Type (openers first)") { byRating = false }
                    Button("Rating") { byRating = true }
                }
                Spacer(minLength: 4)
                ActionChip(icon: "sparkles", title: "Auto-pick") { autoPick() }
                ActionChip(icon: "xmark", title: "Clear", destructive: true) { selected = []; Haptics.tap() }
                ActionChip(icon: "checkmark", title: "Save", primary: true, disabled: !blocking.isEmpty) { save() }
            }
            TableNote(text: issues.isEmpty ? "Tap to pick or drop. New picks bat where they bat best; fine-tune in Batting order."
                                           : issues.joined(separator: " · "), warning: !issues.isEmpty)
            SquadTableHead(count: squad.count, check: true)
        } rows: {
            ForEach(Array(squad.enumerated()), id: \.element.id) { i, p in
                if !byRating, i == 0 || Self.typeName(squad[i - 1]) != Self.typeName(p) {
                    Text(Self.typeName(p).uppercased())
                        .font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 2)
                }
                Button { toggle(p.id) } label: {
                    SquadTableRow(player: p, year: year, check: selected.contains(p.id),
                                  pitchFit: c?.suitsUserPitch(p), selected: selected.contains(p.id))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            if !loaded {
                selected = Set(store.career?.userClub.xi ?? [])
                loaded = true
            }
        }
    }

    private func save() {
        store.careerPickXI(selected)
        Haptics.success()
        dismiss()
    }

    /// The assistant's XI for the next match's pitch (not saved until Save).
    private func autoPick() {
        guard var c = store.career else { return }
        c.autoPickXI(clubIndex: c.userClubIndex, pitch: c.nextUserFixture?.pitch)
        selected = Set(c.userClub.xi)
        Haptics.success()
    }

    private func toggle(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else if selected.count < 11 {
            selected.insert(id)
        } else {
            Haptics.warning()
            return
        }
        Haptics.tap()
    }
}

// MARK: - Player profile

struct CareerPlayerView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.verticalSizeClass) private var vSize
    let playerId: String
    @State private var showDeal = false
    @State private var dealMessage: String? = nil

    var body: some View {
        if vSize == .compact, let c = store.career, let p = c.players[playerId] {
            landscape(c, p)
        } else {
            portrait
        }
    }

    // MARK: Landscape: everything on one screen (device feedback)

    private func landscape(_ c: Career, _ p: CareerPlayer) -> some View {
        // Device feedback: three full-height boxes (Soccer Manager style): who he is, his form and
        // last five matches; his attributes; his numbers and contract.
        HStack(alignment: .top, spacing: DS.Space.sm) {
            PanelBox(padding: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        compactHeader(c, p)
                        Hairline()
                        compactForm(c, p)
                        lastFive(c, p)
                    }
                    .padding(12)
                }
            }
            PanelBox(padding: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        group("Batting · \(p.bat)") {
                            RatingBar(label: "TEC", value: p.attr.technique, color: Palette.four, compact: true)
                            RatingBar(label: "PWR", value: p.attr.power, color: Palette.four, compact: true)
                            RatingBar(label: "PACE", value: p.attr.vsPace, color: Palette.four, compact: true)
                            RatingBar(label: "SPIN", value: p.attr.vsSpin, color: Palette.four, compact: true)
                            RatingBar(label: "TEMP", value: p.attr.temperament, color: Palette.four, compact: true)
                        }
                        Hairline()
                        group("Bowling · \(p.bowl) \(p.bowlingStyle ?? (p.bowlType == .spin ? "spin" : "pace"))") {
                            RatingBar(label: "ACC", value: p.attr.accuracy, color: Palette.wicket, compact: true)
                            RatingBar(label: p.bowlType == .spin ? "TURN" : "PACE", value: p.attr.potency, color: Palette.wicket, compact: true)
                            RatingBar(label: "VAR", value: p.attr.variation, color: Palette.wicket, compact: true)
                            RatingBar(label: "DTH", value: p.attr.death, color: Palette.wicket, compact: true)
                            RatingBar(label: "NEW", value: p.attr.newBall, color: Palette.wicket, compact: true)
                        }
                        Hairline()
                        group("Fielding") {
                            RatingBar(label: "FLD", value: p.attr.fielding, color: Palette.six, compact: true)
                            if p.role == .WK { RatingBar(label: "KEEP", value: p.attr.keeping, color: Palette.six, compact: true) }
                        }
                    }
                    .padding(12)
                }
            }
            PanelBox(padding: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        compactStats(c, p)
                        Hairline()
                        compactDeal(c, p)
                    }
                    .padding(12)
                }
            }
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.sm)
        .background(AppBackground())
        .navigationTitle(p.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDeal) {
            NavigationStack {
                ScrollView { TransferActions(playerId: playerId).padding(DS.Space.lg) }
                    .background(AppBackground())
                    .navigationTitle("Negotiate")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { showDeal = false } } }
            }
            .environmentObject(store)
        }
    }

    /// Last five matches: when, who against, with the bat and the ball, the result and the rating.
    private func lastFive(_ c: Career, _ p: CareerPlayer) -> some View {
        let lines = c.recentMatches(p.id)
        return VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Last \(max(lines.count, 1)) matches")
            if lines.isEmpty {
                Text("No matches this season").font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted)
            } else {
                HStack(spacing: 6) {
                    Text("MATCH").frame(maxWidth: .infinity, alignment: .leading)
                    Text("BAT").frame(width: 56, alignment: .trailing)
                    Text("BOWL").frame(width: 40, alignment: .trailing)
                    Text("RTG").frame(width: 34, alignment: .trailing)
                }
                .font(.system(size: 9 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
                ForEach(lines, id: \.resultId) { m in
                    HStack(spacing: 6) {
                        Circle().fill(m.won ? Palette.accent : Palette.wicket).frame(width: 6, height: 6)
                        if let t = c.club(m.opponent) { TeamBadge(team: t, size: 18) }
                        Text(m.day.map { CareerCalendar.label($0) } ?? "")
                            .font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(m.runs.map { "\($0)\(m.notOut ? "*" : "") (\(m.balls))" } ?? "–")
                            .font(.score(12)).frame(width: 56, alignment: .trailing)
                        Text(m.wickets.map { "\($0)-\(m.conceded)" } ?? "–")
                            .font(.score(12)).foregroundStyle(m.wickets == nil ? Palette.muted : .white).frame(width: 40, alignment: .trailing)
                        Text(String(format: "%.1f", m.rating)).font(.score(12)).foregroundStyle(RatingStyle.color(m.rating))
                            .frame(width: 34, alignment: .trailing)
                    }
                    .padding(.vertical, 3)
                    .overlay(alignment: .bottom) { Hairline() }
                }
            }
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t.uppercased()).font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ rows: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased()).font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
            rows()
        }
    }

    private func compactHeader(_ c: Career, _ p: CareerPlayer) -> some View {
        let club = p.clubId.flatMap { c.club($0) }
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                RoleChip(role: p.role)
                Chip(text: p.country)
                if p.overseas { Chip(text: "Overseas") }
                if let club { TeamBadge(team: club, size: 18) }
            }
            Text(p.roleDescription).font(.system(size: 12 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.accent)
            if let fit = c.pitchFitLine(p) {
                Label(fit.text, systemImage: fit.good ? "house.fill" : "house")
                    .font(.system(size: 11 * TextScale.factor, weight: .semibold))
                    .foregroundStyle(fit.good ? Palette.accent : Color.orange).lineLimit(1).minimumScaleFactor(0.8)
            }
            Text("Age \(p.age(in: c.year)) · \(club?.name ?? "Free agent")").font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted)
                .lineLimit(1)
            HStack(spacing: 0) {
                number("\(p.rating)", "OVR", strengthColor(p.rating))
                number("\(p.bat)", "BAT", strengthColor(p.bat))
                number("\(p.bowl)", "BOWL", strengthColor(p.bowl))
                number(FormStyle.text(c.formScore(p.id)), "FORM", FormStyle.color(c.formScore(p.id)))
            }
            Text("Value \(Money.format(p.value(in: c.year))) · Potential \(c.potentialLabel(p))\(c.knowledge(of: p.id) < 100 ? " (\(c.knowledge(of: p.id))%)" : "")")
                .font(.system(size: 12 * TextScale.factor, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            if !p.traits.isEmpty { TraitChips(traits: p.traits, inline: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func number(_ v: String, _ l: String, _ color: Color) -> some View {
        VStack(spacing: 0) {
            Text(v).font(.display(20)).foregroundStyle(color)
            Text(l).font(.display(9, weight: .heavy)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func compactForm(_ c: Career, _ p: CareerPlayer) -> some View {
        let trend = c.formTrend(p.id)
        return HStack {
            sectionTitle("Form")
            Text("\(FormStyle.label(c.formScore(p.id)))\(trend > 0 ? " · rising" : (trend < 0 ? " · falling" : ""))")
                .font(.system(size: 12 * TextScale.factor, weight: .semibold)).foregroundStyle(FormStyle.color(c.formScore(p.id)))
            Spacer()
            if let avg = c.averageRating(p.id) {
                Text("avg rating \(String(format: "%.2f", avg))").font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted)
            }
        }
    }

    /// This season as a grid of numbers (batting, then bowling when he bowls), all-time in a line.
    private func compactStats(_ c: Career, _ p: CareerPlayer) -> some View {
        let s = c.statLine(p.id, scope: .season)
        let all = c.statLine(p.id, scope: .allTime)
        let bowls = p.bowl >= 40 || s.ballsBowled > 0
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
        return VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Season \(String(c.year)) · \(s.matches) matches")
            LazyVGrid(columns: cols, spacing: 6) {
                statTile("\(s.runs)", "Runs")
                statTile(s.balls > 0 ? String(format: "%.0f", s.strikeRate) : "–", "Strike rate")
                statTile(s.matches > 0 ? "\(s.highScore)" : "–", "Best")
                statTile("\(s.fours) · \(s.sixes)", "4s · 6s")
                statTile("\(s.fifties) · \(s.hundreds)", "50s · 100s")
                statTile("\(s.potm)", "Player of match")
                if bowls {
                    statTile("\(s.wickets)", "Wickets")
                    statTile(s.ballsBowled > 0 ? String(format: "%.2f", s.economy) : "–", "Economy")
                    statTile("\(s.ballsBowled / 6)", "Overs")
                }
            }
            HStack(spacing: 6) {
                sectionTitle("All-time · \(all.matches) m\(p.stats.titles > 0 ? " · \(p.stats.titles) titles" : "")")
                Spacer()
            }
            Text(StatText.line(all, role: p.role)).font(.system(size: 12 * TextScale.factor).monospacedDigit())
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.score(15)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(label.uppercased()).font(.system(size: 8 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.surfaceHi))
    }

    /// One line of the contract box: label left, value right.
    private func dealRow(_ label: String, _ value: String, _ color: Color = .white) -> some View {
        HStack {
            Text(label).font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted)
            Spacer()
            Text(value).font(.score(12)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder private func compactDeal(_ c: Career, _ p: CareerPlayer) -> some View {
        let mine = p.clubId == c.userClubId
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(p.clubId == nil ? "Free agent" : "Contract")
            if let k = p.contract {
                dealRow("Wage", "\(Money.format(k.wage)) a season")
                dealRow("Runs to", "\(String(k.until)) mega auction · \(max(0, k.until - c.year)) season\(k.until - c.year == 1 ? "" : "s") left")
            }
            dealRow("Market value", Money.format(p.value(in: c.year)))
            if mine {
                let inXI = c.userClub.xi.contains(p.id)
                if let listed = c.market.listed[p.id] {
                    dealRow("Status", "Listed at \(Money.format(listed))", .orange)
                } else {
                    dealRow("Status", inXI ? "In the XI" : "On the bench", inXI ? Palette.accent : .white)
                }
                ActionChip(icon: "arrow.left.arrow.right", title: "List or release…") { showDeal = true }
            } else if !p.retired {
                let fee = p.clubId == nil ? 0 : c.askingPrice(p)
                let wage = c.userWageDemand(p)
                if let club = p.clubId.flatMap({ c.club($0) }) { dealRow("Club", club.name) }
                if p.clubId != nil { dealRow("Asking fee", Money.format(fee), Palette.accent) }
                dealRow("Wants", "\(Money.format(wage)) a season", Palette.accent)
                let advice = c.scoutAdvice(p, fee: fee)
                Label(advice.text, systemImage: advice.good ? "checkmark.circle" : "info.circle")
                    .font(.system(size: 11 * TextScale.factor, weight: .semibold))
                    .foregroundStyle(advice.good ? Palette.accent : Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ActionChip(icon: "checkmark", title: "Pay asking", primary: true, disabled: !c.windowOpen) {
                        let outcome = store.careerMakeOffer(playerId: p.id, fee: fee, wage: wage)
                        dealMessage = outcome.message
                        if case .accepted = outcome { Haptics.success() } else { Haptics.warning() }
                    }
                    ActionChip(icon: "bubble.left.and.bubble.right", title: "Negotiate…") { showDeal = true }
                }
                if let dealMessage { Text(dealMessage).font(.system(size: 11 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.accent).lineLimit(3) }
                if !c.windowOpen { Text(c.windowLabel).font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted) }
            }
            GoldActions(playerId: p.id).font(.system(size: 12 * TextScale.factor, weight: .semibold))
        }
    }

    // MARK: Portrait

    private var portrait: some View {
        ScrollView {
            if let c = store.career, let p = c.players[playerId] {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    header(c, p)
                    FormCard(career: c, player: p)
                    if !p.traits.isEmpty {
                        SectionLabel(text: "Traits")
                        AppCard { TraitChips(traits: p.traits, showBlurb: true) }
                    }
                    SectionLabel(text: "Batting · \(p.bat)")
                    AppCard {
                        VStack(spacing: 8) {
                            RatingBar(label: "TEC", value: p.attr.technique, color: Palette.four)
                            RatingBar(label: "PWR", value: p.attr.power, color: Palette.four)
                            RatingBar(label: "PACE", value: p.attr.vsPace, color: Palette.four)
                            RatingBar(label: "SPIN", value: p.attr.vsSpin, color: Palette.four)
                            RatingBar(label: "TEMP", value: p.attr.temperament, color: Palette.four)
                        }
                    }
                    SectionLabel(text: "Bowling · \(p.bowl) \(p.bowlType == .spin ? "spin" : "pace")")
                    AppCard {
                        VStack(spacing: 8) {
                            RatingBar(label: "ACC", value: p.attr.accuracy, color: Palette.wicket)
                            RatingBar(label: p.bowlType == .spin ? "TURN" : "PACE", value: p.attr.potency, color: Palette.wicket)
                            RatingBar(label: "VAR", value: p.attr.variation, color: Palette.wicket)
                            RatingBar(label: "DTH", value: p.attr.death, color: Palette.wicket)
                            RatingBar(label: "NEW", value: p.attr.newBall, color: Palette.wicket)
                        }
                    }
                    SectionLabel(text: "Fielding")
                    AppCard {
                        VStack(spacing: 8) {
                            RatingBar(label: "FLD", value: p.attr.fielding, color: Palette.six)
                            if p.role == .WK {
                                RatingBar(label: "KEEP", value: p.attr.keeping, color: Palette.six)
                            }
                        }
                    }
                    PlayerStatsSection(career: c, player: p)
                    SectionLabel(text: "Transfer")
                    TransferActions(playerId: playerId)
                    GoldActions(playerId: playerId)
                }
                .padding(DS.Space.lg)
            }
        }
        .background(AppBackground())
        .navigationTitle(store.career?.players[playerId]?.name ?? "Player")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ c: Career, _ p: CareerPlayer) -> some View {
        let club = p.clubId.flatMap { c.club($0) }
        return AppCard(tint: club.map { Color(hex: $0.colorHex) }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    RoleChip(role: p.role)
                    Chip(text: p.country)
                    if p.overseas { Chip(text: "Overseas") }
                    if p.legend { Chip(text: "★ Legend", color: Palette.accent.opacity(0.2), textColor: Palette.accent) }
                }
                Text(p.name.uppercased()).font(.display(30)).lineLimit(1).minimumScaleFactor(0.6)
                Text("Age \(p.age(in: c.year)) · bats \(p.slot.label.lowercased()) · \(club?.name ?? "Free agent")")
                    .font(.subheadline).foregroundStyle(Palette.muted)
                if let fit = c.pitchFitLine(p) {
                    Label(fit.text, systemImage: fit.good ? "house.fill" : "house")
                        .font(.caption.weight(.semibold)).foregroundStyle(fit.good ? Palette.accent : Color.orange)
                }
                HStack(spacing: 0) {
                    big("\(p.rating)", "OVR", strengthColor(p.rating))
                    big("\(p.bat)", "BAT", strengthColor(p.bat))
                    big("\(p.bowl)", "BOWL", strengthColor(p.bowl))
                    big(FormStyle.text(c.formScore(p.id)), "FORM", FormStyle.color(c.formScore(p.id)))
                }
                Text("Value \(Money.format(p.value(in: c.year))) · Potential \(c.potentialLabel(p))\(c.knowledge(of: p.id) < 100 ? " (scouted \(c.knowledge(of: p.id))%)" : "")")
                    .font(.subheadline.weight(.semibold))
                if !p.line.isEmpty {
                    Text(p.line).font(.caption).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private func big(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.display(30)).foregroundStyle(color)
            Text(label).font(.display(10, weight: .heavy)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Any club's squad

struct CareerClubView: View {
    @EnvironmentObject var store: GameStore
    let clubId: Int

    var body: some View {
        let c = store.career
        let squad = c.map { $0.squad(clubId).sorted { $0.rating != $1.rating ? $0.rating > $1.rating : $0.id < $1.id } } ?? []
        let xi = Set(c?.club(clubId)?.xi ?? [])
        TableScreen(title: c?.club(clubId)?.name ?? "") {
            if let c, let club = c.club(clubId) {
                HStack(spacing: 10) {
                    TeamBadge(team: club, size: 34)
                    SummaryLine(cells: [
                        SummaryCell(value: Career.ordinal(c.position(of: clubId)), label: "in the league"),
                        SummaryCell(value: "\(c.strength(clubId))", label: "XI strength", color: strengthColor(c.strength(clubId))),
                        SummaryCell(value: c.homePitch(clubId).label, label: "home"),
                        SummaryCell(value: "\(c.info(clubId)?.titles ?? 0)", label: "titles"),
                    ])
                }
                TableNote(text: "Highlighted: their current XI. Tap a player for his page.")
                SquadTableHead(count: squad.count, trailing: "WAGE")
            }
        } rows: {
            ForEach(squad) { p in
                NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                    SquadTableRow(player: p, year: c?.year ?? 0, trailing: p.contract.map { Money.format($0.wage) } ?? "–",
                                  trailingColor: Palette.muted, selected: xi.contains(p.id))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Career › Squad › Form: the player's form, its trend and his recent match ratings.
struct FormCard: View {
    let career: Career
    let player: CareerPlayer

    var body: some View {
        let c = career, p = player
        let trend = c.formTrend(p.id)
        let recent = c.recentRatings(p.id)
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Form")
            VStack(spacing: 0) {
                InfoRow(label: "Form", value: "\(FormStyle.label(c.formScore(p.id))) · \(FormStyle.text(c.formScore(p.id)))",
                        color: FormStyle.color(c.formScore(p.id)), chevron: false)
                Hairline(inset: 16)
                InfoRow(label: "Trend", value: trend > 0 ? "Rising" : (trend < 0 ? "Falling" : "Level"),
                        color: trend > 0 ? Palette.accent : (trend < 0 ? Palette.wicket : .white), chevron: false)
                Hairline(inset: 16)
                InfoRow(label: "Match rating", value: c.averageRating(p.id).map { "\(String(format: "%.2f", $0)) over \(c.matchRatings(p.id).count) matches" } ?? "No matches this season",
                        chevron: false)
                if !recent.isEmpty {
                    Hairline(inset: 16)
                    HStack {
                        Text("Last \(recent.count)").font(.display(16, weight: .regular))
                        Spacer()
                        ForEach(Array(recent.enumerated()), id: \.offset) { _, x in
                            Text(String(format: "%.1f", x)).font(.score(16)).foregroundStyle(RatingStyle.color(x))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
            .gameFrame()
            Text("Form comes from recent performances and moves his batting and bowling by up to 3 in matches. It drifts back towards steady between games.")
                .font(.display(12, weight: .regular)).foregroundStyle(Palette.muted)
        }
    }
}

/// Career › Squad › Squad report: averages, the three best players, strengths and weak spots.
struct SquadReportView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        let c = store.career
        let r = c?.squadReport() ?? SquadReport()
        PaneScreen(title: "Squad report") {
            SummaryLine(cells: [
                SummaryCell(value: "\(r.averageRating)", label: "avg rating", color: strengthColor(r.averageRating)),
                SummaryCell(value: "\(c.map { $0.squad($0.userClubId).count } ?? 0)", label: "squad"),
                SummaryCell(value: String(format: "%.1f", r.averageAge), label: "avg age"),
                SummaryCell(value: Money.format(r.totalValue), label: "value"),
            ])
            Text("BEST PLAYERS").font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
            SquadTableHead(count: r.stars.count, form: true, compact: true)
            ForEach(r.stars) { p in
                NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                    SquadTableRow(player: p, year: c?.year ?? 0, pitchFit: c?.suitsUserPitch(p), compact: true)
                }
                .buttonStyle(.plain)
            }
        } right: {
            lines("Strengths", r.strengths, icon: "checkmark", color: Palette.accent)
            lines("Weak spots", r.weaknesses.isEmpty ? ["Nothing stands out."] : r.weaknesses, icon: "xmark", color: Palette.wicket)
        }
    }

    private func lines(_ title: String, _ items: [String], icon: String, color: Color) -> some View {
        PaneBox(title: title) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, line in
                if i > 0 { Hairline() }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon).font(.system(size: 12 * TextScale.factor, weight: .bold)).foregroundStyle(color)
                        .frame(width: 14)
                    Text(line).font(.system(size: 13 * TextScale.factor)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

enum RatingStyle {
    /// Match ratings: 8+ excellent, 7+ good, 6+ fair, below that poor.
    static func color(_ x: Double) -> Color { x >= 8 ? Palette.accent : (x >= 7 ? Palette.four : (x >= 6 ? .white : .orange)) }
}

/// Career › Squad › Club stats: the user's players ranked by one category.
struct ClubStatsView: View {
    @EnvironmentObject var store: GameStore
    @State private var category = Category.runs

    enum Category: String, CaseIterable, Identifiable {
        case runs = "Runs", wickets = "Wickets", rating = "Match rating", sixes = "Sixes"
        case strikeRate = "Strike rate", economy = "Economy", potm = "Player of the match"
        var id: String { rawValue }
        /// Header of the middle column (a rate that puts the total in context).
        var rateLabel: String {
            switch self {
            case .runs: return "SR"
            case .wickets: return "Econ"
            case .sixes: return "Balls/6"
            case .strikeRate: return "Runs"
            case .economy: return "Wkts"
            case .rating, .potm: return ""
            }
        }
    }

    var body: some View {
        let c = store.career
        let rows = c.map { ranked($0, $0.seasonStatLines) } ?? []
        TableScreen(title: "Club stats") {
            HStack(spacing: 6) {
                ForEach([Category.runs, .wickets, .rating], id: \.self) { cat in
                    FilterChip(title: cat.rawValue, on: category == cat) { category = cat }
                }
                MenuChip(title: [Category.runs, .wickets, .rating].contains(category) ? "More" : category.rawValue) {
                    ForEach(Category.allCases) { cat in Button(cat.rawValue) { category = cat } }
                }
                Spacer(minLength: 4)
                Text("Season \(String(c?.year ?? 0))").font(.system(size: 12 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted)
            }
            TableNote(text: "Match ratings run 3 to 10. Strike rate needs 30 balls faced, economy 24 bowled.")
            TableHead {
                Text("#").frame(width: TCol.num, alignment: .center)
                Text("PLAYER · \(rows.count)").frame(maxWidth: .infinity, alignment: .leading)
                Text("APPS").frame(width: TCol.stat + 6, alignment: .trailing)
                Text(category.rateLabel.uppercased()).frame(width: TCol.wide, alignment: .trailing)
                Text(category == .rating ? "AVG" : "TOTAL").frame(width: TCol.wide, alignment: .trailing)
            }
        } rows: {
            if rows.isEmpty {
                Text("No matches played this season yet.").font(.system(size: 13 * TextScale.factor)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).tableRow()
            }
            ForEach(Array(rows.enumerated()), id: \.element.0.id) { i, row in
                NavigationLink { CareerPlayerView(playerId: row.0.id) } label: {
                    HStack(spacing: 8) {
                        TNum(text: "\(i + 1)", width: TCol.num, color: Palette.muted, align: .center)
                        TName(text: row.0.name, overseas: row.0.overseas, bold: i < 3)
                        TNum(text: "\(row.1)", width: TCol.stat + 6, color: Palette.muted)
                        TNum(text: row.2, width: TCol.wide, color: Palette.muted)
                        TNum(text: row.3, width: TCol.wide, color: Palette.accent)
                    }
                    .tableRow()
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// (player, apps, rate, total) for the chosen category, best first.
    private func ranked(_ c: Career, _ season: [String: StatLine]) -> [(CareerPlayer, Int, String, String)] {
        let squad = c.squad(c.userClubId)
        let f1 = { (x: Double) in String(format: "%.1f", x) }
        var rows: [(CareerPlayer, Int, String, String, Double)] = []
        for p in squad {
            let s = season[p.id] ?? StatLine()
            guard s.matches > 0 else { continue }
            switch category {
            case .runs:
                rows.append((p, s.matches, s.balls > 0 ? f1(s.strikeRate) : "–", "\(s.runs)", Double(s.runs)))
            case .wickets:
                guard s.ballsBowled > 0 else { continue }
                rows.append((p, s.matches, f1(s.economy), "\(s.wickets)", Double(s.wickets) - s.economy / 100))
            case .rating:
                guard let avg = c.averageRating(p.id) else { continue }
                rows.append((p, s.matches, "", String(format: "%.2f", avg), avg))
            case .sixes:
                guard s.sixes > 0 else { continue }
                rows.append((p, s.matches, "\(s.balls / max(1, s.sixes))", "\(s.sixes)", Double(s.sixes)))
            case .strikeRate:
                guard s.balls >= 30 else { continue }
                rows.append((p, s.matches, "\(s.runs)", f1(s.strikeRate), s.strikeRate))
            case .economy:
                guard s.ballsBowled >= 24 else { continue }
                rows.append((p, s.matches, "\(s.wickets)", String(format: "%.2f", s.economy), -s.economy))
            case .potm:
                guard s.potm > 0 else { continue }
                rows.append((p, s.matches, "", "\(s.potm)", Double(s.potm)))
            }
        }
        return rows.sorted { $0.4 != $1.4 ? $0.4 > $1.4 : $0.0.id < $1.0.id }.map { ($0.0, $0.1, $0.2, $0.3) }
    }
}

/// Career › Squad › Development: young players and academy prospects, rating at the season start,
/// now, the trend and the potential range.
struct DevelopmentReportView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.verticalSizeClass) private var vSize

    var body: some View {
        let c = store.career
        let list = c?.developmentWatch ?? []
        let rising = list.filter { (c?.seasonProgress($0) ?? 0) > 0 }.count
        TableScreen(title: "Development") {
            SummaryLine(cells: [
                SummaryCell(value: "\(list.count)", label: "aged 23 or under"),
                SummaryCell(value: "\(rising)", label: "improved this season", color: Palette.accent),
                SummaryCell(value: "\(list.filter { $0.academyOf != nil }.count)", label: "in the academy"),
            ])
            TableNote(text: "Young players grow most with training focus and match time. Scouting narrows the potential range.")
            TableHead {
                Text("PLAYER · \(list.count)").frame(maxWidth: .infinity, alignment: .leading)
                if vSize == .compact { Text("ROLE").frame(width: TCol.role, alignment: .leading) }
                Text("AGE").frame(width: TCol.age, alignment: .trailing)
                Text("START").frame(width: TCol.wide - 10, alignment: .trailing)
                Text("NOW").frame(width: TCol.stat, alignment: .trailing)
                Text("").frame(width: 18)
                Text("POTENTIAL").frame(width: 76, alignment: .trailing)
            }
        } rows: {
            if list.isEmpty {
                Text("No players aged 23 or under. Sign some, or promote from the academy.")
                    .font(.system(size: 13 * TextScale.factor)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).tableRow()
            }
            if let c {
                ForEach(list) { p in
                    let delta = c.seasonProgress(p) ?? 0
                    NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                TName(text: p.name, overseas: p.overseas)
                                if p.academyOf != nil {
                                    Text("ACADEMY").font(.system(size: 9 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.four)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if vSize == .compact { TRole(role: p.role) }
                            TNum(text: "\(p.age(in: c.year))", width: TCol.age, color: Palette.muted)
                            TNum(text: p.seasonStartRating.map { "\($0)" } ?? "–", width: TCol.wide - 10, color: Palette.muted)
                            TNum(text: "\(p.rating)", width: TCol.stat, color: strengthColor(p.rating))
                            Image(systemName: delta > 0 ? "arrow.up" : (delta < 0 ? "arrow.down" : "minus"))
                                .font(.system(size: 11 * TextScale.factor, weight: .bold))
                                .foregroundStyle(delta > 0 ? Palette.accent : (delta < 0 ? Palette.wicket : Palette.muted))
                                .frame(width: 18)
                            TNum(text: c.potentialLabel(p), width: 76, color: Palette.four)
                        }
                        .tableRow()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
