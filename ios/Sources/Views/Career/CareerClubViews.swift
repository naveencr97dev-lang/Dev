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
        let trees = PerkTree.allCases
        PaneScreen(title: "Manager traits") {
            if let c {
                SummaryLine(cells: [
                    SummaryCell(value: "\(c.manager.level)", label: "level", color: Palette.accent),
                    SummaryCell(value: "\(c.manager.points)", label: "points", color: c.manager.points > 0 ? Palette.accent : .white),
                    SummaryCell(value: "\(c.manager.perks.count)", label: "perks"),
                ])
            }
            TableNote(text: message ?? "Win matches, titles and a profit to level up. Each level is a point. Tier 2 needs 2 perks in its tree, tier 3 needs 4.",
                      warning: message != nil)
            ForEach(trees.prefix(1), id: \.self) { tree in perks(tree, c) }
        } right: {
            ForEach(trees.dropFirst(), id: \.self) { tree in perks(tree, c) }
        }
    }

    private func perks(_ tree: PerkTree, _ c: Career?) -> some View {
        PaneBox(title: tree.label) {
            ForEach(Array(Perk.allCases.filter { $0.tree == tree }.enumerated()), id: \.element.id) { i, perk in
                if i > 0 { Hairline() }
                PerkRow(perk: perk, owned: c?.manager.has(perk) ?? false, block: c?.canLearn(perk)) {
                    message = store.careerLearn(perk)
                    if message == nil { Haptics.success() }
                }
            }
        }
    }
}

struct PerkRow: View {
    let perk: Perk
    let owned: Bool
    let block: String?
    let learn: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(String(repeating: "●", count: perk.tier)).font(.system(size: 9 * TextScale.factor)).foregroundStyle(Palette.accent)
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(perk.label).font(.system(size: 13 * TextScale.factor, weight: .semibold)).foregroundStyle(owned ? Palette.accent : .white)
                    .lineLimit(1)
                Text(perk.blurb).font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if owned {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.accent).frame(width: 100, alignment: .trailing)
            } else {
                ActionChip(icon: "plus", title: "Learn \(perk.cost)", disabled: block != nil, action: learn)
                    .frame(width: 100, alignment: .trailing)
            }
        }
    }
}

// MARK: - Facilities

struct FacilitiesView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.verticalSizeClass) private var vSize
    @State private var message: String? = nil

    var body: some View {
        let c = store.career
        TableScreen(title: "Facilities") {
            if let c {
                SummaryLine(cells: [
                    SummaryCell(value: Money.format(c.bank(c.userClubId)), label: "bank"),
                    SummaryCell(value: Money.format(c.facilityMaintenance), label: "upkeep / season"),
                    SummaryCell(value: c.facilities.building == nil ? "None" : "\(c.facilities.weeksLeft) wk", label: "building",
                                color: c.facilities.building == nil ? Palette.muted : Palette.accent),
                ])
                HStack(spacing: 6) {
                    if let b = c.facilities.building, let k = FacilityKind(rawValue: b) {
                        TableNote(text: message ?? "Building \(k.label) level \(c.facility(k) + 1): \(c.facilities.weeksLeft) weeks left.", warning: message != nil)
                        Spacer(minLength: 4)
                        ActionChip(icon: "bolt.fill", title: "Finish now · \(c.goldCost(.finishBuild)) gold") {
                            message = store.careerSpendGold(.finishBuild)
                        }
                    } else {
                        TableNote(text: message ?? "One project at a time. Building time counts in your matches; each level adds upkeep.",
                                  warning: message != nil)
                    }
                }
                TableHead {
                    if vSize == .compact {
                        Text("FACILITY").frame(width: 150, alignment: .leading)
                        Text("LEVEL").frame(width: 110, alignment: .leading)
                        Text("EFFECT").frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("FACILITY").frame(maxWidth: .infinity, alignment: .leading)
                        Text("LV").frame(width: TCol.stat, alignment: .trailing)
                    }
                    Text("UPGRADE").frame(width: vSize == .compact ? 190 : 150, alignment: .trailing)
                }
            }
        } rows: {
            if let c {
                ForEach(FacilityKind.allCases) { k in
                    FacilityRow(career: c, kind: k) {
                        message = store.careerUpgrade(k)
                        if message == nil { Haptics.success() }
                    }
                }
            }
        }
    }
}

struct FacilityRow: View {
    let career: Career
    let kind: FacilityKind
    let upgrade: () -> Void
    @Environment(\.verticalSizeClass) private var vSize

    var body: some View {
        let level = career.facility(kind)
        let wide = vSize == .compact
        HStack(spacing: 8) {
            if wide {
                Text("\(kind.icon) \(kind.label)").font(.system(size: 13 * TextScale.factor, weight: .semibold)).lineLimit(1)
                    .minimumScaleFactor(0.8).frame(width: 150, alignment: .leading)
                pips(level)
                Text(kind.effect).font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(kind.icon) \(kind.label)").font(.system(size: 13 * TextScale.factor, weight: .semibold)).lineLimit(1)
                    Text(kind.effect).font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                TNum(text: "\(level)", width: TCol.stat, color: Palette.accent)
            }
            Group {
                if level < 10 {
                    ActionChip(icon: "arrow.up", title: "\(Money.format(career.upgradeCost(kind))) · \(career.upgradeWeeks(kind)) wk",
                               disabled: career.facilities.building != nil, action: upgrade)
                } else {
                    Text("Max").font(.system(size: 12 * TextScale.factor, weight: .bold)).foregroundStyle(Palette.muted)
                }
            }
            .frame(width: wide ? 190 : 150, alignment: .trailing)
        }
        .tableRow()
    }

    /// Ten level pips and the number (landscape).
    private func pips(_ level: Int) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1).fill(i < level ? Palette.accent : Color.white.opacity(0.1)).frame(width: 5, height: 10)
                }
            }
            Text("\(level)").font(.score(13)).foregroundStyle(Palette.accent)
        }
        .frame(width: 110, alignment: .leading)
    }
}

// MARK: - Store

struct StoreView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        let gold = store.career?.gold ?? 0
        PaneScreen(title: "Store") {
            SummaryLine(cells: [
                SummaryCell(value: "\(gold)", label: "gold", color: CareerPalette.gold),
                SummaryCell(value: Money.format(store.career.map { $0.bank($0.userClubId) } ?? 0), label: "bank"),
            ])
            PaneBox(title: "Gold → club bank", note: "1 gold = ₹1 lakh. Gold also finishes builds, boosts training, scouts instantly and freshens form.") {
                ForEach(Array([100, 1_000, 10_000, 100_000].enumerated()), id: \.offset) { i, amount in
                    if i > 0 { Hairline() }
                    HStack {
                        Text("\(amount.formatted()) gold → \(Money.format(amount))").font(.system(size: 13 * TextScale.factor))
                        Spacer()
                        ActionChip(icon: "arrow.right", title: "Exchange", disabled: gold < amount) {
                            if store.careerExchangeGold(amount) == nil { Haptics.success() } else { Haptics.warning() }
                        }
                    }
                }
            }
        } right: {
            PaneBox(title: "Gold packs",
                    note: StoreConfig.testerStore
                        ? "TEST MODE: no real purchases. Every pack is free; the Tester Pack can be bought any number of times."
                        : "Purchases are charged to your Apple account.") {
                ForEach(Array(StorePack.allCases.enumerated()), id: \.element.id) { i, pack in
                    if i > 0 { Hairline() }
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pack.title).font(.system(size: 13 * TextScale.factor, weight: .bold))
                                .foregroundStyle(pack == .tester ? Palette.accent : .white)
                            Text("+\(pack.gold) gold").font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        ActionChip(icon: "cart", title: pack.priceLabel, primary: pack == .tester) {
                            store.careerBuy(pack)
                            Haptics.success()
                        }
                    }
                }
            }
        }
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
                        // Device tour: "Player of the Month · J… Bhuvneshwar Kumar (…" was cut off.
                        InfoRow(label: "Player of the month",
                                value: "\(a.playerName.split(separator: " ").last.map(String.init) ?? a.playerName) · \(c.club(a.playerClub)?.short ?? "")",
                                chevron: false)
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
            case .homeWins, .youth, .awayWins, .invest: return "\(p.value)/\(objective.target)"
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

/// Home: the assistant manager speaks up during a losing run (Career › Club › Assistant).
struct AssistantCard: View {
    let career: Career

    var body: some View {
        if let report = career.assistantReport() {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionLabel(text: "Assistant manager")
                VStack(alignment: .leading, spacing: 6) {
                    Text(report.diagnosis).font(.display(15, weight: .regular)).foregroundStyle(.white)
                    ForEach(report.advice, id: \.self) { line in
                        Label(line, systemImage: "arrow.turn.down.right")
                            .font(.display(13, weight: .regular)).foregroundStyle(Palette.muted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .gameFrame()
            }
        }
    }
}
