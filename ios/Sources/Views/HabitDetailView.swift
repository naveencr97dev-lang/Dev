import SwiftUI

struct HabitDetailView: View {
    @EnvironmentObject var store: Store
    let habit: Habit
    @State private var showingEdit = false

    private var stats: Stats { Stats(store: store) }
    // Re-read the habit from the store so edits reflect immediately.
    private var live: Habit { store.habits.first { $0.id == habit.id } ?? habit }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    streakTile(value: stats.currentStreak(live), label: "Current", unit: "days")
                    streakTile(value: stats.longestStreak(live), label: "Best", unit: "days")
                    streakTile(value: Int(stats.completionRate(live) * 100), label: "30-day", unit: "%")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("History") {
                Heatmap(habit: live)
                    .padding(.vertical, 6)
            }

            Section("Details") {
                row("Type", live.kind.label)
                if let t = live.goalTarget, let u = live.goalUnit {
                    row("Goal", "\(t) \(u) / day")
                }
                row("Schedule", live.isDaily ? "Every day" : scheduleText(live))
                if let m = live.reminderMinutes {
                    row("Reminder", String(format: "%02d:%02d", m / 60, m % 60))
                }
            }
        }
        .navigationTitle("\(live.emoji) \(live.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            HabitEditView(habit: live)
        }
    }

    private func streakTile(value: Int, label: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: live.colorHex))
            Text(unit).font(.caption2).foregroundStyle(.secondary)
            Text(label).font(.caption).fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k); Spacer(); Text(v).foregroundStyle(.secondary) }
    }

    private func scheduleText(_ h: Habit) -> String {
        let syms = Calendar.current.shortStandaloneWeekdaySymbols
        return h.weekdays.sorted().map { syms[$0 - 1] }.joined(separator: " ")
    }
}
