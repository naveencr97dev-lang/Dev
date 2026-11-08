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
            let request = UNNotificationRequest(identifier: habit.id.uuidString,
                                                content: content, trigger: trigger)
            center.add(request)
        }
    }
}
