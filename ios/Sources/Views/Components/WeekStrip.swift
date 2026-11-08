import SwiftUI

/// Horizontal 7-day strip for picking the active day.
struct WeekStrip: View {
    @Binding var selected: Date
    var dayProgress: (Date) -> Double

    private let calendar = Calendar.current

    private var days: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { calendar.date(byAdding: .day, value: -$0, to: today)! }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { day in
                let isSel = calendar.isDate(day, inSameDayAs: selected)
                Button {
                    selected = day
                } label: {
                    VStack(spacing: 6) {
                        Text(weekdayLetter(day))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ZStack {
                            ProgressRing(progress: dayProgress(day),
                                         color: .accentColor, lineWidth: 3, size: 30)
                            Text("\(calendar.component(.day, from: day))")
                                .font(.footnote.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSel ? Color.accentColor.opacity(0.15) : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func weekdayLetter(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE" // single letter
        return f.string(from: date)
    }
}
