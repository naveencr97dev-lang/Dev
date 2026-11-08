import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: Store
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var showingNew = false
    @State private var showingJournal = false
    @State private var statusFilter: StatusFilter = .all
    @State private var timeFilter: TimeFilter = .all
    @State private var collapsedGroups: Set<String> = []

    private var stats: Stats { Stats(store: store) }

    private var habits: [Habit] {
        store.habitsScheduled(on: selected).filter { h in
            switch statusFilter {
            case .all: break
            case .met: if !store.isDone(h, on: selected) { return false }
            case .unmet: if store.isDone(h, on: selected) { return false }
            }
            switch timeFilter {
            case .all: return true
            case .some(let t): return h.timeOfDay == t
            }
        }
    }

    enum StatusFilter: String, CaseIterable, Identifiable { case all, unmet, met; var id: String { rawValue } }
    enum TimeFilter: Equatable, Identifiable {
        case all
        case some(TimeOfDay)
        var id: String { if case .some(let t) = self { return t.rawValue }; return "all" }
        var label: String { if case .some(let t) = self { return t.label }; return "All" }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    headerCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if habits.isEmpty {
                    Section {
                        emptyState
                            .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(groups) { group in
                        groupSection(group)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingJournal = true } label: { Image(systemName: "face.smiling") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNew) {
                HabitTemplatePicker()
            }
            .sheet(isPresented: $showingJournal) {
                MoodView()
            }
        }
    }

    private var doneCount: Int { habits.filter { store.isDone($0, on: selected) }.count }

    // MARK: - Grouping by goal

    struct HabitGroup: Identifiable {
        let id: String
        let goal: Goal?
        let habits: [Habit]
    }

    private var groups: [HabitGroup] {
        let items = habits
        let goalIds = Set(store.goals.map { $0.id })
        var result: [HabitGroup] = []
        for goal in store.sortedGoals {
            let gh = items.filter { $0.goalId == goal.id }
            if !gh.isEmpty { result.append(HabitGroup(id: goal.id.uuidString, goal: goal, habits: gh)) }
        }
        let ungrouped = items.filter { $0.goalId == nil || !goalIds.contains($0.goalId!) }
        if !ungrouped.isEmpty { result.append(HabitGroup(id: "none", goal: nil, habits: ungrouped)) }
        return result
    }

    @ViewBuilder
    private func groupSection(_ group: HabitGroup) -> some View {
        let done = group.habits.filter { store.isDone($0, on: selected) }.count
        // With goals present, collapse into disclosure groups to cut clutter.
        if group.goal != nil || store.goals.contains(where: { !store.habits(for: $0).isEmpty }) {
            Section {
                DisclosureGroup(isExpanded: expansion(group.id)) {
                    ForEach(group.habits) { habit in
                        NavigationLink { HabitDetailView(habit: habit) } label: {
                            HabitRow(habit: habit, date: selected)
                        }
                    }
                } label: {
                    groupHeader(group, done: done)
                }
            }
        } else {
            Section {
                ForEach(group.habits) { habit in
                    NavigationLink { HabitDetailView(habit: habit) } label: {
                        HabitRow(habit: habit, date: selected)
                    }
                }
            } header: {
                Text(done == group.habits.count ? "All done — nice 🎉" : "\(done) of \(group.habits.count) done")
            }
        }
    }

    private func groupHeader(_ group: HabitGroup, done: Int) -> some View {
        HStack(spacing: 10) {
            if let goal = group.goal {
                Text(goal.emoji)
                Text(goal.name).font(.body.weight(.semibold))
            } else {
                Image(systemName: "tray").foregroundStyle(.secondary)
                Text("Other").font(.body.weight(.semibold))
            }
            Spacer()
            Text("\(done)/\(group.habits.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func expansion(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !collapsedGroups.contains(id) },
            set: { expanded in
                if expanded { collapsedGroups.remove(id) } else { collapsedGroups.insert(id) }
            }
        )
    }

    private var title: String {
        Calendar.current.isDateInToday(selected) ? "Today" :
            selected.formatted(.dateTime.weekday(.wide).month().day())
    }

    private var headerCard: some View {
        AppCard {
            VStack(spacing: DS.Space.lg) {
                HStack(spacing: DS.Space.lg) {
                    ZStack {
                        ProgressRing(progress: stats.dayProgress(on: selected), lineWidth: 10, size: 68)
                        Text("\(Int(stats.dayProgress(on: selected) * 100))%")
                            .numeral(16)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting).font(.title3.weight(.bold))
                        Text("\(store.activeHabits.count) active habit\(store.activeHabits.count == 1 ? "" : "s")")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                WeekStrip(selected: $selected) { stats.dayProgress(on: $0) }
                filterBar
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.sm)
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Picker("Status", selection: $statusFilter) {
                ForEach(StatusFilter.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)

            Menu {
                Button("All") { timeFilter = .all }
                ForEach(TimeOfDay.allCases) { t in
                    Button { timeFilter = .some(t) } label: { Label(t.label, systemImage: t.symbol) }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(timeFilter.label).lineLimit(1)
                }
                .font(.subheadline)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Keep it up"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("No habits for this day")
                .font(.headline)
            Text("Tap + to create your first habit and start a streak.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showingNew = true } label: {
                Text("Create a habit").fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
