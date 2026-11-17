import Foundation
import UserNotifications

/// Local notification scheduling for habit reminders. Fails quietly if the
/// user hasn't granted permission.
enum Reminders {
    static func requestAuthorization(completion: @escaping () -> Void = {}) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async { completion() }
        }
    }

    /// Clears and re-schedules a reminder for every habit that has a time set.
    static func sync(store: Store) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for habit in store.activeHabits {
            guard let minutes = habit.reminderMinutes else { continue }
            let content = UNMutableNotificationContent()
            content.title = habit.name
            content.body = habit.kind == .quit ? "Stay on track today." : "Time for your habit \(habit.emoji)"
            content.sound = .default

            var comps = DateComponents()
            comps.hour = minutes / 60
            comps.minute = minutes % 60

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: "habit-\(habit.id.uuidString)",
                                                content: content, trigger: trigger)
            center.add(request)
        }

        // Task reminders: fire once at the task's due date + time.
        let calendar = Calendar.current
        for task in store.tasks where task.remind && !task.done {
            guard let minutes = task.dueMinutes else { continue }
            var comps = calendar.dateComponents([.year, .month, .day], from: task.dueDay)
            comps.hour = minutes / 60
            comps.minute = minutes % 60
            guard let fire = calendar.date(from: comps), fire > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = task.title
            content.body = "Task due"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
                repeats: false)
            let request = UNNotificationRequest(identifier: "task-\(task.id.uuidString)",
                                                content: content, trigger: trigger)
            center.add(request)
        }
    }
}
