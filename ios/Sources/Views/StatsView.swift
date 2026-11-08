import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: Store
    private var stats: Stats { Stats(store: store) }
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            List {
                Section("Last 7 days") {
                    weekBars
                        .listRowBackground(Color.clear)
                }

                if store.activeHabits.isEmpty {
                    Section {
                        Text("No data yet. Create a habit and check it off to see your progress here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Streaks") {
                        ForEach(store.activeHabits) { habit in
                            HStack {
                                Text(habit.emoji)
                                Text(habit.name)
                                Spacer()
                                Label("\(stats.currentStreak(habit))", systemImage: "flame.fill")
                                    .foregroundStyle(Color(hex: habit.colorHex))
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }

    private var weekBars: some View {
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).reversed().map { calendar.date(byAdding: .day, value: -$0, to: today)! }
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(days, id: \.self) { day in
                let p = stats.dayProgress(on: day)
                VStack(spacing: 6) {
                    Text("\(Int(p * 100))%").font(.caption2).foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(height: max(6, CGFloat(p) * 120))
                    Text(letter(day)).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 160)
        .padding(.vertical, 8)
    }

    private func letter(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEEE"; return f.string(from: d)
    }
}
