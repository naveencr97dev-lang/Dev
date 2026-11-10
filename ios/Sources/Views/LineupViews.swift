import SwiftUI

/// Broadcast-style lineup row (like a TV "Teams" graphic): batting number, NAME, (wk), C, overseas,
/// a short role tag and the rating.
struct LineupRow: View {
    let number: Int?
    let name: String
    var keeper = false
    var captain = false
    var overseas = false
    var tag = ""
    var rating: Int? = nil
    var selected = false

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
            Spacer(minLength: 4)
            if !tag.isEmpty {
                Text(tag).font(.system(size: 11 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted).lineLimit(1)
            }
            if let rating {
                Text("\(rating)").font(.score(13)).foregroundStyle(strengthColor(rating)).frame(width: 24, alignment: .trailing)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 24 * min(1.25, TextScale.factor))
        .background(selected ? Palette.accent.opacity(0.22) : Color.clear)
        .contentShape(Rectangle())
    }
}

/// A titled list of lineup rows with hairlines, the band in the team colour.
struct LineupPanel<Rows: View>: View {
    let title: String
    var color: Color = Palette.surfaceHi
    var darkText = false
    @ViewBuilder var rows: Rows

    var body: some View {
        VStack(spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 13 * TextScale.factor, weight: .heavy))
                .foregroundStyle(darkText ? Palette.ink : .white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(color)
            VStack(spacing: 0) { rows }
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
    let onStart: () -> Void
    let onSkip: () -> Void

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
            HStack(spacing: 10) {
                Text(tossLine.uppercased()).font(.system(size: 12 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.accent))
                Button("Skip to result", action: onSkip)
                    .font(.system(size: 13 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.muted)
                Button(action: onStart) {
                    Label("Start match", systemImage: "play.fill").font(.system(size: 14 * TextScale.factor, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
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
                          overseas: p?.overseas ?? false, tag: p?.role.short ?? "", rating: p?.rating)
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
    @Binding var selected: String?
    @Binding var message: String?

    var body: some View {
        if let c = store.career {
            LineupPanel(title: title) {
                if ids.isEmpty {
                    Text("Nobody here.").font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted).padding(10)
                }
                ForEach(Array(ids.enumerated()), id: \.element) { i, id in
                    if i > 0 { Hairline(inset: 10) }
                    if let p = c.players[id] {
                        LineupRow(number: numbered ? i + 1 : nil, name: p.name, keeper: p.role == .WK,
                                  captain: c.tactics.captain == id, overseas: p.overseas,
                                  tag: "\(p.role.short) · \(CareerText.form(p.form))", rating: p.rating,
                                  selected: selected == id)
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
