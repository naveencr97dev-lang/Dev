import Foundation

/// Streak and completion calculations derived from check-ins.
struct Stats {
    let calendar: Calendar
    let store: Store

    init(store: Store, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    /// Current streak: consecutive scheduled days, ending today (or yesterday
    /// if today isn't done yet), that are completed.
    func currentStreak(_ habit: Habit) -> Int {
        var streak = 0
        var day = calendar.startOfDay(for: Date())

        // If today is scheduled but not done, don't break the streak yet —
        // start counting from yesterday.
        if habit.isScheduled(on: day, calendar: calendar), !store.isDone(habit, on: day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }

        var guard_ = 0
        while guard_ < 3650 {
            guard_ += 1
            if habit.isScheduled(on: day, calendar: calendar) {
                if store.isDone(habit, on: day) {
                    streak += 1
                } else {
                    break
                }
            }
            day = calendar.date(byAdding: .day, value: -1, to: day)!
            if day < calendar.startOfDay(for: habit.createdAt) { break }
        }
        return streak
    }

    /// Longest streak ever for the habit.
    func longestStreak(_ habit: Habit) -> Int {
        let start = calendar.startOfDay(for: habit.createdAt)
        let today = calendar.startOfDay(for: Date())
        var best = 0, run = 0
        var day = start
        var guard_ = 0
        while day <= today, guard_ < 3650 {
            guard_ += 1
            if habit.isScheduled(on: day, calendar: calendar) {
                if store.isDone(habit, on: day) {
                    run += 1
                    best = max(best, run)
                } else {
                    run = 0
                }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return best
    }

    /// Completion rate over the last `days` scheduled days (0...1).
    func completionRate(_ habit: Habit, lastDays days: Int = 30) -> Double {
        let today = calendar.startOfDay(for: Date())
        var scheduled = 0, done = 0
        for offset in 0..<days {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            if day < calendar.startOfDay(for: habit.createdAt) { continue }
            if habit.isScheduled(on: day, calendar: calendar) {
                scheduled += 1
                if store.isDone(habit, on: day) { done += 1 }
            }
        }
        guard scheduled > 0 else { return 0 }
        return Double(done) / Double(scheduled)
    }

    /// Overall completion across all active habits for a given day (0...1).
    func dayProgress(on date: Date) -> Double {
        let habits = store.habitsScheduled(on: date)
        guard !habits.isEmpty else { return 0 }
        let done = habits.filter { store.isDone($0, on: date) }.count
        return Double(done) / Double(habits.count)
    }

    // MARK: - Period summaries (Met %, BestDay, TotalDone, BestStreak)

    private func days(back n: Int) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<n).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
    }

    /// Share of scheduled habit-slots completed over the last `n` days (0...1).
    func metRate(lastDays n: Int) -> Double {
        var scheduled = 0, done = 0
        for day in days(back: n) {
            for h in store.habitsScheduled(on: day) {
                scheduled += 1
                if store.isDone(h, on: day) { done += 1 }
            }
        }
        guard scheduled > 0 else { return 0 }
        return Double(done) / Double(scheduled)
    }

    /// Number of fully-completed ("perfect") days in the last `n` days.
    func bestDays(lastDays n: Int) -> Int {
        days(back: n).filter { day in
            let hs = store.habitsScheduled(on: day)
            return !hs.isEmpty && hs.allSatisfy { store.isDone($0, on: day) }
        }.count
    }

    /// Total habit completions in the last `n` days.
    func totalDone(lastDays n: Int) -> Int {
        var total = 0
        for day in days(back: n) {
            total += store.habitsScheduled(on: day).filter { store.isDone($0, on: day) }.count
        }
        return total
    }

    /// Best streak across all active habits.
    func bestStreak() -> Int {
        store.activeHabits.map { longestStreak($0) }.max() ?? 0
    }
}
