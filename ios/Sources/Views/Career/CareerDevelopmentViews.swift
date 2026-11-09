import SwiftUI

// MARK: - Training

struct TrainingView: View {
    @EnvironmentObject var store: GameStore
    @State private var plan = TrainingPlan()
    @State private var loaded = false

    var body: some View {
        let c = store.career
        let squad = c.map { car in car.squad(car.userClubId).sorted { $0.age(in: car.year) < $1.age(in: car.year) } } ?? []
        List {
            Section {
                ForEach(0..<plan.drills.count, id: \.self) { i in
                    Picker("Slot \(i + 1)", selection: drillBinding(i)) {
                        ForEach(Drill.allCases) { d in
                            Text("\(d.icon) \(d.label)").tag(d)
                        }
                    }
                    .pickerStyle(.menu)
                }
                if plan.drills.count < (c?.trainingSlots ?? 3) {
                    Button("Add a drill slot") { plan.drills.append(.fitness) }
                }
                Picker("Intensity", selection: $plan.intensity) {
                    ForEach(Intensity.allCases, id: \.self) { i in Text(i.label).tag(i) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Weekly drills · \(c?.trainingSlots ?? 3) slots")
            } footer: {
                Text("After each of your matches, every player has a chance to gain a point in the drilled skills. Under-22s learn fastest, over-30s slowest, and nobody grows past their potential. Hard training develops faster but costs form; light sessions and fitness drills lift form. The Training Ground adds slots (M4).")
            }
            .listRowBackground(Palette.surface)

            Section {
                ForEach(squad) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(.subheadline.weight(.semibold))
                            Text("Age \(p.age(in: c?.year ?? 0)) · POT \(p.potential) · now \(max(p.bat, p.bowl))")
                                .font(.caption2).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Menu {
                            Button("No focus") { plan.focus[p.id] = nil }
                            ForEach(Attributes.trainable, id: \.name) { t in
                                Button(t.label) { plan.focus[p.id] = t.name }
                            }
                        } label: {
                            Text(focusLabel(p.id)).font(.caption.weight(.bold))
                        }
                    }
                }
            } header: {
                Text("Individual focus")
            } footer: {
                Text("A focus skill grows about 2.5× faster than a drill.")
            }
            .listRowBackground(Palette.surface)
        }
        .darkList()
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !loaded, let t = store.career?.training {
                plan = t
                loaded = true
            }
        }
        .onChange(of: plan) { p in
            if loaded { store.careerSetTraining(p) }
        }
    }

    private func drillBinding(_ i: Int) -> Binding<Drill> {
        Binding(get: { i < plan.drills.count ? plan.drills[i] : .fitness },
                set: { if i < plan.drills.count { plan.drills[i] = $0 } })
    }

    private func focusLabel(_ id: String) -> String {
        guard let name = plan.focus[id] else { return "Focus ▾" }
        return (Attributes.trainable.first { $0.name == name }?.label ?? name) + " ▾"
    }
}

// MARK: - Academy

struct AcademyView: View {
    @EnvironmentObject var store: GameStore
    @State private var message: String? = nil

    var body: some View {
        let c = store.career
        let kids = c?.academyPlayers.sorted { $0.potential > $1.potential } ?? []
        List {
            Section {
                if kids.isEmpty {
                    Text("No academy players right now. A new intake arrives every off-season.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(kids) { p in
                    VStack(alignment: .leading, spacing: 6) {
                        NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                            CareerPlayerRow(player: p, year: c?.year ?? 0)
                        }
                        HStack {
                            Text("Potential \(p.potential)").font(.caption.weight(.bold)).foregroundStyle(Palette.four)
                            Spacer()
                            Button("Promote") {
                                message = store.careerPromote(p.id) ?? "\(p.name) joins the squad on \(Money.format(c?.tuning.minWage ?? 20))."
                            }
                            .font(.caption.weight(.bold))
                            .buttonStyle(.borderless)
                            Button("Release") { store.careerReleaseAcademy(p.id) }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Palette.wicket)
                                .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text("Academy · \(kids.count)/\(c?.tuning.academyMax ?? 8)")
            } footer: {
                Text("Academy kids train with your plan (a little faster) and don't count against your squad or the salary cap until promoted on a minimum contract.")
            }
            .listRowBackground(Palette.surface)
            if let message {
                Section { Text(message).font(.footnote) }
                    .listRowBackground(Palette.surface)
            }
        }
        .darkList()
        .navigationTitle("Academy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Scouting

struct ScoutingView: View {
    @EnvironmentObject var store: GameStore
    @State private var message: String? = nil

    var body: some View {
        let c = store.career
        let s = c?.scouting ?? ScoutingState()
        List {
            Section {
                ForEach(s.scouts) { scout in
                    ScoutRow(scout: scout, regions: c?.scoutRegions ?? ["ANY"])
                }
            } header: {
                Text("Your scouts · \(s.scouts.count)/\(c?.scoutCap ?? 2)")
            } footer: {
                Text("After each of your matches, every scout studies players that fit his brief. More stars = more players and more detail. Scouted players show a narrower potential range; you know your own players fully.")
            }
            .listRowBackground(Palette.surface)

            Section("Available to hire") {
                ForEach(s.candidates) { cand in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cand.name).font(.subheadline.weight(.semibold))
                            Text(String(repeating: "★", count: cand.stars) + String(repeating: "☆", count: 5 - cand.stars))
                                .font(.caption).foregroundStyle(Palette.accent)
                        }
                        Spacer()
                        Button("Hire \(Money.format(cand.wage))/yr") {
                            message = store.careerHireScout(cand.id) ?? "\(cand.name) hired."
                        }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.borderless)
                    }
                }
            }
            .listRowBackground(Palette.surface)

            if let message {
                Section { Text(message).font(.footnote) }
                    .listRowBackground(Palette.surface)
            }

            Section("Latest reports") {
                if s.reports.isEmpty {
                    Text("No reports yet.").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(s.reports) { r in
                    if let car = c, let p = car.players[r.playerId] {
                        NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(p.name) · \(p.role.short) · \(p.country) · age \(p.age(in: car.year))")
                                    .font(.subheadline.weight(.semibold))
                                Text("OVR \(p.rating) · potential \(car.potentialLabel(p)) · \(r.scoutName)")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
            }
            .listRowBackground(Palette.surface)
        }
        .darkList()
        .navigationTitle("Scouting")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ScoutRow: View {
    @EnvironmentObject var store: GameStore
    let scout: Scout
    let regions: [String]

    private static let roles: [Role?] = [nil, .BAT, .WK, .AR, .BOWL]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(scout.name).font(.subheadline.weight(.semibold))
                Text(String(repeating: "★", count: scout.stars)).font(.caption).foregroundStyle(Palette.accent)
                Spacer()
                Button("Fire") { store.careerFireScout(scout.id) }
                    .font(.caption.weight(.bold)).foregroundStyle(Palette.wicket)
                    .buttonStyle(.borderless)
            }
            HStack {
                Menu {
                    ForEach(regions, id: \.self) { r in
                        Button(r == "ANY" ? "Anywhere" : r) {
                            store.careerAssignScout(scout.id, region: r, role: scout.role, youthOnly: scout.youthOnly)
                        }
                    }
                } label: {
                    Text("📍 \(scout.region == "ANY" ? "Anywhere" : scout.region)").font(.caption.weight(.bold))
                }
                Menu {
                    ForEach(0..<Self.roles.count, id: \.self) { i in
                        Button(Self.roles[i]?.label ?? "Any role") {
                            store.careerAssignScout(scout.id, region: scout.region, role: Self.roles[i], youthOnly: scout.youthOnly)
                        }
                    }
                } label: {
                    Text("🎯 \(scout.role?.short ?? "Any role")").font(.caption.weight(.bold))
                }
                Spacer()
                Button(scout.youthOnly ? "U21 only ✓" : "All ages") {
                    store.careerAssignScout(scout.id, region: scout.region, role: scout.role, youthOnly: !scout.youthOnly)
                }
                .font(.caption.weight(.bold))
                .buttonStyle(.borderless)
            }
        }
    }
}
