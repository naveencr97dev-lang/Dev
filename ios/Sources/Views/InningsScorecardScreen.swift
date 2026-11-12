import SwiftUI

/// Owner's request: after each innings the match stops on its scorecard. Batting on the left,
/// bowling on the right, and (at the innings break, in your own match) the assistant's advice for
/// the next innings with a Tactics button. Next, at the top, carries on.
struct InningsScorecardScreen: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.verticalSizeClass) private var vSize
    let result: MatchResult
    /// 0 = first innings (the break), 1 = second innings (after the match).
    let index: Int
    let title: String
    let subtitle: String
    var advice: [String] = []
    var onTactics: (() -> Void)? = nil

    var body: some View {
        let inn = result.card(index)
        let team = store.team(inn.teamId)
        let content = VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let team { TeamBadge(team: team, size: 26) }
                Text(title).font(.system(size: 13 * TextScale.factor, weight: .heavy)).tracking(1.5)
                    .foregroundStyle(Palette.accent).lineLimit(1)
                Text(team?.name.uppercased() ?? "").font(.system(size: 15 * TextScale.factor, weight: .heavy)).lineLimit(1)
                Spacer(minLength: 6)
                Text(inn.score).font(.score(24))
                Text("(\(inn.overs) ov)").font(.score(13, weight: .regular)).foregroundStyle(Palette.muted)
            }
            Text(subtitle).font(.system(size: 13 * TextScale.factor, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                .minimumScaleFactor(0.8)
            let layout = vSize == .compact ? AnyLayout(HStackLayout(alignment: .top, spacing: 10))
                                           : AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            layout {
                batting(inn)
                bowling(inn)
            }
            .frame(maxHeight: vSize == .compact ? .infinity : nil)
            if !advice.isEmpty || onTactics != nil { assistant }
        }
        if vSize == .compact {
            content.padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.sm)
                .frame(maxWidth: 960, maxHeight: .infinity, alignment: .top).frame(maxWidth: .infinity)
        } else {
            ScrollView { content.padding(DS.Space.md) }
        }
    }

    // MARK: Batting

    private func batting(_ inn: InningsCard) -> some View {
        let batted = inn.batters.filter(\.batted)
        let dnb = inn.batters.filter { !$0.batted }.map(\.name)
        return PanelBox {
            TableHead {
                Text("BATTER").frame(maxWidth: .infinity, alignment: .leading)
                Text("R").frame(width: TCol.stat, alignment: .trailing)
                Text("B").frame(width: TCol.stat, alignment: .trailing)
                Text("4s").frame(width: 26, alignment: .trailing)
                Text("6s").frame(width: 26, alignment: .trailing)
                Text("SR").frame(width: 46, alignment: .trailing)
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(batted) { b in
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Text(b.name).font(.system(size: 13 * TextScale.factor, weight: .semibold)).lineLimit(1)
                                Text(b.dismissal ?? "not out").font(.system(size: 11 * TextScale.factor))
                                    .foregroundStyle(b.dismissal == nil ? Palette.accent : Palette.muted).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            TNum(text: "\(b.runs)\(b.dismissal == nil ? "*" : "")", width: TCol.stat,
                                 color: b.runs >= 50 ? Palette.accent : .white)
                            TNum(text: "\(b.balls)", width: TCol.stat, color: Palette.muted)
                            TNum(text: "\(b.fours)", width: 26, color: Palette.muted)
                            TNum(text: "\(b.sixes)", width: 26, color: Palette.muted)
                            TNum(text: b.balls > 0 ? String(format: "%.0f", b.strikeRate) : "–", width: 46, color: Palette.muted)
                        }
                        .tableRow()
                    }
                    Text((dnb.isEmpty ? "" : "Did not bat: \(dnb.joined(separator: ", ")) · ") + "Extras \(inn.extras)")
                        .font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 5)
                }
            }
        }
    }

    // MARK: Bowling

    private func bowling(_ inn: InningsCard) -> some View {
        let bowlers = inn.bowlers.filter { $0.balls > 0 }
        return PanelBox {
            TableHead {
                Text("BOWLER").frame(maxWidth: .infinity, alignment: .leading)
                Text("O").frame(width: TCol.stat, alignment: .trailing)
                Text("R").frame(width: TCol.stat, alignment: .trailing)
                Text("W").frame(width: TCol.stat, alignment: .trailing)
                Text("ECON").frame(width: 46, alignment: .trailing)
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(bowlers) { b in
                        HStack(spacing: 8) {
                            Text(b.name).font(.system(size: 13 * TextScale.factor, weight: .semibold)).lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            TNum(text: b.overs, width: TCol.stat, color: Palette.muted)
                            TNum(text: "\(b.runs)", width: TCol.stat)
                            TNum(text: "\(b.wickets)", width: TCol.stat, color: b.wickets >= 3 ? Palette.accent : .white)
                            TNum(text: String(format: "%.2f", b.economy), width: 46,
                                 color: b.economy >= 10 ? Palette.wicket : (b.economy <= 7 ? Palette.accent : Palette.muted))
                        }
                        .tableRow()
                    }
                }
            }
        }
    }

    // MARK: Assistant

    private var assistant: some View {
        PanelBox {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "person.wave.2.fill").font(.system(size: 15 * TextScale.factor)).foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("ASSISTANT MANAGER").font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
                    ForEach(advice, id: \.self) { line in
                        Text(line).font(.system(size: 12 * TextScale.factor, weight: .semibold)).foregroundStyle(.white)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let onTactics {
                    ActionChip(icon: "slider.horizontal.3", title: "Tactics", primary: true, action: onTactics)
                        .accessibilityIdentifier("break.tactics")
                }
            }
        }
    }
}
