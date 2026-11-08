import Foundation

/// Streak and completion calculations derived from check-ins.
/// Handles daily habits (per scheduled day) and weekly/monthly habits
/// (per period).
struct Stats {
    let calendar: Calendar
    let store: Store

    init(store: Store, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    // MARK: - Streaks

    func currentStreak(_ habit: Habit) -> Int {
        habit.frequency == .daily ? currentDailyStreak(habit) : currentPeriodStreak(habit)
    }

    func longestStreak(_ habit: Habit) -> Int {
        habit.frequency == .daily ? longestDailyStreak(habit) : longestPeriodStreak(habit)
    }

    private func currentDailyStreak(_ habit: Habit) -> Int {
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        if habit.isScheduled(on: day, calendar: calendar), !store.isDone(habit, on: day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var guard_ = 0
        while guard_ < 3650 {
            guard_ += 1
            if habit.isScheduled(on: day, calendar: calendar) {
                if store.isDone(habit, on: day) { streak += 1 } else { break }
            }
            day = calendar.date(byAdding: .day, value: -1, to: day)!
            if day < calendar.startOfDay(for: habit.createdAt) { break }
        }
        return streak
    }

    private func longestDailyStreak(_ habit: Habit) -> Int {
        let start = calendar.startOfDay(for: habit.createdAt)
        let today = calendar.startOfDay(for: Date())
        var best = 0, run = 0
        var day = start
        var guard_ = 0
        while day <= today, guard_ < 3650 {
            guard_ += 1
            if habit.isScheduled(on: day, calendar: calendar) {
                if store.isDone(habit, on: day) { run += 1; best = max(best, run) } else { run = 0 }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return best
    }

    private func prevPeriodDay(_ habit: Habit, _ date: Date) -> Date {
        let start = store.periodInterval(for: habit, on: date).start
        return calendar.date(byAdding: .day, value: -1, to: start)!
    }

    private func nextPeriodStart(_ habit: Habit, _ periodStart: Date) -> Date {
        switch habit.frequency {
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: periodStart)!
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: periodStart)!
        case .daily: return calendar.date(byAdding: .day, value: 1, to: periodStart)!
        }
    }

    private func currentPeriodStreak(_ habit: Habit) -> Int {
        var streak = 0
        var ref = Date()
        if !store.isDone(habit, on: ref) { ref = prevPeriodDay(habit, ref) }
        let createdStart = calendar.startOfDay(for: habit.createdAt)
        var guard_ = 0
        while guard_ < 1200 {
            guard_ += 1
            let start = store.periodInterval(for: habit, on: ref).start
            if store.isDone(habit, on: ref) { streak += 1 } else { break }
            if start <= createdStart { break }
            ref = prevPeriodDay(habit, ref)
        }
        return streak
    }

    private func longestPeriodStreak(_ habit: Habit) -> Int {
        var ref = store.periodInterval(for: habit, on: habit.createdAt).start
        let nowStart = store.periodInterval(for: habit, on: Date()).start
        var best = 0, run = 0
        var guard_ = 0
        while ref <= nowStart, guard_ < 1200 {
            guard_ += 1
            if store.isDone(habit, on: ref) { run += 1; best = max(best, run) } else { run = 0 }
            ref = nextPeriodStart(habit, ref)
        }
        return best
    }

    // MARK: - Completion

    func completionRate(_ habit: Habit, lastDays days: Int = 30) -> Double {
        let today = calendar.startOfDay(for: Date())
        if habit.frequency == .daily {
            var scheduled = 0, done = 0
            for offset in 0..<days {
                let day = calendar.date(byAdding: .day, value: -offset, to: today)!
                if day < calendar.startOfDay(for: habit.createdAt) { continue }
                if habit.isScheduled(on: day, calendar: calendar) {
                    scheduled += 1
                    if store.isDone(habit, on: day) { done += 1 }
                }
            }
            return scheduled > 0 ? Double(done) / Double(scheduled) : 0
        } else {
            let startBound = calendar.date(byAdding: .day, value: -days, to: today)!
            var ref = store.periodInterval(for: habit, on: startBound).start
            let nowStart = store.periodInterval(for: habit, on: today).start
            let createdStart = store.periodInterval(for: habit, on: habit.createdAt).start
            var total = 0, done = 0
            var guard_ = 0
            while ref <= nowStart, guard_ < 1200 {
                guard_ += 1
                if ref >= createdStart {
                    total += 1
                    if store.isDone(habit, on: ref) { done += 1 }
                }
                ref = nextPeriodStart(habit, ref)
            }
            return total > 0 ? Double(done) / Double(total) : 0
        }
    }

    /// Overall completion across active habits for a given day (0...1).
    func dayProgress(on date: Date) -> Double {
        let habits = store.habitsScheduled(on: date)
        guard !habits.isEmpty else { return 0 }
        let done = habits.filter { store.isDone($0, on: date) }.count
        return Double(done) / Double(habits.count)
    }

    // MARK: - Period summaries (daily habits only, for honest day metrics)

    private func days(back n: Int) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<n).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
    }

    func metRate(lastDays n: Int) -> Double {
        var scheduled = 0, done = 0
        for day in days(back: n) {
            for h in store.dailyHabitsScheduled(on: day) {
                scheduled += 1
                if store.isDone(h, on: day) { done += 1 }
            }
        }
        return scheduled > 0 ? Double(done) / Double(scheduled) : 0
    }

    func bestDays(lastDays n: Int) -> Int {
        days(back: n).filter { day in
            let hs = store.dailyHabitsScheduled(on: day)
            return !hs.isEmpty && hs.allSatisfy { store.isDone($0, on: day) }
        }.count
    }

    func totalDone(lastDays n: Int) -> Int {
        var total = 0
        for day in days(back: n) {
            total += store.dailyHabitsScheduled(on: day).filter { store.isDone($0, on: day) }.count
        }
        return total
    }

    func bestStreak() -> Int {
        store.activeHabits.map { longestStreak($0) }.max() ?? 0
    }
}
