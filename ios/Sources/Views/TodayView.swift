import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: Store
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var showingNew = false
    @State private var editing: Habit? = nil

    private var stats: Stats { Stats(store: store) }
    private var habits: [Habit] { store.habitsScheduled(on: selected) }

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
                HabitEditView(habit: nil)
            }
        }
    }

    private var doneCount: Int { habits.filter { store.isDone($0, on: selected) }.count }

    private var title: String {
        Calendar.current.isDateInToday(selected) ? "Today" :
            selected.formatted(.dateTime.weekday(.wide).month().day())
    }

    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    ProgressRing(progress: stats.dayProgress(on: selected), lineWidth: 10, size: 64)
                    Text("\(Int(stats.dayProgress(on: selected) * 100))%")
                        .font(.headline)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting).font(.title3.weight(.bold))
                    Text("\(store.activeHabits.count) active habit\(store.activeHabits.count == 1 ? "" : "s")")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            WeekStrip(selected: $selected) { stats.dayProgress(on: $0) }
        }
        .padding(16)
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
