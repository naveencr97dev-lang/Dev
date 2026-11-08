import SwiftUI

/// Reports tab: Weekly / Monthly / Yearly views with summary metrics.
struct StatsView: View {
    @EnvironmentObject var store: Store
    @State private var period: Period = .weekly
    private var stats: Stats { Stats(store: store) }
    private let calendar = Calendar.current

    enum Period: String, CaseIterable, Identifiable {
        case weekly = "Weekly", monthly = "Monthly", yearly = "Yearly"
        var id: String { rawValue }
        var days: Int { self == .weekly ? 7 : (self == .monthly ? 30 : 365) }
        var heatmapWeeks: Int { self == .monthly ? 6 : 53 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Period", selection: $period) {
                        ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                if store.activeHabits.isEmpty {
                    Section {
                        Text("No data yet. Create a habit and check it off to see your reports here.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    Section { summaryTiles.listRowBackground(Color.clear) }

                    switch period {
                    case .weekly: weeklyGrid
                    case .monthly, .yearly: calendarCards
                    }
                }
            }
            .navigationTitle("Reports")
        }
    }

    // MARK: Summary

    private var summaryTiles: some View {
        HStack(spacing: 10) {
            metric("\(Int(stats.metRate(lastDays: period.days) * 100))%", "Met", "#EF4444")
            metric("\(stats.bestDays(lastDays: period.days))d", "BestDay", "#4F8CFF")
            metric("\(stats.totalDone(lastDays: period.days))", "Done", "#34D399")
            metric("\(stats.bestStreak())d", "Streak", "#F59E0B")
        }
    }

    private func metric(_ value: String, _ label: String, _ hex: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: hex))
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: Weekly grid (habits × 7 days)

    private var weekDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: today)!
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: monday)! }
    }

    private var weeklyGrid: some View {
        Section {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("").frame(width: 92, alignment: .leading)
                    ForEach(weekDays, id: \.self) { d in
                        Text(letter(d)).font(.caption2).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(store.activeHabits) { habit in
                    HStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Text(habit.emoji)
                            Text(habit.name).font(.caption).lineLimit(1)
                        }
                        .frame(width: 92, alignment: .leading)
                        ForEach(weekDays, id: \.self) { d in
                            cell(habit, d)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func cell(_ habit: Habit, _ day: Date) -> some View {
        let today = calendar.startOfDay(for: Date())
        let scheduled = habit.isScheduled(on: day, calendar: calendar)
        let future = day > today
        let done = store.isDone(habit, on: day)
        return RoundedRectangle(cornerRadius: 5)
            .fill(
                future || !scheduled ? Color.secondary.opacity(0.08)
                : (done ? Color(hex: habit.colorHex) : Color(hex: habit.colorHex).opacity(0.15))
            )
            .frame(height: 26)
    }

    // MARK: Monthly / Yearly cards

    private var calendarCards: some View {
        Section {
            ForEach(store.activeHabits) { habit in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(habit.emoji)
                        Text(habit.name).font(.headline)
                        Spacer()
                        Text("\(Int(stats.completionRate(habit, lastDays: period.days) * 100))%")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: habit.colorHex))
                    }
                    Heatmap(habit: habit, weeks: period.heatmapWeeks)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func letter(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEEE"; return f.string(from: d)
    }
}
