import SwiftUI

/// Owner's request: after each innings the match stops on its scorecard, in the full scorecard's
/// format. Landscape: the batting card fills the left side; on the right, the innings line and the
/// bowling card on top and (at the innings break, in your own match) the assistant manager below,
/// with Tactics in the box's corner. Next, at the top of the screen, carries on.
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
        if vSize == .compact {
            GeometryReader { geo in
                let gap = DS.Space.md
                let left = (geo.size.width - gap) * 0.54
                HStack(alignment: .top, spacing: gap) {
                    ScrollView(showsIndicators: false) {
                        BattingTable(innings: inn)
                    }
                    .frame(width: left)
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        banner
                        // Five to seven bowlers: their own height; the assistant takes the rest.
                        bowling(inn)
                        if showsAssistant {
                            assistant.frame(maxHeight: .infinity, alignment: .top)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.md) {
                    banner
                    BattingTable(innings: inn)
                    bowling(inn)
                    if showsAssistant { assistant }
                }
                .padding(DS.Space.md)
            }
        }
    }

    private var showsAssistant: Bool { !advice.isEmpty || onTactics != nil }

    /// "INNINGS BREAK" and the chase (or the result), one line each.
    private var banner: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 12 * TextScale.factor, weight: .heavy)).tracking(1.5).foregroundStyle(Palette.accent)
            Text(subtitle).font(.system(size: 14 * TextScale.factor, weight: .bold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The fielding side's name over the full scorecard's bowling table.
    private func bowling(_ inn: InningsCard) -> some View {
        let fielding = result.innings.prefix(2).first { $0.teamId != inn.teamId }.flatMap { store.team($0.teamId) }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let fielding { TeamBadge(team: fielding, size: 18) }
                Text("\(fielding?.name ?? "") bowling").font(.system(size: 12 * TextScale.factor, weight: .bold))
                    .foregroundStyle(Palette.muted).lineLimit(1)
            }
            BowlingTable(innings: inn)
        }
    }

    private var assistant: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "person.wave.2.fill").font(.system(size: 13 * TextScale.factor)).foregroundStyle(Palette.accent)
                Text("ASSISTANT MANAGER").font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
                Spacer(minLength: 4)
                if let onTactics {
                    ActionChip(icon: "slider.horizontal.3", title: "Tactics", primary: true, action: onTactics)
                        .accessibilityIdentifier("break.tactics")
                }
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(advice, id: \.self) { line in
                        Text(line).font(.system(size: 13 * TextScale.factor, weight: .semibold)).foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surface))
    }
}
