import SwiftUI

/// Broadcast-style lineup row (like a TV "Teams" graphic): batting number, NAME, (wk), C, overseas,
/// a short role tag and the rating.
struct LineupRow: View {
    let number: Int?
    let name: String
    var keeper = false
    var captain = false
    var overseas = false
    /// Home-pitch fit (career): true suits, false struggles, nil neither.
    var pitchFit: Bool? = nil
    var tag = ""
    /// Career: the form score column before the rating (a dash before his first match).
    var showsForm = false
    var formScore: Double? = nil
    var rating: Int? = nil
    var selected = false
    /// Stretch to share the available height (the Squad tab's XI fills the left column).
    var fill = false

    var body: some View {
        HStack(spacing: 6) {
            if let number {
                Text("\(number)").font(.score(11)).foregroundStyle(Palette.muted).frame(width: 16, alignment: .trailing)
            }
            Text(name.uppercased()).font(.system(size: 13 * TextScale.factor, weight: .bold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
            if keeper {
                Text("(wk)").font(.system(size: 11 * TextScale.factor, weight: .medium)).foregroundStyle(Palette.muted)
            }
            if captain {
                Text("C").font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Palette.accent))
            }
            if overseas {
                Image(systemName: "airplane").font(.system(size: 9 * TextScale.factor)).foregroundStyle(Palette.muted)
            }
            PitchFitMark(fit: pitchFit)
            Spacer(minLength: 4)
            if !tag.isEmpty {
                Text(tag).font(.system(size: 11 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted).lineLimit(1)
            }
            if showsForm {
                Text(FormStyle.text(formScore)).font(.score(13)).foregroundStyle(FormStyle.color(formScore))
                    .frame(width: 30, alignment: .trailing)
            }
            if let rating {
                Text("\(rating)").font(.score(13)).foregroundStyle(strengthColor(rating)).frame(width: 24, alignment: .trailing)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: fill ? 20 : 24 * min(1.25, TextScale.factor), maxHeight: fill ? .infinity : 24 * min(1.25, TextScale.factor))
        .background(selected ? Palette.accent.opacity(0.22) : Color.clear)
        .contentShape(Rectangle())
    }
}

/// A titled list of lineup rows with hairlines, the band in the team colour.
struct LineupPanel<Rows: View>: View {
    let title: String
    var color: Color = Palette.surfaceHi
    var darkText = false
    /// Column titles at the right of the header, lined up with the rows' trailing columns.
    var columns: [(title: String, width: CGFloat)] = []
    @ViewBuilder var rows: Rows

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 13 * TextScale.factor, weight: .heavy))
                    .foregroundStyle(darkText ? Palette.ink : .white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                    Text(col.title).font(.system(size: 10 * TextScale.factor, weight: .heavy))
                        .foregroundStyle(darkText ? Palette.ink : Palette.muted)
                        .frame(width: col.width, alignment: .trailing)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color)
            VStack(spacing: 0) { rows }
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Before a match: both XIs side by side (home left, away right), the occasion on top and the
/// toss at the foot, then Start.
struct TeamsBoard: View {
    @EnvironmentObject var store: GameStore
    let result: MatchResult
    var occasion = ""
    /// Landscape: the panels stretch so the rows fill the screen height.
    var fill = false
    let onStart: () -> Void
    let onSkip: () -> Void
    /// Your own career match: opens the tactics (they apply from the first ball).
    var onTactics: (() -> Void)? = nil
    private let barHeight: CGFloat = 36

    var body: some View {
        let home = result.teamA, away = result.teamB
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("TEAMS").font(.system(size: 20 * TextScale.factor, weight: .black))
                Text([occasion, "\(result.pitch.icon) \(result.pitch.label)"].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted).lineLimit(1)
                Spacer(minLength: 0)
            }
            HStack(alignment: .top, spacing: 10) {
                side(home)
                side(away)
            }
            .frame(maxHeight: fill ? .infinity : nil)
            // One height for the toss band and both buttons (device feedback: they didn't line up).
            HStack(spacing: 10) {
                Text(tossLine.uppercased()).font(.system(size: 12 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: barHeight, maxHeight: barHeight, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.accent))
                if let onTactics {
                    Button(action: onTactics) {
                        Label("Tactics", systemImage: "slider.horizontal.3").font(.system(size: 13 * TextScale.factor, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 14)
                            .frame(minHeight: barHeight, maxHeight: barHeight)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surfaceHi))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("teams.tactics")
                }
                Button(action: onSkip) {
                    Text("Skip to result").font(.system(size: 13 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.accent)
                        .padding(.horizontal, 14)
                        .frame(minHeight: barHeight, maxHeight: barHeight)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surfaceHi))
                }
                .buttonStyle(.plain)
                Button(action: onStart) {
                    Label("Start match", systemImage: "play.fill").font(.system(size: 14 * TextScale.factor, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 16)
                        .frame(minHeight: barHeight, maxHeight: barHeight)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tossLine: String {
        let winner = store.team(result.tossWinner)?.name ?? ""
        let batted = result.innings.first?.teamId == result.tossWinner
        return "\(winner) won the toss & chose to \(batted ? "bat" : "bowl")"
    }

    /// One side's XI in batting order, from the scorecard (the XI that actually played).
    private func side(_ teamId: Int) -> some View {
        let team = store.team(teamId)
        let ids = result.innings.prefix(2).first { $0.teamId == teamId }?.batters.map(\.id) ?? []
        let captain = store.inCareer && teamId == store.career?.userClubId ? store.career?.tactics.captain : nil
        return LineupPanel(title: team?.name ?? "", color: team.map { Color(hex: $0.colorHex) } ?? Palette.surfaceHi,
                           darkText: team.map { MatchSummaryBoard.isLight($0.colorHex) } ?? false) {
            ForEach(Array(ids.enumerated()), id: \.element) { i, id in
                if i > 0 { Hairline(inset: 10) }
                let p = store.player(id)
                LineupRow(number: i + 1, name: p?.name ?? id, keeper: p?.role == .WK, captain: id == captain,
                          overseas: p?.overseas ?? false, tag: p?.role.short ?? "", rating: p?.rating, fill: fill)
            }
        }
    }
}

/// The user's lineup as an editable list: drag a player onto another to swap them (bench onto XI
/// brings him in at that place; XI onto XI swaps batting places), or tap one then the other.
struct EditableLineup: View {
    @EnvironmentObject var store: GameStore
    let title: String
    let ids: [String]
    var numbered = true
    var fill = false
    @Binding var selected: String?
    @Binding var message: String?

    var body: some View {
        if let c = store.career {
            LineupPanel(title: title, columns: [("FORM", 30), ("OVR", 24)]) {
                if ids.isEmpty {
                    Text("Nobody here.").font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted).padding(10)
                }
                ForEach(Array(ids.enumerated()), id: \.element) { i, id in
                    if i > 0 { Hairline(inset: 10) }
                    if let p = c.players[id] {
                        LineupRow(number: numbered ? i + 1 : nil, name: p.name, keeper: p.role == .WK,
                                  captain: c.tactics.captain == id, overseas: p.overseas, pitchFit: c.suitsUserPitch(p),
                                  tag: p.role.short, showsForm: true, formScore: c.formScore(id), rating: p.rating,
                                  selected: selected == id, fill: fill)
                            .onTapGesture { tap(id) }
                            .draggable(id)
                            .dropDestination(for: String.self) { items, _ in
                                guard let from = items.first else { return false }
                                return swap(from, id)
                            }
                    }
                }
            }
        }
    }

    private func tap(_ id: String) {
        guard let first = selected else { selected = id; Haptics.tap(); return }
        selected = nil
        if first != id { _ = swap(first, id) }
    }

    private func swap(_ a: String, _ b: String) -> Bool {
        if let why = store.careerSwapLineup(a, b) {
            message = why
            Haptics.warning()
            return false
        }
        message = nil
        Haptics.success()
        return true
    }
}
