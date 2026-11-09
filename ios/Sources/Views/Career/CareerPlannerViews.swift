import SwiftUI

/// Career › Squad › Squad planner: one card per job in the XI (starters, then depth), auto-fill, and
/// "Use as my XI".
struct SquadPlannerView: View {
    @EnvironmentObject var store: GameStore
    @State private var message: String? = nil

    var body: some View {
        if let c = store.career {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                Text("Plan who does each job, and who steps in behind them. The plan doesn't change your XI until you use it.")
                    .font(.display(13, weight: .regular)).foregroundStyle(Palette.muted)
                HStack(spacing: DS.Space.sm) {
                    Button {
                        store.careerAutoPlan()
                        message = "Planned from your best players."
                        Haptics.success()
                    } label: { Label(c.plan == nil ? "Auto-fill" : "Auto-fill again", systemImage: "wand.and.stars") }
                    .buttonStyle(SecondaryButtonStyle())
                    Button {
                        let issues = store.careerApplyPlan()
                        message = issues.isEmpty ? "Your XI now follows the plan. The assistant stops picking the team." : issues.joined(separator: " ")
                        if issues.isEmpty { Haptics.success() } else { Haptics.warning() }
                    } label: { Label("Use as my XI", systemImage: "checkmark.circle") }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(c.plan == nil)
                }
                if let message {
                    Text(message).font(.display(13, weight: .semibold)).foregroundStyle(Palette.accent)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: DS.Space.md)], spacing: DS.Space.md) {
                    ForEach(PlanSlot.allCases) { slot in
                        NavigationLink { CareerScreen(title: slot.label) { PlanSlotView(slot: slot) } } label: {
                            PlanSlotCard(career: c, slot: slot)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

/// One job on the planner: starters and depth with ratings, the job's average, and a warning.
struct PlanSlotCard: View {
    let career: Career
    let slot: PlanSlot

    var body: some View {
        let c = career
        let list = c.planned(slot)
        let summary = c.planSummary(slot)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(slot.label.uppercased()).font(.display(12, weight: .heavy)).foregroundStyle(Palette.muted)
                Spacer()
                Text(list.isEmpty ? "–" : "\(summary.rating)").font(.score(16)).foregroundStyle(strengthColor(summary.rating))
            }
            if list.isEmpty {
                Text("Nobody planned. Tap to add.").font(.display(14, weight: .regular)).foregroundStyle(Palette.muted)
            }
            ForEach(Array(list.prefix(SquadPlan.depth).enumerated()), id: \.element.id) { i, p in
                HStack(spacing: 8) {
                    Text("\(slot.score(p))").font(.score(14)).foregroundStyle(strengthColor(slot.score(p))).frame(width: 26, alignment: .leading)
                    Text(p.name).font(.display(14, weight: i < slot.starters ? .semibold : .regular))
                        .foregroundStyle(i < slot.starters ? .white : Palette.muted).lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(p.age(in: c.year))").font(.score(13)).foregroundStyle(Palette.muted)
                }
            }
            if let warning = summary.successionWarning {
                Label(warning, systemImage: "exclamationmark.triangle").font(.display(11, weight: .semibold)).foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .gameFrame()
        .contentShape(Rectangle())
    }
}

/// Editing one job: order the depth chart, add or remove players, and the scout's suggested target.
struct PlanSlotView: View {
    @EnvironmentObject var store: GameStore
    let slot: PlanSlot

    var body: some View {
        if let c = store.career {
            let list = c.planned(slot)
            let summary = c.planSummary(slot)
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                HStack(spacing: 0) {
                    stat(list.isEmpty ? "–" : "\(summary.rating)", "RATING")
                    stat(list.isEmpty ? "–" : String(format: "%.1f", summary.age), "AGE")
                    stat("\(slot.starters)", "IN THE XI")
                    stat("\(max(0, list.count - slot.starters))", "BACKUPS")
                }
                .padding(.vertical, DS.Space.sm)
                .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surface))
                if let warning = summary.successionWarning {
                    Label(warning, systemImage: "exclamationmark.triangle").font(.display(13, weight: .semibold)).foregroundStyle(.orange)
                }

                SectionLabel(text: "Depth chart")
                VStack(spacing: 0) {
                    if list.isEmpty {
                        Text("Nobody planned for this job yet.").font(.subheadline).foregroundStyle(.secondary).padding(16)
                    }
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, p in
                        if i > 0 { Hairline(inset: 16) }
                        HStack(spacing: 10) {
                            Text(i < slot.starters ? "XI" : "\(i - slot.starters + 1)")
                                .font(.display(11, weight: .heavy)).foregroundStyle(i < slot.starters ? Palette.accent : Palette.muted)
                                .frame(width: 22)
                            NavigationLink { CareerPlayerView(playerId: p.id) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(.display(15, weight: .semibold)).lineLimit(1)
                                    Text("\(p.age(in: c.year)) · \(p.role.short) · form \(CareerText.form(p.form))")
                                        .font(.caption).foregroundStyle(Palette.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            Text("\(slot.score(p))").font(.score(16)).foregroundStyle(strengthColor(slot.score(p)))
                            iconButton("chevron.up", disabled: i == 0) { store.careerPlanMove(slot, p.id, by: -1) }
                            iconButton("chevron.down", disabled: i == list.count - 1) { store.careerPlanMove(slot, p.id, by: 1) }
                            iconButton("trash", disabled: false) { store.careerPlanRemove(slot, p.id) }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                    }
                }
                .gameFrame()
                if !list.isEmpty {
                    Button("Clear this job") { store.careerPlanClear(slot) }
                        .font(.display(14, weight: .semibold)).foregroundStyle(Palette.wicket)
                }

                let candidates = c.planCandidates(slot)
                if !candidates.isEmpty {
                    SectionLabel(text: "Add players")
                    VStack(spacing: 0) {
                        ForEach(Array(candidates.prefix(8).enumerated()), id: \.element.id) { i, p in
                            if i > 0 { Hairline(inset: 16) }
                            Button { store.careerPlanAdd(slot, p.id); Haptics.tap() } label: {
                                HStack {
                                    Image(systemName: "plus.circle").foregroundStyle(Palette.accent)
                                    Text(p.name).font(.display(15, weight: .regular)).lineLimit(1)
                                    Spacer()
                                    Text("\(p.age(in: c.year))").font(.score(14)).foregroundStyle(Palette.muted)
                                    Text("\(slot.score(p))").font(.score(16)).foregroundStyle(strengthColor(slot.score(p))).frame(width: 34, alignment: .trailing)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .gameFrame()
                }

                SectionLabel(text: "Scout's target")
                if let t = c.planTarget(slot) {
                    NavigationLink { CareerPlayerView(playerId: t.id) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.name).font(.display(16, weight: .semibold)).lineLimit(1)
                                Text("\(t.clubId.flatMap { c.club($0)?.short } ?? "Free agent") · \(t.age(in: c.year)) · \(t.clubId == nil ? "free" : Money.format(c.askingPrice(t)))")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Text("\(slot.score(t))").font(.score(20)).foregroundStyle(strengthColor(slot.score(t)))
                            Image(systemName: "chevron.right").foregroundStyle(Palette.stroke)
                        }
                        .padding(14)
                        .gameFrame()
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Nobody affordable would start ahead of your plan.").font(.subheadline).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.display(18)).lineLimit(1).minimumScaleFactor(0.6)
            Text(l).font(.display(9, weight: .heavy)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func iconButton(_ name: String, disabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 14 * TextScale.factor, weight: .semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? Palette.stroke : Palette.muted)
        .disabled(disabled)
    }
}
