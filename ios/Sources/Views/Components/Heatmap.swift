import SwiftUI

/// Month-style completion heatmap for one habit (last ~15 weeks).
struct Heatmap: View {
    @EnvironmentObject var store: Store
    let habit: Habit
    var weeks: Int = 15

    private let calendar = Calendar.current
    private let cell: CGFloat = 14
    private let spacing: CGFloat = 3

    private var columns: [[Date]] {
        let today = calendar.startOfDay(for: Date())
        // Align to the start of this week.
        let weekday = calendar.component(.weekday, from: today)
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today)!
        var cols: [[Date]] = []
        for w in (0..<weeks).reversed() {
            let colStart = calendar.date(byAdding: .day, value: -7 * w, to: startOfWeek)!
            var col: [Date] = []
            for d in 0..<7 {
                col.append(calendar.date(byAdding: .day, value: d, to: colStart)!)
            }
            cols.append(col)
        }
        return cols
    }

    private func level(_ date: Date) -> Double {
        let today = calendar.startOfDay(for: Date())
        if date > today { return -1 }                       // future
        if date < calendar.startOfDay(for: habit.createdAt) { return -1 }
        if !habit.isScheduled(on: date, calendar: calendar) { return -2 } // off day
        return store.isDone(habit, on: date) ? 1 : 0
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                    VStack(spacing: spacing) {
                        ForEach(col, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(fill(for: level(day)))
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
        }
    }

    private func fill(for level: Double) -> Color {
        switch level {
        case 1: return Color(hex: habit.colorHex)
        case 0: return Color(hex: habit.colorHex).opacity(0.12)
        case -2: return Color.secondary.opacity(0.06)
        default: return Color.clear
        }
    }
}
