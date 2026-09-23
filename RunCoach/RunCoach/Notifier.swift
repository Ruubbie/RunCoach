import Foundation
import UserNotifications

/// Strict local reminders. No server needed: they're scheduled on the phone itself.
@MainActor
enum Notifier {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func reschedule(store: Store) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let hour = store.settings.reminderHour
        let streak = store.streak

        // iOS allows 64 pending notifications; 14 days x max 3 = 42.
        for offset in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let w = PlanEngine.workout(for: day, settings: store.settings)
            if w.dayType == .rest { continue }
            if offset == 0 && store.didActivity(on: day) { continue }

            let minutes = max(1, w.totalSeconds / 60)
            var messages: [(hour: Int, title: String, body: String)] = [
                (hour, w.title, "\(w.summary) Shoes on. No negotiating.")
            ]
            if hour + 2 < 21 {
                messages.append((hour + 2, "Still waiting on you",
                                 "\(minutes) minutes. That's all today asks. Go now."))
            }
            if hour < 21 {
                let streakLine = (offset == 0 && streak > 0)
                    ? "Your \(streak)-day streak dies tonight if you skip."
                    : "Don't let today be a zero."
                messages.append((21, "Last call", "\(streakLine) Get out the door."))
            }

            for (i, m) in messages.enumerated() {
                var comps = cal.dateComponents([.year, .month, .day], from: day)
                comps.hour = m.hour
                comps.minute = 0
                if let fire = cal.date(from: comps), fire <= now { continue }
                let content = UNMutableNotificationContent()
                content.title = m.title
                content.body = m.body
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: "day\(offset)-\(i)", content: content, trigger: trigger)) { _ in }
            }
        }
    }

    static func test() {
        let content = UNMutableNotificationContent()
        content.title = "run."
        content.body = "This is what I'll sound like when you skip a run. 👀"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "test", content: content, trigger: trigger)) { _ in }
    }
}
