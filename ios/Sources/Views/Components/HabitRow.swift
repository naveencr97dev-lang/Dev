import SwiftUI
import UIKit

struct HabitRow: View {
    @EnvironmentObject var store: Store
    let habit: Habit
    let date: Date

    private var color: Color { Color(hex: habit.colorHex) }
    private var periodDone: Bool { store.isDone(habit, on: date) }
    private var checkedToday: Bool { store.value(for: habit, on: date) >= 1 }
    private var progress: Double { store.periodProgress(habit, on: date) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 44, height: 44)
                Text(habit.emoji).font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.body.weight(.semibold))
                    .strikethrough(periodDone && habit.kind == .build, color: .secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Haptics.tap()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    store.toggle(habit, on: date)
                }
            } label: { trailingControl }
                .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        switch habit.frequency {
        case .daily:
            if let target = habit.goalTarget, let unit = habit.goalUnit {
                return "\(store.value(for: habit, on: date)) / \(target) \(unit)"
            }
            return habit.kind == .quit ? "Stay clean today" : (periodDone ? "Done" : "Tap to complete")
        case .weekly, .monthly:
            let n = store.completions(habit, inPeriodOf: date)
            return "\(n) / \(max(habit.periodTarget, 1)) this \(habit.frequency.unit)"
        }
    }

    @ViewBuilder private var trailingControl: some View {
        if habit.frequency == .daily && habit.goalTarget == nil {
            Image(systemName: periodDone ? "checkmark.circle.fill" : "circle")
                .font(.title)
                .foregroundStyle(periodDone ? color : Color.secondary.opacity(0.5))
        } else {
            ZStack {
                ProgressRing(progress: progress, color: color, lineWidth: 5, size: 38)
                Image(systemName: iconName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
            }
        }
    }

    private var iconName: String {
        switch habit.frequency {
        case .daily: return periodDone ? "checkmark" : "plus"
        case .weekly, .monthly: return checkedToday ? "checkmark" : "plus"
        }
    }
}
