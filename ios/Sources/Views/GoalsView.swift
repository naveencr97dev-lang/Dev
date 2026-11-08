import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var store: Store
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            Group {
                if store.goals.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(store.sortedGoals) { goal in
                            NavigationLink { GoalDetailView(goal: goal) } label: {
                                goalRow(goal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNew) { GoalEditView(goal: nil) }
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        let habits = store.habits(for: goal)
        let progress = store.goalProgress(goal)
        return HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: progress, color: Color(hex: goal.colorHex), lineWidth: 6, size: 48)
                Text(goal.emoji)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(goal.name).font(.body.weight(.semibold))
                Text("\(habits.count) habit\(habits.count == 1 ? "" : "s") · \(Int(progress * 100))% today")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: "target").font(.system(size: 42)).foregroundStyle(.tint)
            Text("No goals yet").font(.headline)
            Text("Set a goal you care about, then attach habits to it and finish them daily, weekly, or monthly.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, DS.Space.xl)
            Button { showingNew = true } label: { Text("Create a goal").fontWeight(.semibold) }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct GoalDetailView: View {
    @EnvironmentObject var store: Store
    let goal: Goal
    @State private var showingAddHabit = false
    @State private var showingEdit = false

    private var live: Goal { store.goals.first { $0.id == goal.id } ?? goal }
    private var habits: [Habit] { store.habits(for: live) }
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        List {
            Section {
                VStack(spacing: DS.Space.md) {
                    ZStack {
                        ProgressRing(progress: store.goalProgress(live), color: Color(hex: live.colorHex),
                                     lineWidth: 10, size: 84)
                        Text("\(Int(store.goalProgress(live) * 100))%").numeral(18)
                    }
                    if let d = live.targetDate {
                        Text("Target: \(d.formatted(.dateTime.month().day().year()))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Habits") {
                if habits.isEmpty {
                    Text("No habits yet. Add one to work toward this goal.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(habits) { habit in
                        NavigationLink { HabitDetailView(habit: habit) } label: {
                            HabitRow(habit: habit, date: today)
                        }
                    }
                }
                Button {
                    showingAddHabit = true
                } label: {
                    Label("Add habit to goal", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("\(live.emoji) \(live.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showingEdit = true } }
        }
        .sheet(isPresented: $showingAddHabit) {
            HabitEditView(habit: nil, prefill: Habit(name: "", goalId: live.id))
        }
        .sheet(isPresented: $showingEdit) { GoalEditView(goal: live) }
    }
}

struct GoalEditView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let goal: Goal?

    @State private var name = ""
    @State private var emoji = "🎯"
    @State private var colorHex = Palette.habitColors[9]
    @State private var hasTarget = false
    @State private var targetDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("Name (e.g. Run a 10K)", text: $name)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(["🎯","🏃","💪","📚","🧠","💰","🧘","🎸","🥗","😴","🚭","🌱"], id: \.self) { e in
                            Text(e).font(.title3).frame(width: 34, height: 34)
                                .background(Circle().fill(emoji == e ? Color.accentColor.opacity(0.25) : .clear))
                                .onTapGesture { emoji = e }
                        }
                    }
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Palette.habitColors, id: \.self) { hex in
                            Circle().fill(Color(hex: hex)).frame(width: 32, height: 32)
                                .overlay(Circle().stroke(Color.primary, lineWidth: colorHex == hex ? 2 : 0))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
                Section("Target date") {
                    Toggle("Set a target date", isOn: $hasTarget)
                    if hasTarget {
                        DatePicker("Target", selection: $targetDate, displayedComponents: .date)
                    }
                }
                if goal != nil {
                    Section {
                        Button("Delete goal", role: .destructive) {
                            if let g = goal { store.deleteGoal(g) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(goal == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: hydrate)
        }
    }

    private func hydrate() {
        guard let g = goal else { return }
        name = g.name; emoji = g.emoji; colorHex = g.colorHex
        if let d = g.targetDate { hasTarget = true; targetDate = d }
    }

    private func save() {
        var g = goal ?? Goal(name: "")
        g.name = name.trimmingCharacters(in: .whitespaces)
        g.emoji = emoji
        g.colorHex = colorHex
        g.targetDate = hasTarget ? targetDate : nil
        if goal == nil { store.addGoal(g) } else { store.updateGoal(g) }
        dismiss()
    }
}
