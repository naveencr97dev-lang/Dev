import SwiftUI

/// Career › Squad › Tactics: game plans (one tap sets all six phase settings), the phase settings
/// themselves, the toss call, the captain and each batter's role. Used for your club and your
/// national side.
struct TacticsView: View {
    @EnvironmentObject var store: GameStore
    @State private var t = Tactics()
    @State private var loaded = false

    var body: some View {
        List {
            if let c = store.career {
                plans(c)
                phases
                toss
                captain(c)
                roles(c)
            }
        }
        .darkList()
        .navigationTitle("Tactics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !loaded, let c = store.career {
                t = c.tactics
                loaded = true
            }
        }
        .onChange(of: t) { v in
            if loaded { store.careerSetTactics(v) }
        }
    }

    // MARK: Game plan

    @ViewBuilder private func plans(_ c: Career) -> some View {
        let pitch = c.nextUserFixture?.pitch
        let suggested = pitch.map { GamePlan.suggested(for: $0) }
        Section {
            ForEach(GamePlan.allCases) { plan in
                Button { t = plan.apply(to: t); Haptics.tap() } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(plan.label).font(.display(16, weight: .semibold)).foregroundStyle(.white)
                            if plan == suggested {
                                Text("SUITS \(pitch?.label.uppercased() ?? "")")
                                    .font(.display(10, weight: .heavy)).foregroundStyle(Palette.accent)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().stroke(Palette.accent, lineWidth: 1))
                            }
                            Spacer()
                            if t.matchingPlan == plan {
                                Image(systemName: "checkmark").font(.system(size: 14 * TextScale.factor, weight: .bold)).foregroundStyle(Palette.accent)
                            }
                        }
                        Text(plan.blurb).font(.caption).foregroundStyle(Palette.muted)
                        AggressionBar(value: plan.aggression)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Game plan")
        } footer: {
            Text(t.matchingPlan == nil ? "Custom: your own phase settings below." : "Sets batting and field for all three phases. Fine-tune them below.")
        }
        .listRowBackground(GameRowBackground())
    }

    // MARK: Phases

    @ViewBuilder private var phases: some View {
        ForEach(0..<3, id: \.self) { i in
            Section(Tactics.phases[i]) {
                Picker("Field", selection: Binding(get: { t.field[i] }, set: { t.field[i] = $0 })) {
                    ForEach(FieldSetting.allCases, id: \.self) { f in Text(f.label).tag(f) }
                }
                .pickerStyle(.segmented)
                Text(t.field[i].blurb).font(.caption).foregroundStyle(Palette.muted)
                Picker("Batting", selection: Binding(get: { t.intent[i] }, set: { t.intent[i] = $0 })) {
                    ForEach(BatIntent.allCases, id: \.self) { b in Text(b.label).tag(b) }
                }
                .pickerStyle(.segmented)
                Text(t.intent[i].blurb).font(.caption).foregroundStyle(Palette.muted)
            }
            .listRowBackground(GameRowBackground())
        }
    }

    // MARK: Toss, captain, roles

    @ViewBuilder private var toss: some View {
        Section {
            Picker("Toss", selection: Binding(get: { t.toss?.rawValue ?? "auto" }, set: { t.toss = TossCall(rawValue: $0) })) {
                Text("Captain's call").tag("auto")
                ForEach(TossCall.allCases, id: \.self) { call in Text(call.label).tag(call.rawValue) }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("If you win the toss")
        } footer: {
            Text("Captain's call reads the pitch: seamers and flat tracks usually mean bowling first.")
        }
        .listRowBackground(GameRowBackground())
    }

    @ViewBuilder private func captain(_ c: Career) -> some View {
        let xi = c.userClub.xi.compactMap { c.players[$0] }
        Section {
            Picker("Captain", selection: Binding(get: { t.captain ?? "" }, set: { t.captain = $0.isEmpty ? nil : $0 })) {
                Text("None").tag("")
                ForEach(xi) { p in Text(p.name).tag(p.id) }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Captain")
        } footer: {
            Text("The captain leads by example: +1 batting and bowling while he plays.")
        }
        .listRowBackground(GameRowBackground())
    }

    @ViewBuilder private func roles(_ c: Career) -> some View {
        let xi = c.userClub.xi.compactMap { c.players[$0] }
        Section {
            ForEach(Array(xi.prefix(8).enumerated()), id: \.element.id) { i, p in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(i + 1). \(p.name)").font(.display(15, weight: .semibold))
                    Picker(p.name, selection: Binding(get: { t.roles?[p.id] ?? .normal }, set: { r in
                        var all = t.roles ?? [:]
                        all[p.id] = r == .normal ? nil : r
                        t.roles = all.isEmpty ? nil : all
                    })) {
                        ForEach(BatRole.allCases, id: \.self) { r in Text(r.label).tag(r) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Batting roles")
        } footer: {
            Text("\(BatRole.anchor.label): \(BatRole.anchor.blurb.lowercased()). \(BatRole.hitter.label): \(BatRole.hitter.blurb.lowercased()).")
        }
        .listRowBackground(GameRowBackground())
    }
}

/// Defence ↔ Attack bar for a game plan.
struct AggressionBar: View {
    let value: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("Defence").font(.display(10, weight: .semibold)).foregroundStyle(Palette.muted)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.stroke)
                    Capsule().fill(Palette.accent).frame(width: max(4, g.size.width * CGFloat(value) / 100))
                }
            }
            .frame(height: 5)
            Text("Attack").font(.display(10, weight: .semibold)).foregroundStyle(Palette.muted)
        }
    }
}
