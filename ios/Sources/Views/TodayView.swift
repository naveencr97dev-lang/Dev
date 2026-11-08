import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: Store
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var showingNew = false
    @State private var statusFilter: StatusFilter = .all
    @State private var timeFilter: TimeFilter = .all

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
                    Section {
                        ForEach(habits) { habit in
                            NavigationLink { HabitDetailView(habit: habit) } label: {
                                HabitRow(habit: habit, date: selected)
                            }
                        }
                    } header: {
                        Text(doneCount == habits.count ? "All done — nice 🎉" : "\(doneCount) of \(habits.count) done")
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNew) {
                HabitTemplatePicker()
            }
        }
    }

    private var doneCount: Int { habits.filter { store.isDone($0, on: selected) }.count }

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
