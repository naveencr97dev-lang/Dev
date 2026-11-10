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

/// League › Leaders: four boards in a 2×2 grid (orange cap, most sixes, purple cap, best economy).
struct LeadersGrid: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        if let c = store.career {
            let season = c.seasonStatLines
            if season.isEmpty {
                Text("No matches played this season yet.").foregroundStyle(.secondary)
            } else {
                VStack(spacing: DS.Space.sm) {
                    HStack(alignment: .top, spacing: DS.Space.sm) {
                        board(c, season, "Orange Cap · most runs", .runs) { "\($0.runs)" }
                        board(c, season, "Most sixes", .sixes) { "\($0.sixes)" }
                    }
                    HStack(alignment: .top, spacing: DS.Space.sm) {
                        board(c, season, "Purple Cap · most wickets", .wickets) { "\($0.wickets)" }
                        board(c, season, "Best economy", .economy) { String(format: "%.2f", $0.economy) }
                    }
                }
            }
        }
    }

    private func board(_ c: Career, _ season: [String: StatLine], _ title: String, _ sort: MarketSort,
                       _ value: @escaping (StatLine) -> String) -> some View {
        let rows = c.leaders(sort, scope: .season, limit: 5)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.system(size: 11 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.accent)
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, p in
                HStack(spacing: 6) {
                    Text("\(i + 1)").font(.score(11)).foregroundStyle(Palette.muted).frame(width: 12)
                    if let club = p.clubId.flatMap({ c.club($0) }) { TeamBadge(team: club, size: 16) }
                    Text(p.name).font(.system(size: 13 * TextScale.factor, weight: i == 0 ? .bold : .regular)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(value(c.statLine(p.id, scope: .season, season: season))).font(.score(14))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surface))
    }
}

/// League › Stats: one top-10 table; pick the category and season or all-time.
struct StatsTable: View {
    @EnvironmentObject var store: GameStore
    @State private var sort: MarketSort = .runs
    @State private var scope: StatScope = .season
    private static let sorts: [MarketSort] = [.runs, .wickets, .sixes, .strikeRate, .economy]

    var body: some View {
        if let c = store.career {
            let season = c.seasonStatLines
            let rows = c.leaders(sort, scope: scope, limit: 10)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Menu {
                        ForEach(Self.sorts) { s in Button(title(s)) { sort = s } }
                    } label: { pill(title(sort)) }
                    Menu {
                        Button("Season \(String(c.year))") { scope = .season }
                        Button("All-time since \(String(c.startYear))") { scope = .allTime }
                    } label: { pill(scope == .season ? "Season \(String(c.year))" : "All-time") }
                    Spacer()
                    if sort == .strikeRate || sort == .economy {
                        Text("min \(c.minBalls(scope)) balls").font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted)
                    }
                }
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Text("#").frame(width: 18, alignment: .leading)
                        Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
                        Text("CLUB").frame(width: 44, alignment: .leading)
                        Text("M").frame(width: 28, alignment: .trailing)
                        Text(secondTitle).frame(width: 52, alignment: .trailing)
                        Text(title(sort).uppercased()).frame(width: 70, alignment: .trailing).lineLimit(1)
                    }
                    .font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    if rows.isEmpty {
                        Text("No matches yet.").font(.subheadline).foregroundStyle(.secondary).padding(10)
                    }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, p in
                        let s = c.statLine(p.id, scope: scope, season: season)
                        Hairline(inset: 10)
                        NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                            HStack(spacing: 8) {
                                Text("\(i + 1)").font(.score(12)).foregroundStyle(Palette.muted).frame(width: 18, alignment: .leading)
                                Text(p.name).font(.system(size: 13 * TextScale.factor, weight: i == 0 ? .bold : .semibold)).lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(p.clubId.flatMap { c.club($0)?.short } ?? "–").font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted)
                                    .frame(width: 44, alignment: .leading)
                                Text("\(s.matches)").font(.score(12)).foregroundStyle(Palette.muted).frame(width: 28, alignment: .trailing)
                                Text(second(s)).font(.score(12)).foregroundStyle(Palette.muted).frame(width: 52, alignment: .trailing)
                                Text(main(s)).font(.score(15)).foregroundStyle(Palette.accent).frame(width: 70, alignment: .trailing)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surface))
            }
        }
    }

    private func title(_ s: MarketSort) -> String {
        switch s {
        case .runs: return "Most runs"
        case .wickets: return "Most wickets"
        case .sixes: return "Most sixes"
        case .strikeRate: return "Best strike rate"
        case .economy: return "Best economy"
        default: return s.label
        }
    }

    private var secondTitle: String {
        switch sort {
        case .runs, .sixes: return "SR"
        case .wickets: return "ECON"
        case .strikeRate: return "RUNS"
        default: return "WKTS"
        }
    }

    private func main(_ s: StatLine) -> String {
        switch sort {
        case .runs: return "\(s.runs)"
        case .wickets: return "\(s.wickets)"
        case .sixes: return "\(s.sixes)"
        case .strikeRate: return String(format: "%.1f", s.strikeRate)
        default: return String(format: "%.2f", s.economy)
        }
    }

    private func second(_ s: StatLine) -> String {
        switch sort {
        case .runs, .sixes: return s.balls > 0 ? String(format: "%.0f", s.strikeRate) : "–"
        case .wickets: return s.ballsBowled > 0 ? String(format: "%.1f", s.economy) : "–"
        case .strikeRate: return "\(s.runs)"
        default: return "\(s.wickets)"
        }
    }

    private func pill(_ text: String) -> some View {
        HStack(spacing: 3) {
            Text(text).lineLimit(1)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9 * TextScale.factor, weight: .bold))
        }
        .font(.system(size: 12 * TextScale.factor, weight: .semibold))
        .foregroundStyle(Palette.accent)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(Palette.surface))
    }
}
