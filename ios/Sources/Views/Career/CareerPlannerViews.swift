import SwiftUI

/// Career › Squad › Squad planner: one row per job in the XI (starters, then depth), auto-fill, and
/// "Use as my XI".
struct SquadPlannerView: View {
    @EnvironmentObject var store: GameStore
    @State private var message: String? = nil

    var body: some View {
        let c = store.career
        TableScreen(title: "Squad planner") {
            if let c {
                HStack(spacing: 6) {
                    TableNote(text: message ?? "Plan who does each job and who steps in behind them. Your XI changes only when you use the plan.")
                    Spacer(minLength: 4)
                    ActionChip(icon: "wand.and.stars", title: c.plan == nil ? "Auto-fill" : "Auto-fill again") {
                        store.careerAutoPlan()
                        message = "Planned from your best players."
                        Haptics.success()
                    }
                    ActionChip(icon: "checkmark", title: "Use as my XI", primary: true, disabled: c.plan == nil) {
                        let issues = store.careerApplyPlan()
                        message = issues.isEmpty ? "Your XI now follows the plan. The assistant stops picking the team." : issues.joined(separator: " ")
                        if issues.isEmpty { Haptics.success() } else { Haptics.warning() }
                    }
                }
                TableHead {
                    Text("JOB").frame(width: 120, alignment: .leading)
                    Text("IN THE XI").frame(maxWidth: .infinity, alignment: .leading)
                    Text("BACKUPS").frame(maxWidth: .infinity, alignment: .leading)
                    Text("AVG").frame(width: TCol.stat, alignment: .trailing)
                    Text("").frame(width: 14)
                }
            }
        } rows: {
            if let c {
                ForEach(PlanSlot.allCases) { slot in
                    NavigationLink { PlanSlotView(slot: slot) } label: { PlanSlotRow(career: c, slot: slot) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

/// One job on the planner, on one line: starters, backups, the job's average and any warning.
struct PlanSlotRow: View {
    let career: Career
    let slot: PlanSlot

    var body: some View {
        let c = career
        let list = c.planned(slot)
        let summary = c.planSummary(slot)
        let starters = list.prefix(slot.starters).map(\.name).joined(separator: ", ")
        let backups = list.dropFirst(slot.starters).prefix(SquadPlan.depth).map(\.name).joined(separator: ", ")
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(slot.label).font(.system(size: 13 * TextScale.factor, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                if let warning = summary.successionWarning {
                    Text(warning).font(.system(size: 10 * TextScale.factor, weight: .semibold)).foregroundStyle(.orange).lineLimit(1)
                }
            }
            .frame(width: 120, alignment: .leading)
            Text(starters.isEmpty ? "Nobody planned" : starters).font(.system(size: 12 * TextScale.factor, weight: .semibold))
                .foregroundStyle(starters.isEmpty ? Palette.muted : .white).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(backups.isEmpty ? "–" : backups).font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            TNum(text: list.isEmpty ? "–" : "\(summary.rating)", width: TCol.stat, color: strengthColor(summary.rating))
            Image(systemName: "chevron.right").font(.system(size: 11 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.stroke)
                .frame(width: 14)
        }
        .tableRow()
    }
}

/// Editing one job: order the depth chart, add or remove players, and the scout's suggested target.
struct PlanSlotView: View {
    @EnvironmentObject var store: GameStore
    let slot: PlanSlot

    var body: some View {
        let c = store.career
        let list = c?.planned(slot) ?? []
        let summary = c?.planSummary(slot)
        let year = c?.year ?? 0
        PaneScreen(title: slot.label) {
            SummaryLine(cells: [
                SummaryCell(value: list.isEmpty ? "–" : "\(summary?.rating ?? 0)", label: "rating", color: strengthColor(summary?.rating ?? 0)),
                SummaryCell(value: list.isEmpty ? "–" : String(format: "%.1f", summary?.age ?? 0), label: "age"),
                SummaryCell(value: "\(slot.starters)", label: "in the XI"),
                SummaryCell(value: "\(max(0, list.count - slot.starters))", label: "backups"),
            ])
            if let warning = summary?.successionWarning { TableNote(text: warning, warning: true) }
            HStack {
                Text("DEPTH CHART").font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
                Spacer()
                if !list.isEmpty {
                    ActionChip(icon: "trash", title: "Clear this job", destructive: true) { store.careerPlanClear(slot) }
                }
            }
            if list.isEmpty {
                Text("Nobody planned for this job yet.").font(.system(size: 13 * TextScale.factor)).foregroundStyle(Palette.muted).tableRow()
            }
            ForEach(Array(list.enumerated()), id: \.element.id) { i, p in
                HStack(spacing: 8) {
                    Text(i < slot.starters ? "XI" : "\(i - slot.starters + 1)")
                        .font(.system(size: 11 * TextScale.factor, weight: .heavy))
                        .foregroundStyle(i < slot.starters ? Palette.accent : Palette.muted).frame(width: TCol.num)
                    NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                        TName(text: p.name, overseas: p.overseas)
                    }
                    .buttonStyle(.plain)
                    TRole(role: p.role)
                    TNum(text: "\(p.age(in: year))", width: TCol.age, color: Palette.muted)
                    TNum(text: "\(slot.score(p))", width: TCol.stat, color: strengthColor(slot.score(p)))
                    iconButton("chevron.up", disabled: i == 0) { store.careerPlanMove(slot, p.id, by: -1) }
                    iconButton("chevron.down", disabled: i == list.count - 1) { store.careerPlanMove(slot, p.id, by: 1) }
                    iconButton("trash", disabled: false) { store.careerPlanRemove(slot, p.id) }
                }
                .tableRow(selected: i < slot.starters)
            }
        } right: {
            if let c {
                let candidates = c.planCandidates(slot)
                Text("SCOUT'S TARGET").font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
                if let t = c.planTarget(slot) {
                    NavigationLink { CareerPlayerView(playerId: t.id) } label: {
                        HStack(spacing: 8) {
                            TName(text: t.name, overseas: t.overseas, pitchFit: c.suitsUserPitch(t))
                            Text("\(t.clubId.flatMap { c.club($0)?.short } ?? "Free") · \(t.age(in: year)) · \(t.clubId == nil ? "free" : Money.format(c.askingPrice(t)))")
                                .font(.system(size: 11 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(1)
                            TNum(text: "\(slot.score(t))", width: TCol.stat, color: strengthColor(slot.score(t)))
                        }
                        .tableRow()
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Nobody affordable would start ahead of your plan.").font(.system(size: 12 * TextScale.factor))
                        .foregroundStyle(Palette.muted).tableRow()
                }
                if !candidates.isEmpty {
                    Text("ADD PLAYERS").font(.system(size: 10 * TextScale.factor, weight: .heavy)).foregroundStyle(Palette.muted)
                    ForEach(candidates.prefix(10)) { p in
                        Button { store.careerPlanAdd(slot, p.id); Haptics.tap() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle").foregroundStyle(Palette.accent).frame(width: TCol.mark)
                                TName(text: p.name, overseas: p.overseas, bold: false)
                                TRole(role: p.role)
                                TNum(text: "\(p.age(in: year))", width: TCol.age, color: Palette.muted)
                                TNum(text: "\(slot.score(p))", width: TCol.stat, color: strengthColor(slot.score(p)))
                            }
                            .tableRow()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func iconButton(_ name: String, disabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 13 * TextScale.factor, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? Palette.stroke : Palette.muted)
        .disabled(disabled)
    }
}
