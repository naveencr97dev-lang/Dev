import SwiftUI

/// Compact one-line numbers for lists: batting and/or bowling depending on the role.
enum StatText {
    static func line(_ s: StatLine, role: Role) -> String {
        if s.isEmpty { return "No matches yet" }
        let bat = "\(s.runs) runs · SR \(Int(s.strikeRate.rounded())) · HS \(s.highScore)"
        let bowl = s.ballsBowled > 0 ? "\(s.wickets) wkts · econ \(String(format: "%.1f", s.economy))" : ""
        switch role {
        case .BOWL: return bowl.isEmpty ? "\(s.matches) m · " + bat : "\(s.matches) m · " + bowl + " · \(s.runs) runs"
        case .AR: return "\(s.matches) m · " + bat + (bowl.isEmpty ? "" : " · " + bowl)
        default: return "\(s.matches) m · " + bat + (s.sixes > 0 ? " · \(s.sixes) 6s" : "")
        }
    }
}

/// Profile stats: this season, season by season, and all-time since the career began.
struct PlayerStatsSection: View {
    let career: Career
    let player: CareerPlayer

    var body: some View {
        let c = career
        let season = c.statLine(player.id, scope: .season)
        let allTime = c.statLine(player.id, scope: .allTime)
        VStack(alignment: .leading, spacing: DS.Space.md) {
            SectionLabel(text: "This season · \(String(c.year))")
            if season.isEmpty {
                Text("Hasn't played this season yet.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                StatGrid(line: season)
            }
            SectionLabel(text: "All-time · since \(String(c.startYear))")
            if allTime.isEmpty {
                Text("No matches yet.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                StatGrid(line: allTime, titles: player.stats.titles)
            }
            if let log = player.seasonLog, !log.isEmpty {
                SectionLabel(text: "Season by season")
                AppCard(padding: DS.Space.md) {
                    VStack(spacing: 6) {
                        HStack {
                            Text("YEAR").frame(width: 44, alignment: .leading)
                            Text("CLUB").frame(width: 40, alignment: .leading)
                            Text("M").frame(width: 24)
                            Text("RUNS").frame(maxWidth: .infinity)
                            Text("SR").frame(width: 34)
                            Text("WKTS").frame(width: 36)
                            Text("ECON").frame(width: 36)
                        }
                        .font(.display(11, weight: .heavy)).foregroundStyle(Palette.muted)
                        ForEach(Array(log.reversed().enumerated()), id: \.offset) { _, s in
                            HStack {
                                Text(String(s.year)).frame(width: 44, alignment: .leading)
                                Text(s.club).frame(width: 40, alignment: .leading)
                                Text("\(s.matches)").frame(width: 24)
                                Text("\(s.runs)").fontWeight(.semibold).frame(maxWidth: .infinity)
                                Text(s.balls > 0 ? "\(s.runs * 100 / s.balls)" : "–").frame(width: 34)
                                Text("\(s.wickets)").fontWeight(.semibold).frame(width: 36)
                                Text(s.ballsBowled > 0 ? String(format: "%.1f", Double(s.runsConceded) * 6 / Double(s.ballsBowled)) : "–")
                                    .frame(width: 36)
                            }
                            .font(.caption.monospacedDigit())
                        }
                    }
                }
            }
        }
    }
}

struct StatGrid: View {
    let line: StatLine
    var titles: Int? = nil

    var body: some View {
        let s = line
        AppCard {
            VStack(spacing: DS.Space.md) {
                HStack(spacing: 0) {
                    cell("\(s.matches)", "MATCHES")
                    cell("\(s.runs)", "RUNS")
                    cell("\(s.highScore)", "BEST")
                    cell(s.balls > 0 ? String(format: "%.0f", s.strikeRate) : "–", "SR")
                }
                HStack(spacing: 0) {
                    cell("\(s.fours)/\(s.sixes)", "4s/6s")
                    cell("\(s.wickets)", "WICKETS")
                    cell(s.ballsBowled > 0 ? String(format: "%.1f", s.economy) : "–", "ECON")
                    if let titles { cell("\(titles)", "TITLES") } else { cell("\(s.potm)", "POTM") }
                }
                if s.fifties + s.hundreds > 0 {
                    Text("\(s.fifties) fifties · \(s.hundreds) hundreds · \(s.potm) player-of-the-match awards")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private func cell(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.display(24)).lineLimit(1).minimumScaleFactor(0.6)
            Text(l).font(.display(10, weight: .heavy)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Leaderboards for this season and all-time.
struct StatsCentreView: View {
    var body: some View {
        CareerScreen(title: "Stats") { StatsBoards() }
    }
}

/// Season / all-time leaderboards (League tab and the Stats screen).
struct StatsBoards: View {
    @EnvironmentObject var store: GameStore
    @State private var scope: StatScope = .season

    private static let boards: [(MarketSort, String)] = [
        (.runs, "🟠 Most runs"), (.wickets, "🟣 Most wickets"), (.sixes, "💥 Most sixes"),
        (.strikeRate, "⚡️ Best strike rate"), (.economy, "🔒 Best economy"),
    ]

    var body: some View {
        Group {
            if let c = store.career {
                let season = c.seasonStatLines
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    Picker("Scope", selection: $scope) {
                        Text("Season \(String(c.year))").tag(StatScope.season)
                        Text("All-time since \(String(c.startYear))").tag(StatScope.allTime)
                    }
                    .pickerStyle(.segmented)
                    if scope == .season && season.isEmpty {
                        Text("No matches played this season yet.").foregroundStyle(.secondary)
                    }
                    ForEach(Self.boards, id: \.0) { board in
                        let rows = c.leaders(board.0, scope: scope, limit: 8)
                        if !rows.isEmpty {
                            Text(board.1).font(.headline)
                            AppCard(padding: DS.Space.md) {
                                VStack(spacing: 8) {
                                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, p in
                                        NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                                            LeaderRow(career: c, player: p, rank: i + 1, sort: board.0, scope: scope, season: season)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    Text("Strike rate and economy need at least \(c.minBalls(scope)) balls.")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
            }
        }
    }
}

struct LeaderRow: View {
    let career: Career
    let player: CareerPlayer
    let rank: Int
    let sort: MarketSort
    let scope: StatScope
    let season: [String: StatLine]

    var body: some View {
        let s = career.statLine(player.id, scope: scope, season: season)
        let club = player.clubId.flatMap { career.club($0) }
        HStack(spacing: 10) {
            Text("\(rank)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 16)
            if let club { TeamBadge(team: club, size: 22) }
            VStack(alignment: .leading, spacing: 1) {
                Text(player.name).font(.subheadline.weight(rank == 1 ? .bold : .regular)).lineLimit(1)
                Text(club?.short ?? (player.retired ? "Retired" : "Free agent")).font(.caption2).foregroundStyle(Palette.muted)
            }
            Spacer()
            Text(value(s)).font(.score(16))
        }
        .contentShape(Rectangle())
    }

    private func value(_ s: StatLine) -> String {
        switch sort {
        case .runs: return "\(s.runs)"
        case .wickets: return "\(s.wickets)"
        case .sixes: return "\(s.sixes)"
        case .strikeRate: return String(format: "%.1f", s.strikeRate)
        case .economy: return String(format: "%.2f", s.economy)
        default: return "\(player.rating)"
        }
    }
}
