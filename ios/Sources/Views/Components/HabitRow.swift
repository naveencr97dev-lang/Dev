import SwiftUI

struct HabitRow: View {
    @EnvironmentObject var store: Store
    let habit: Habit
    let date: Date

    private var value: Int { store.value(for: habit, on: date) }
    private var done: Bool { store.isDone(habit, on: date) }
    private var progress: Double {
        Double(value) / Double(habit.dailyTarget)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: habit.colorHex).opacity(0.18))
                    .frame(width: 44, height: 44)
                Text(habit.emoji).font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.body.weight(.semibold))
                    .strikethrough(done && habit.kind == .build, color: .secondary)
                if let target = habit.goalTarget, let unit = habit.goalUnit {
                    Text("\(value) / \(target) \(unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(habit.kind == .quit ? "Stay clean today" : (done ? "Done" : "Tap to complete"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                withAnimation { store.toggle(habit, on: date) }
            } label: {
                if habit.goalTarget == nil {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundStyle(done ? Color(hex: habit.colorHex) : Color.secondary.opacity(0.5))
                } else {
                    ZStack {
                        ProgressRing(progress: progress, color: Color(hex: habit.colorHex), lineWidth: 5, size: 38)
                        Image(systemName: done ? "checkmark" : "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(hex: habit.colorHex))
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
