import SwiftUI

// MARK: - International window (Home tab)

struct WindowCard: View {
    @EnvironmentObject var store: GameStore
    let career: Career
    @Binding var path: [Route]
    @Binding var note: String?

    var body: some View {
        let c = career
        let started = c.intl.event?.key == c.pendingWindow
        AppCard(tint: Palette.four) {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                Text("🌍 INTERNATIONAL WINDOW").font(.display(15, weight: .heavy)).foregroundStyle(Palette.four)
                if !started {
                    Text("The league pauses for international cricket.").font(.subheadline)
                    Button("Open the window ▶︎") { store.careerEnsureWindow() }
                        .buttonStyle(PrimaryButtonStyle())
                } else if let e = c.intl.event {
                    Text(e.title.uppercased()).font(.display(20))
                    if let job = c.intl.job {
                        Text("You coach \(c.intl.nations.first { $0.code == job }?.name ?? job) · target: \(c.intl.target)")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    let done = c.intl.fixtures.filter(\.played).count
                    Text("\(done)/\(c.intl.fixtures.count) matches played · stage: \(e.stage.label)")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
            }
        }
        if started, let f = c.nextIntlFixture, c.isUserNationFixture(f) {
            NextMatchCard(fixture: f, number: "\(f.stage.label) · \(CareerCalendar.label(c.intl.days[f.id] ?? 100))") {
                path.append(.match(f.id))
            } quick: {
                if let r = store.play(fixtureId: f.id) { path.append(.result(r.id)) }
            }
        }
        if started {
            HStack(spacing: DS.Space.sm) {
                if c.intl.job != nil {
                    Button("Sim to my next match") {
                        let n = store.careerSimWindow(stopAtUser: true)
                        note = "Simulated \(n) international match\(n == 1 ? "" : "es")."
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Button("Sim the whole window") {
                    let n = store.careerSimWindow(stopAtUser: false)
                    note = "Simulated \(n) international match\(n == 1 ? "" : "es"). The league resumes."
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

// MARK: - World tab

struct CareerWorldTab: View {
    @EnvironmentObject var store: GameStore
    @Binding var path: [Route]

    var body: some View {
        if let c = store.career {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                JobCard(career: c)
                if let e = c.intl.event {
                    SectionLabel(text: e.title)
                    if e.kind == .worldCup {
                        WorldCupGroups(career: c, event: e)
                    }
                    let recent = Array(c.intl.results.reversed().prefix(12))
                    VStack(spacing: DS.Space.sm) {
                        ForEach(recent, id: \.id) { r in
                            Button { path.append(.result(r.id)) } label: { ResultRow(result: r) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                SectionLabel(text: "World rankings")
                AppCard(padding: DS.Space.md) {
                    VStack(spacing: 6) {
                        ForEach(Array(c.rankings.enumerated()), id: \.element.code) { i, n in
                            HStack {
                                Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 22, alignment: .leading)
                                Circle().fill(Color(hex: n.colorHex)).frame(width: 10, height: 10)
                                Text(n.name).font(.subheadline.weight(n.code == c.intl.job ? .heavy : .regular))
                                if !n.fullMember { Text("assoc.").font(.caption2).foregroundStyle(Palette.muted) }
                                Spacer()
                                Text("\(Int(n.points))").font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
                if !c.intl.history.isEmpty {
                    SectionLabel(text: "International history")
                    AppCard(padding: DS.Space.md) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(c.intl.history) { h in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(h.title).font(.subheadline.weight(.semibold))
                                    if let w = h.winner { Text("🏆 \(c.intl.nations.first { $0.code == w }?.name ?? w)").font(.caption) }
                                    if let n = h.userNation, let r = h.userResult {
                                        Text("You (\(n)): \(r)").font(.caption).foregroundStyle(Palette.muted)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct JobCard: View {
    @EnvironmentObject var store: GameStore
    let career: Career
    @State private var confirmResign = false

    var body: some View {
        let c = career
        AppCard(tint: Palette.four) {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                if let job = c.intl.job, let n = c.intl.nations.first(where: { $0.code == job }) {
                    Text("HEAD COACH · \(n.name.uppercased())").font(.display(18)).foregroundStyle(Palette.four)
                    Text("World ranking \(c.rank(of: job)) · board patience \(2 - c.intl.strikes)/2\(c.intl.target.isEmpty ? "" : " · target: \(c.intl.target)")")
                        .font(.caption).foregroundStyle(Palette.muted)
                    NavigationLink { NationalSquadView() } label: {
                        Text("Pick the national squad (\(c.nationSquad(job).count)/15) ▶︎").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button("Resign…") { confirmResign = true }
                        .font(.caption.weight(.bold)).foregroundStyle(Palette.wicket)
                } else {
                    Text("NO NATIONAL JOB").font(.display(18)).foregroundStyle(Palette.four)
                    Text("Reputation \(c.reputation). Offers arrive each off-season; bigger nations need more reputation (manager level and titles).")
                        .font(.caption).foregroundStyle(Palette.muted)
                    ForEach(c.intl.offers, id: \.self) { code in
                        HStack {
                            Text(c.intl.nations.first { $0.code == code }?.name ?? code).font(.subheadline.weight(.semibold))
                            Text("#\(c.rank(of: code))").font(.caption).foregroundStyle(Palette.muted)
                            Spacer()
                            Button("Accept") {
                                store.careerAcceptJob(code)
                                Haptics.success()
                            }
                            .font(.caption.weight(.bold))
                        }
                    }
                }
            }
        }
        .confirmationDialog("Resign from the national job?", isPresented: $confirmResign, titleVisibility: .visible) {
            Button("Resign", role: .destructive) { store.careerResignJob() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct WorldCupGroups: View {
    let career: Career
    let event: IntlEvent

    var body: some View {
        let c = career
        let groups = event.superEight.isEmpty ? event.groups : event.superEight
        let stage: Stage = event.superEight.isEmpty ? .group : .superEight
        AppCard(padding: DS.Space.md) {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                ForEach(Array(groups.enumerated()), id: \.offset) { gi, g in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stage == .group ? "GROUP \(["A", "B", "C", "D"][gi % 4])" : "SUPER 8 · GROUP \(gi + 1)")
                            .font(.display(12, weight: .heavy)).foregroundStyle(Palette.muted)
                        let table = SeasonEngine.table(teamIds: g.map { c.nationTeamId($0) }, results: c.intl.results, stage: stage)
                        ForEach(Array(table.enumerated()), id: \.element.teamId) { i, row in
                            HStack {
                                Text(c.nationCode(teamId: row.teamId) ?? "").font(.subheadline.weight(i < 2 ? .bold : .regular))
                                Spacer()
                                Text("\(row.won)-\(row.lost) · \(row.points) pts").font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct NationalSquadView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var loaded = false

    var body: some View {
        let c = store.career
        let job = c?.intl.job ?? ""
        let pool = c?.nationPlayers(job) ?? []
        List {
            Section {
                Text("\(selected.count)/15 selected").font(.headline)
                if selected.count < 11 {
                    Text("Pick at least 11, or the best 15 are used.").font(.caption).foregroundStyle(.orange)
                }
            } footer: {
                Text("The best XI is chosen from your 15 for each match.")
            }
            .listRowBackground(Palette.surface)
            Section("Eligible players") {
                ForEach(pool) { p in
                    Button {
                        if selected.contains(p.id) { selected.remove(p.id) } else if selected.count < 15 { selected.insert(p.id) }
                        Haptics.tap()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selected.contains(p.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected.contains(p.id) ? Palette.accent : Palette.muted)
                            CareerPlayerRow(player: p, year: c?.year ?? 0)
                            Text("\(c?.intl.caps[p.id] ?? 0) caps").font(.caption2).foregroundStyle(Palette.muted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(Palette.surface)
        }
        .darkList()
        .navigationTitle("National squad")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    store.careerSetNationalSquad(Array(selected))
                    Haptics.success()
                    dismiss()
                }
            }
        }
        .onAppear {
            if !loaded, let car = store.career, let j = car.intl.job {
                selected = Set(car.nationSquad(j))
                loaded = true
            }
        }
    }
}
