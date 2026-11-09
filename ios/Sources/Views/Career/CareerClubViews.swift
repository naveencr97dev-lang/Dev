import SwiftUI

// MARK: - Manager

struct ManagerCard: View {
    let career: Career

    var body: some View {
        let m = career.manager
        let prev = m.level > 1 ? ManagerProfile.xpFor(level: m.level - 1) : 0
        let next = ManagerProfile.xpFor(level: m.level)
        let progress = Double(max(0, m.xp - prev)) / Double(max(1, next - prev))
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("MANAGER \(career.managerName.uppercased())").font(.display(16, weight: .heavy))
                    Spacer()
                    Text("\(career.gold)").font(.score(16))
                }
                HStack(spacing: 10) {
                    Text("LV \(m.level)").font(.display(26)).foregroundStyle(Palette.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
                                Capsule().fill(Palette.accent).frame(width: geo.size.width * CGFloat(min(1, progress)))
                            }
                        }
                        .frame(height: 6)
                        Text("\(m.xp) / \(next) XP · \(m.points) trait point\(m.points == 1 ? "" : "s") · \(m.perks.count) perks")
                            .font(.caption2).foregroundStyle(Palette.muted)
                    }
                }
            }
        }
    }
}

struct ManagerView: View {
    @EnvironmentObject var store: GameStore
    @State private var message: String? = nil

    var body: some View {
        let c = store.career
        List {
            Section {
                if let c {
                    Text("Level \(c.manager.level) · \(c.manager.points) point\(c.manager.points == 1 ? "" : "s") to spend")
                        .font(.headline)
                }
                if let message {
                    Text(message).font(.caption.weight(.bold)).foregroundStyle(.orange)
                }
            } footer: {
                Text("Earn XP by winning matches, reaching the playoffs, titles, finishing a season in profit and upgrading facilities. Each level gives a point. Tier 2 perks cost 2 and need 2 perks from the same tree; tier 3 cost 3 and need 4. Perks apply to this career only.")
            }
            .listRowBackground(GameRowBackground())

            ForEach(PerkTree.allCases, id: \.self) { tree in
                Section(tree.label) {
                    ForEach(Perk.allCases.filter { $0.tree == tree }) { perk in
                        PerkRow(perk: perk, owned: c?.manager.has(perk) ?? false, block: c?.canLearn(perk)) {
                            message = store.careerLearn(perk)
                            if message == nil { Haptics.success() }
                        }
                    }
                }
                .listRowBackground(GameRowBackground())
            }
        }
        .darkList()
        .navigationTitle("Manager traits")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PerkRow: View {
    let perk: Perk
    let owned: Bool
    let block: String?
    let learn: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(String(repeating: "●", count: perk.tier)).font(.caption2).foregroundStyle(Palette.accent).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(perk.label).font(.subheadline.weight(.semibold)).foregroundStyle(owned ? Palette.accent : .white)
                Text(perk.blurb).font(.caption).foregroundStyle(Palette.muted)
            }
            Spacer()
            if owned {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.accent)
            } else {
                Button("Learn (\(perk.cost))", action: learn)
                    .font(.caption.weight(.bold))
                    .buttonStyle(.borderless)
                    .disabled(block != nil)
            }
        }
    }
}

// MARK: - Facilities

struct FacilitiesView: View {
    @EnvironmentObject var store: GameStore
    @State private var message: String? = nil

    var body: some View {
        let c = store.career
        List {
            Section {
                if let c {
                    if let b = c.facilities.building, let k = FacilityKind(rawValue: b) {
                        Text("Building \(k.label) level \(c.facility(k) + 1): \(c.facilities.weeksLeft) weeks left")
                            .font(.subheadline.weight(.semibold))
                        Button("Finish now (\(c.goldCost(.finishBuild)) gold)") {
                            message = store.careerSpendGold(.finishBuild)
                        }
                    } else {
                        Text("No building work. Pick an upgrade below.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("Bank \(Money.format(c.bank(c.userClubId))) · upkeep \(Money.format(c.facilityMaintenance)) a season")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                if let message {
                    Text(message).font(.caption.weight(.bold)).foregroundStyle(.orange)
                }
            } footer: {
                Text("One project at a time. Building time is counted in your matches (4 weeks pass in each off-season). Each level adds yearly upkeep.")
            }
            .listRowBackground(GameRowBackground())

            Section("Facilities") {
                ForEach(FacilityKind.allCases) { k in
                    if let c {
                        FacilityRow(career: c, kind: k) {
                            message = store.careerUpgrade(k)
                            if message == nil { Haptics.success() }
                        }
                    }
                }
            }
            .listRowBackground(GameRowBackground())
        }
        .darkList()
        .navigationTitle("Facilities")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FacilityRow: View {
    let career: Career
    let kind: FacilityKind
    let upgrade: () -> Void

    var body: some View {
        let level = career.facility(kind)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(kind.icon) \(kind.label)").font(.subheadline.weight(.semibold))
                Spacer()
                Text("LV \(level)").font(.display(18)).foregroundStyle(Palette.accent)
            }
            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2).fill(i < level ? Palette.accent : Color.white.opacity(0.1)).frame(height: 5)
                }
            }
            Text(kind.effect).font(.caption).foregroundStyle(Palette.muted)
            if level < 10 {
                Button("Upgrade to \(level + 1) · \(Money.format(career.upgradeCost(kind))) · \(career.upgradeWeeks(kind)) weeks", action: upgrade)
                    .font(.caption.weight(.bold))
                    .buttonStyle(.borderless)
                    .disabled(career.facilities.building != nil)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Store

struct StoreView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        let gold = store.career?.gold ?? 0
        List {
            Section {
                Text("\(gold) gold").font(.display(30)).foregroundStyle(Palette.accent)
                Text("Earn gold from manager levels, titles and every match. Spend it to finish builds, boost training, scout instantly or freshen a player's form.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            .listRowBackground(GameRowBackground())

            Section {
                ForEach([100, 1_000, 10_000, 100_000], id: \.self) { amount in
                    HStack {
                        Text("\(amount.formatted()) gold → \(Money.format(amount))").font(.subheadline)
                        Spacer()
                        Button("Exchange") {
                            if store.careerExchangeGold(amount) == nil { Haptics.success() } else { Haptics.warning() }
                        }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.borderless)
                        .disabled(gold < amount)
                    }
                }
            } header: {
                Text("Gold → club bank")
            } footer: {
                Text("1 gold = ₹1 lakh. Handy for testing transfers with the Tester Pack.")
            }
            .listRowBackground(GameRowBackground())

            Section {
                ForEach(StorePack.allCases) { pack in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.title).font(.subheadline.weight(.bold))
                                .foregroundStyle(pack == .tester ? Palette.accent : .white)
                            Text("+\(pack.gold) gold").font(.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Button(pack.priceLabel) {
                            store.careerBuy(pack)
                            Haptics.success()
                        }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.borderless)
                    }
                }
            } header: {
                Text("Gold packs")
            } footer: {
                Text(StoreConfig.testerStore
                     ? "TEST MODE: no real purchases. Every pack is free, and the Tester Pack can be bought any number of times. Real in-app purchases need an App Store or TestFlight build."
                     : "Purchases are charged to your Apple account.")
            }
            .listRowBackground(GameRowBackground())
        }
        .darkList()
        .navigationTitle("Store")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Gold shortcuts on a player profile.
struct GoldActions: View {
    @EnvironmentObject var store: GameStore
    let playerId: String
    @State private var message: String? = nil

    var body: some View {
        if let c = store.career, let p = c.players[playerId] {
            VStack(alignment: .leading, spacing: 6) {
                if p.clubId == c.userClubId {
                    Button("Fresh legs: form to +3 (\(c.goldCost(.freshLegs)) gold)") {
                        message = store.careerSpendGold(.freshLegs, playerId: playerId) ?? "Feeling fresh!"
                    }
                } else if c.knowledge(of: playerId) < 100 {
                    Button("Instant scout report (\(c.goldCost(.scoutReport)) gold)") {
                        message = store.careerSpendGold(.scoutReport, playerId: playerId) ?? "Fully scouted: potential \(p.potential)."
                    }
                }
                if let message { Text(message).font(.caption).foregroundStyle(Palette.muted) }
            }
            .font(.subheadline.weight(.semibold))
        }
    }
}

/// Home: this season's board objectives and the latest Player of the Month (Career › Club › Board).
struct BoardObjectivesCard: View {
    let career: Career

    var body: some View {
        let c = career
        if !c.board.objectives.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionLabel(text: "Board objectives · confidence \(c.board.confidence)%")
                VStack(spacing: 0) {
                    ForEach(Array(c.board.objectives.enumerated()), id: \.element.id) { i, o in
                        if i > 0 { Hairline(inset: 16) }
                        ObjectiveRow(career: c, objective: o)
                    }
                    if let a = c.board.awards.last, a.year == c.year {
                        Hairline(inset: 16)
                        InfoRow(label: "Player of the Month · \(a.monthName)",
                                value: "\(a.playerName) (\(c.club(a.playerClub)?.short ?? ""))", chevron: false)
                    }
                }
                .gameFrame()
            }
        }
    }
}

struct ObjectiveRow: View {
    let career: Career
    let objective: Objective

    var body: some View {
        let p = career.progress(objective)
        let judged = objective.met
        let ok = judged ?? p.ok
        let value: String = {
            switch objective.kind {
            case .finish: return Career.ordinal(p.value)
            case .homeWins, .youth: return "\(p.value)/\(objective.target)"
            }
        }()
        HStack(spacing: 12) {
            Image(systemName: judged == true ? "checkmark.circle.fill" : (judged == false ? "xmark.circle" : "scope"))
                .font(.system(size: 17 * TextScale.factor, weight: .semibold))
                .foregroundStyle(judged == nil ? Palette.muted : (ok ? Palette.accent : Palette.wicket))
            VStack(alignment: .leading, spacing: 2) {
                Text(objective.title).font(.display(16, weight: .regular)).foregroundStyle(.white)
                Text("+\(objective.xp) XP · +\(objective.gold) gold").font(.display(12, weight: .regular)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 8)
            Text(value).font(.score(16, weight: .regular)).foregroundStyle(ok ? Palette.accent : Palette.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}
