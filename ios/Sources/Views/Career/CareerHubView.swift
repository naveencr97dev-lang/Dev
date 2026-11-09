import SwiftUI

/// Career home in manager-game style: status bar, the desk (next match, news), a dashboard of
/// tiles, and one CONTINUE button that always does the next thing.
struct CareerHubView: View {
    @EnvironmentObject var store: GameStore
    @State private var path: [Route] = []
    @State private var note: String? = nil
    @State private var confirmSimSeason = false
    @State private var showRetention = false
    @State private var showAuction = false
    @State private var tab: HubTab = .home
    @State private var leagueSection = 0

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                ManagerBackground()
                ScrollView {
                    if let c = store.career {
                        VStack(alignment: .leading, spacing: DS.Space.md) {
                            switch tab {
                            case .home:
                                CareerTopBar(career: c)
                                CareerHomeTab(path: $path, note: $note)
                            case .squad:
                                CareerSquadTab()
                            case .transfers:
                                CareerMarketTab()
                            case .league:
                                Picker("League", selection: $leagueSection) {
                                    Text("Fixtures").tag(0)
                                    Text("Table").tag(1)
                                    Text("Stats").tag(2)
                                    Text("World").tag(3)
                                }
                                .pickerStyle(.segmented)
                                switch leagueSection {
                                case 0: CareerFixturesTab(path: $path)
                                case 1: CareerTableTab(path: $path)
                                case 2: StatsBoards()
                                default: CareerWorldTab(path: $path)
                                }
                            case .club:
                                ClubOfficeTiles(career: c)
                                CareerClubTab(path: $path)
                            }
                        }
                        .padding(.horizontal, DS.Space.md)
                        .padding(.top, DS.Space.sm)
                        .padding(.bottom, 170)
                        .frame(maxWidth: 900)
                        .frame(maxWidth: .infinity)
                    }
                }
                if let c = store.career {
                    VStack(spacing: 4) {
                        ContinueBar(career: c) { perform(c.nextAction) }
                        HubTabBar(tab: $tab, career: c)
                    }
                }
            }
            .navigationTitle("Career")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .match(let id): MatchView(fixtureId: id)
                case .result(let id): ResultScreen(resultId: id)
                case .highlights(let id): ResultScreen(resultId: id, autoplay: true)
                case .team(let id): CareerClubView(clubId: id)
                }
            }
            .navigationDestination(isPresented: $showRetention) { RetentionView() }
            .navigationDestination(isPresented: $showAuction) { CareerAuctionView() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if store.career?.phase == .season {
                            Button { confirmSimSeason = true } label: {
                                Label("Quick-sim rest of season", systemImage: "forward.end.fill")
                            }
                        }
                        TextSizePicker()
                        Button { store.exitCareer() } label: {
                            Label("Main menu", systemImage: "house")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog("Simulate every remaining match, yours included?", isPresented: $confirmSimSeason,
                                titleVisibility: .visible) {
                Button("Sim to season end") { store.careerSimToSeasonEnd() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    /// What CONTINUE does.
    private func perform(_ action: CareerAction) {
        Haptics.tap()
        switch action {
        case .goToOffseason: note = CareerText.rollover(store.careerBeginOffseason())
        case .openWindow: store.careerEnsureWindow()
        case .playIntl(let id), .playMatch(let id), .watchOther(let id): path.append(.match(id))
        case .simWindow:
            let n = store.careerSimWindow(stopAtUser: true)
            note = "Simulated \(n) international match\(n == 1 ? "" : "es")."
        case .retention: showRetention = true
        case .auction: showAuction = true
        case .startSeason:
            let signed = store.careerStartSeason()
            note = signed.isEmpty ? "The season is under way!" : "The board filled your squad: \(signed.joined(separator: ", "))."
        case .continueToMatch:
            // One press: the other games in the round sim, then your match starts.
            let n = store.careerSimUntilUserMatch()
            if case .playMatch(let id) = store.career?.nextAction {
                path.append(.match(id))
            } else {
                note = "Simulated \(n) match\(n == 1 ? "" : "es") around the league."
            }
        case .none: break
        }
    }
}

/// The big CONTINUE button pinned to the bottom.
struct ContinueBar: View {
    let career: Career
    let action: () -> Void

    var body: some View {
        let label = career.nextActionLabel
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label.title).font(.system(size: 20 * TextScale.factor, weight: .bold))
                    if !label.detail.isEmpty {
                        Text(label.detail).font(.caption.weight(.bold)).textCase(nil).lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 16 * TextScale.factor, weight: .bold))
            }
            .padding(.horizontal, 18)
        }
        .buttonStyle(GameButtonStyle(kind: .primary))
        .padding(.horizontal, DS.Space.md)
        .padding(.bottom, DS.Space.xs)
        .frame(maxWidth: 640)
    }
}

/// Bottom tabs of the career hub.
enum HubTab: Int, CaseIterable {
    case home, squad, transfers, league, club

    var label: String { ["Home", "Squad", "Transfers", "League", "Club"][rawValue] }
    var icon: String { ["house.fill", "person.3.fill", "arrow.left.arrow.right", "trophy.fill", "building.columns.fill"][rawValue] }
}

/// Game-style tab bar pinned under CONTINUE.
struct HubTabBar: View {
    @Binding var tab: HubTab
    let career: Career

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 0) {
                ForEach(HubTab.allCases, id: \.self) { t in
                    Button {
                        tab = t
                        Haptics.tap()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: t.icon).font(.system(size: 20 * TextScale.factor, weight: .medium))
                                .overlay(alignment: .topTrailing) {
                                    if let b = badge(t) {
                                        Text(b).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                            .padding(.horizontal, 4).padding(.vertical, 1)
                                            .background(Capsule().fill(Palette.wicket))
                                            .offset(x: 10, y: -6)
                                    }
                                }
                            Text(t.label).font(.system(size: 10 * TextScale.factor, weight: .medium)).lineLimit(1)
                        }
                        .foregroundStyle(tab == t ? Palette.accent : Palette.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 7)
                        .padding(.bottom, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 640)
        }
        .background(Palette.surface.opacity(0.98).ignoresSafeArea(edges: .bottom))
    }

    private func badge(_ t: HubTab) -> String? {
        let c = career
        switch t {
        case .squad: return c.xiIssues(c.userClubId).isEmpty ? nil : "!"
        case .transfers: return c.market.offers.isEmpty ? nil : "\(c.market.offers.count)"
        case .club: return c.manager.points > 0 ? "\(c.manager.points)" : nil
        case .league: return c.intl.job == nil && !c.intl.offers.isEmpty ? "\(c.intl.offers.count)" : nil
        case .home: return nil
        }
    }
}

enum CareerText {
    static func fixtureLabel(_ c: Career, _ f: Fixture) -> String {
        let date = CareerCalendar.label(c.day(of: f))
        if let r = c.round(of: f) { return "Round \(r) of \(c.totalRounds) · \(date)" }
        return "\(f.stage.label) · \(date)"
    }

    static func form(_ v: Int) -> String { v > 0 ? "+\(v)" : "\(v)" }

    static func formColor(_ v: Int) -> Color {
        v >= 3 ? Palette.accent : (v <= -3 ? Palette.wicket : Palette.muted)
    }

    static func rollover(_ r: Career.RolloverReport) -> String {
        var parts = ["Off-season! \(r.retired.count) retirements, \(r.youth) youngsters entered the pool."]
        if !r.userRetired.isEmpty { parts.append("Retired from your squad: \(r.userRetired.joined(separator: ", ")).") }
        if !r.signed.isEmpty { parts.append("Signed to fill your squad: \(r.signed.joined(separator: ", ")).") }
        if !r.bigRisers.isEmpty { parts.append("Big improvers: \(r.bigRisers.joined(separator: ", ")).") }
        return parts.joined(separator: " ")
    }
}

/// Club tab: the office tiles.
struct ClubOfficeTiles: View {
    let career: Career

    var body: some View {
        let c = career
        VStack(spacing: 0) {
            NavigationLink { FacilitiesView() } label: {
                DashTile(icon: "building.2", title: "Facilities",
                         subtitle: c.facilities.building.flatMap { FacilityKind(rawValue: $0)?.label }.map { "Building \($0)" } ?? "7 facilities")
            }
            Hairline(inset: 54)
            NavigationLink { ManagerView() } label: {
                DashTile(icon: "star", title: "Manager", subtitle: "Level \(c.manager.level) · traits",
                         badge: c.manager.points > 0 ? "\(c.manager.points)" : nil)
            }
            Hairline(inset: 54)
            NavigationLink { StoreView() } label: {
                DashTile(icon: "bag", title: "Store", subtitle: "\(c.gold) gold")
            }
            Hairline(inset: 54)
            NavigationLink { NewsScreen() } label: {
                DashTile(icon: "newspaper", title: "News", subtitle: "\(c.news.count) items")
            }
            Hairline(inset: 54)
            NavigationLink { CareerSettingsView() } label: {
                DashTile(icon: "gearshape", title: "Settings",
                         subtitle: "\(c.settings.difficulty.label) · market \(c.settings.marketAlwaysOpen ? "open" : "windows")")
            }
        }
        .gameFrame()
        .buttonStyle(.plain)
    }
}

/// All news.
struct NewsScreen: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        CareerScreen(title: "News") {
            NewsFeed(news: store.career?.news ?? [])
        }
    }
}

struct CareerHomeTab: View {
    @EnvironmentObject var store: GameStore
    @Binding var path: [Route]
    @Binding var note: String?

    var body: some View {
        if let c = store.career {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                // The one thing to do now.
                if c.phase == .seasonEnd {
                    SeasonEndCard(career: c) {
                        let report = store.careerBeginOffseason()
                        note = CareerText.rollover(report)
                        Haptics.success()
                    }
                } else if c.pendingWindow != nil {
                    WindowCard(career: c, path: $path, note: $note)
                } else if c.phase == .offseason {
                    OffseasonCard(career: c) { signed in
                        note = signed.isEmpty ? "Season \(c.year) is under way." : "The board filled your squad: \(signed.joined(separator: ", "))."
                    }
                } else if let f = c.nextUserFixture {
                    NextMatchHero(career: c, fixture: f) {
                        if let r = store.play(fixtureId: f.id) { path.append(.result(r.id)) }
                    }
                } else if c.nextFixture != nil {
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        Text("You're out of the playoffs").font(.display(20, weight: .bold))
                        Text("Watch the remaining matches with Continue, or sim to the end.").font(.display(14, weight: .regular)).foregroundStyle(Palette.muted)
                        Button("Sim to season end") { store.careerSimToSeasonEnd() }.buttonStyle(SecondaryButtonStyle())
                    }
                }
                if let note {
                    Text(note).font(.display(12, weight: .regular)).foregroundStyle(Palette.muted)
                }
                SeasonSummary(career: c, path: $path)
                BoardObjectivesCard(career: c)
                NewsFeed(news: Array(c.news.prefix(3)))
                if c.news.count > 3 {
                    NavigationLink { NewsScreen() } label: {
                        Text("All news").font(.display(14, weight: .semibold)).foregroundStyle(Palette.accent)
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }
}

/// Home hero: the next match, big and plain.
struct NextMatchHero: View {
    let career: Career
    let fixture: Fixture
    let quickSim: () -> Void

    var body: some View {
        let c = career
        let home = fixture.home == c.userClubId
        let oppId = home ? fixture.away : fixture.home
        let isNext = c.nextFixture?.id == fixture.id
        VStack(alignment: .leading, spacing: DS.Space.md) {
            Text("NEXT MATCH · \(CareerText.fixtureLabel(c, fixture).uppercased())")
                .font(.display(12, weight: .semibold)).foregroundStyle(Palette.muted)
            if let opp = c.club(oppId) {
                HStack(spacing: DS.Space.md) {
                    TeamBadge(team: opp, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(home ? "vs" : "at") \(opp.name)").font(.display(28, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                        Text("\(home ? "Home" : "Away") · \(fixture.pitch.label) · they're \(Career.ordinal(c.position(of: oppId)))")
                            .font(.display(14, weight: .regular)).foregroundStyle(Palette.muted).lineLimit(1)
                    }
                }
            }
            if isNext {
                Button("Sim result instead", action: quickSim)
                    .font(.display(14, weight: .semibold)).foregroundStyle(Palette.accent)
            } else {
                Text("Other games in the round sim first.").font(.display(12, weight: .regular)).foregroundStyle(Palette.muted)
            }
        }
        .padding(DS.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameFrame()
    }
}

/// Home: the season at a glance, one grouped list.
struct SeasonSummary: View {
    let career: Career
    @Binding var path: [Route]

    var body: some View {
        let c = career
        let row = c.table.first { $0.teamId == c.userClubId }
        let last = c.results.last { $0.teamA == c.userClubId || $0.teamB == c.userClubId }
        let net = MoneyCategory.allCases.reduce(0) { $0 + c.seasonTotal($1) }
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Season \(String(c.year))")
            VStack(spacing: 0) {
                NavigationLink { CareerScreen(title: "League") { CareerTableTab(path: $path) } } label: {
                    InfoRow(label: "League", value: "\(Career.ordinal(c.position(of: c.userClubId))) · \(row?.points ?? 0) pts · \(row?.won ?? 0)–\(row?.lost ?? 0)")
                }
                Hairline(inset: 16)
                InfoRow(label: "Form", value: c.userForm().isEmpty ? "–" : c.userForm().map { $0 ? "W" : "L" }.joined(separator: " "), chevron: false)
                if let last {
                    Hairline(inset: 16)
                    Button { path.append(.result(last.id)) } label: {
                        InfoRow(label: "Last result",
                                value: "\(last.winnerId == c.userClubId ? "Won" : "Lost") vs \(c.club(last.teamA == c.userClubId ? last.teamB : last.teamA)?.short ?? "")",
                                color: last.winnerId == c.userClubId ? Palette.accent : Palette.wicket)
                    }
                }
                Hairline(inset: 16)
                NavigationLink { CareerScreen(title: "Money") { SeasonMoneyCard(career: c) } } label: {
                    InfoRow(label: "Money this season", value: (net >= 0 ? "+" : "−") + Money.format(abs(net)),
                            color: net >= 0 ? Palette.accent : Palette.wicket)
                }
                if c.phase == .season {
                    Hairline(inset: 16)
                    NavigationLink { TrainingView() } label: {
                        InfoRow(label: "Training", value: c.trainingDoneThisWeek ? "Done this week" : "Session ready")
                    }
                }
            }
            .gameFrame()
            .buttonStyle(.plain)
        }
    }
}

/// Label on the left, value on the right, optional chevron.
struct InfoRow: View {
    let label: String
    let value: String
    var color: Color = .white
    var chevron = true

    var body: some View {
        HStack {
            Text(label).font(.display(16, weight: .regular)).foregroundStyle(.white)
            Spacer(minLength: 8)
            Text(value).font(.score(16, weight: .regular)).foregroundStyle(color == .white ? Palette.muted : color).lineLimit(1)
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 13 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.stroke)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}



struct SeasonEndCard: View {
    let career: Career
    let onNext: () -> Void

    var body: some View {
        let c = career
        let record = c.history.last
        AppCard(tint: Palette.accent) {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                if let champ = c.championId.flatMap({ c.club($0) }) {
                    HStack(spacing: 12) {
                        TeamBadge(team: champ, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(c.year) CHAMPIONS").font(.display(14, weight: .heavy)).foregroundStyle(Palette.accent)
                            Text(champ.name.uppercased()).font(.display(24))
                        }
                    }
                }
                if let record {
                    Text("Your season: \(record.userFinish)").font(.headline)
                    VStack(alignment: .leading, spacing: 4) {
                        if let a = record.orangeCap { Text("Orange Cap: \(a.name) — \(a.value)") }
                        if let a = record.purpleCap { Text("Purple Cap: \(a.name) — \(a.value)") }
                        if let a = record.mvp { Text("MVP: \(a.name) — \(a.value)") }
                    }
                    .font(.subheadline)
                }
                Button("Go to the \(String(c.year + 1)) off-season ▶︎", action: onNext).buttonStyle(PrimaryButtonStyle())
                Text("Players age a year, develop or decline, veterans retire and a youth intake joins the pool. Then retentions (mega-auction years), the auction and the transfer window.")
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
        }
    }
}

struct NewsFeed: View {
    let news: [NewsItem]

    var body: some View {
        if !news.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionLabel(text: "News")
                AppCard(padding: DS.Space.md) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(news) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: icon(item.kind)).font(.system(size: 14 * TextScale.factor))
                                    .foregroundStyle(Palette.muted).frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(NewsFeed.clean(item.text)).font(.subheadline)
                                    Text("\(CareerCalendar.label(item.day)) \(String(item.year))")
                                        .font(.caption2).foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func icon(_ k: NewsItem.Kind) -> String {
        switch k {
        case .result: return "sportscourt"
        case .milestone: return "star"
        case .squad: return "person.2"
        case .season: return "trophy"
        case .info: return "newspaper"
        }
    }

    /// News text without a leading emoji (icons come from SF Symbols).
    static func clean(_ t: String) -> String {
        guard let first = t.unicodeScalars.first, first.properties.isEmojiPresentation || first.properties.isEmoji && first.value > 0x238C else { return t }
        guard let space = t.firstIndex(of: " ") else { return t }
        return String(t[t.index(after: space)...])
    }
}

// MARK: - Fixtures

struct CareerFixturesTab: View {
    @EnvironmentObject var store: GameStore
    @Binding var path: [Route]
    @State private var showAll = false

    var body: some View {
        if let c = store.career {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Picker("Show", selection: $showAll) {
                    Text("Your matches").tag(false)
                    Text("League results").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, DS.Space.sm)

                if showAll {
                    let others = Array(c.results.reversed().prefix(40))
                    if others.isEmpty {
                        Text("No results yet.").foregroundStyle(.secondary)
                    }
                    ForEach(others, id: \.id) { r in
                        Button { path.append(.result(r.id)) } label: { ResultRow(result: r) }
                            .buttonStyle(.plain)
                    }
                } else {
                    ForEach(c.userFixtures) { f in
                        Button {
                            if let r = c.result(f.resultId) { path.append(.result(r.id)) }
                        } label: {
                            FixtureRow(career: c, fixture: f)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct FixtureRow: View {
    let career: Career
    let fixture: Fixture

    var body: some View {
        let c = career
        let oppId = fixture.home == c.userClubId ? fixture.away : fixture.home
        let r = c.result(fixture.resultId)
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(CareerCalendar.label(c.day(of: fixture))).font(.score(15))
                Text(c.round(of: fixture).map { "R\($0)" } ?? fixture.stage.label)
                    .font(.caption2).foregroundStyle(Palette.muted).lineLimit(1)
            }
            .frame(width: 70, alignment: .leading)
            if let opp = c.club(oppId) {
                TeamBadge(team: opp, size: 28)
                Text("\(fixture.home == c.userClubId ? "vs" : "at") \(opp.short)").font(.subheadline.weight(.semibold))
            }
            Text(fixture.pitch.icon).font(.caption)
            Spacer()
            if let r {
                let won = r.winnerId == c.userClubId
                Text(won ? "W" : "L")
                    .font(.display(14, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(won ? Palette.accent : Palette.wicket))
                Text(scoreLine(r)).font(.score(13, weight: .regular)).foregroundStyle(Palette.muted)
            } else {
                Text("Upcoming").font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, DS.Space.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surface))
    }

    private func scoreLine(_ r: MatchResult) -> String {
        r.innings.prefix(2).map(\.score).joined(separator: " · ")
    }
}

// MARK: - Table

struct CareerTableTab: View {
    @EnvironmentObject var store: GameStore
    @Binding var path: [Route]

    var body: some View {
        if let c = store.career {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                if c.fixtures.contains(where: { $0.stage != .league }) {
                    CareerPlayoffs(career: c) { path.append(.result($0)) }
                }
                CareerPointsTable(career: c) { path.append(.team($0)) }
                CareerLeaders(career: c)
            }
        }
    }
}

struct CareerPointsTable: View {
    let career: Career
    let onOpen: (Int) -> Void

    var body: some View {
        let c = career
        let table = c.table
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Points table")
            AppCard(padding: DS.Space.md) {
                VStack(spacing: 10) {
                    HStack {
                        Text("#").frame(width: 18, alignment: .leading)
                        Text("Team").frame(maxWidth: .infinity, alignment: .leading)
                        Text("P").frame(width: 24)
                        Text("W").frame(width: 24)
                        Text("L").frame(width: 24)
                        Text("Pts").frame(width: 32)
                        Text("NRR").frame(width: 52, alignment: .trailing)
                    }
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(Array(table.enumerated()), id: \.element.teamId) { i, row in
                        if let t = c.club(row.teamId) {
                            Button { onOpen(t.id) } label: {
                                HStack {
                                    Text("\(i + 1)").frame(width: 18, alignment: .leading).foregroundStyle(.secondary)
                                    HStack(spacing: 8) {
                                        TeamBadge(team: t, size: 24)
                                        Text(t.short).fontWeight(.semibold)
                                        if !t.isCPU { Image(systemName: "person.fill").font(.caption2).foregroundStyle(Palette.accent) }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(row.played)").frame(width: 24)
                                    Text("\(row.won)").frame(width: 24)
                                    Text("\(row.lost)").frame(width: 24)
                                    Text("\(row.points)").fontWeight(.heavy).frame(width: 32)
                                    Text(String(format: "%+.2f", row.nrr)).frame(width: 52, alignment: .trailing)
                                        .foregroundStyle(row.nrr >= 0 ? Palette.four : Palette.wicket)
                                }
                                .font(.subheadline.monospacedDigit())
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if i == 3 {
                                Rectangle().fill(Palette.accent.opacity(0.5)).frame(height: 1)
                            }
                        }
                    }
                }
            }
            Text("Top 4 reach the playoffs. Tap a club to see its squad.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct CareerPlayoffs: View {
    let career: Career
    let onOpen: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Playoffs")
            AppCard(padding: DS.Space.md) {
                VStack(spacing: 10) {
                    ForEach([Stage.qualifier1, .eliminator, .qualifier2, .final], id: \.self) { stage in
                        row(stage)
                    }
                }
            }
        }
    }

    private func row(_ stage: Stage) -> some View {
        let c = career
        let f = c.fixtures.first { $0.stage == stage }
        let r = c.result(f?.resultId)
        return Button {
            if let r { onOpen(r.id) }
        } label: {
            HStack {
                Text(stage.label).font(.caption.weight(.bold)).frame(width: 86, alignment: .leading)
                    .foregroundStyle(stage == .final ? Palette.accent : .primary)
                if let f, let a = c.club(f.home), let b = c.club(f.away) {
                    Text(a.short).fontWeight(r?.winnerId == a.id ? Font.Weight.heavy : Font.Weight.regular)
                    Text("v").foregroundStyle(.secondary)
                    Text(b.short).fontWeight(r?.winnerId == b.id ? Font.Weight.heavy : Font.Weight.regular)
                    Spacer()
                    if let r, let w = c.club(r.winnerId) {
                        Text("\(w.short) won").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(CareerCalendar.label(c.day(of: f))).font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("TBD").foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .font(.subheadline)
        }
        .buttonStyle(.plain)
    }
}

struct CareerLeaders: View {
    let career: Career

    var body: some View {
        let stats = Array(SeasonEngine.playerStats(results: career.results).values)
        if !stats.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                board("🟠 Orange Cap", Array(stats.filter { $0.runs > 0 }.sorted { $0.runs > $1.runs }.prefix(5))) { s in
                    "\(s.runs) runs · SR \(s.ballsFaced == 0 ? 0 : s.runs * 100 / s.ballsFaced)"
                }
                board("🟣 Purple Cap", Array(stats.filter { $0.wickets > 0 }.sorted { $0.wickets > $1.wickets }.prefix(5))) { s in
                    "\(s.wickets) wkts · econ \(String(format: "%.1f", s.economy))"
                }
                board("⭐ MVP race", Array(stats.sorted { $0.mvpPoints > $1.mvpPoints }.prefix(5))) { s in
                    "\(Int(s.mvpPoints)) pts"
                }
            }
        }
    }

    private func board(_ title: String, _ rows: [PlayerSeason], stat: @escaping (PlayerSeason) -> String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text(title).font(.headline)
            AppCard(padding: DS.Space.md) {
                VStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, s in
                        HStack(spacing: 10) {
                            Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 14)
                            if let t = career.club(s.teamId) { TeamBadge(team: t, size: 24) }
                            Text(career.players[s.id]?.name ?? s.id).font(.subheadline.weight(i == 0 ? .bold : .regular)).lineLimit(1)
                            Spacer()
                            Text(stat(s)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Club

struct CareerClubTab: View {
    @EnvironmentObject var store: GameStore
    @Binding var path: [Route]

    var body: some View {
        if let c = store.career {
            let club = c.userClub
            let info = c.info(c.userClubId)
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                AppCard(tint: Color(hex: club.colorHex)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(club.name.uppercased()).font(.display(26))
                        if let info {
                            Text("\(info.homePitch.icon) Home ground: \(info.homePitch.label)").font(.subheadline)
                            Text(info.homePitch.blurb).font(.caption).foregroundStyle(Palette.muted)
                            Text("Titles: \(info.titles)").font(.subheadline)
                        }
                        Text("Manager since \(String(c.startYear)) · \(c.history.count) season\(c.history.count == 1 ? "" : "s") completed")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                }

                ManagerCard(career: c)
                HStack(spacing: DS.Space.sm) {
                    NavigationLink { FacilitiesView() } label: {
                        SquadAction(icon: "building.2", text: "Facilities")
                    }
                    NavigationLink { ManagerView() } label: {
                        SquadAction(icon: "star.circle", text: "Traits \(c.manager.points)")
                    }
                    NavigationLink { StoreView() } label: {
                        SquadAction(icon: "bag", text: "Store")
                    }
                }
                .buttonStyle(.plain)

                FinanceCard(career: c)

                SectionLabel(text: "History")
                if c.history.isEmpty {
                    Text("Your first season is under way.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: DS.Space.sm) {
                        ForEach(c.history.reversed()) { h in
                            HistoryRow(career: c, record: h)
                        }
                    }
                }

                SectionLabel(text: "Roll of honour")
                AppCard(padding: DS.Space.md) {
                    VStack(spacing: 8) {
                        ForEach(c.clubInfo.sorted { $0.titles != $1.titles ? $0.titles > $1.titles : $0.id < $1.id }) { i in
                            if let t = c.club(i.id) {
                                Button { path.append(.team(t.id)) } label: {
                                    HStack(spacing: 10) {
                                        TeamBadge(team: t, size: 26)
                                        Text(t.name).font(.subheadline)
                                        Spacer()
                                        Text(i.titles > 0 ? String(repeating: "🏆", count: min(i.titles, 6)) + (i.titles > 6 ? " ×\(i.titles)" : "") : "–")
                                            .font(.caption)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct HistoryRow: View {
    let career: Career
    let record: SeasonRecord

    var body: some View {
        AppCard(padding: DS.Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(String(record.year)).font(.display(22)).foregroundStyle(Palette.accent)
                    Spacer()
                    if let champ = career.club(record.championId) {
                        Text("\(champ.short)").font(.subheadline.weight(.bold))
                    }
                }
                Text("You: \(record.userFinish) · \(Career.ordinal(record.userPosition)) in the league").font(.subheadline)
                if let a = record.orangeCap { Text("\(a.name) \(a.value)").font(.caption).foregroundStyle(Palette.muted) }
                if let a = record.purpleCap { Text("\(a.name) \(a.value)").font(.caption).foregroundStyle(Palette.muted) }
            }
        }
    }
}
