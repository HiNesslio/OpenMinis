//
// ButlerLocalNotifications.swift — opt-in iOS local notifications.
// Schedules only known EventKit times. Never fabricates ETAs or forecasts.
//
import Foundation
import UserNotifications

struct ButlerNotificationPlan: Equatable {
    let identifier: String
    let title: String
    let body: String
    let fireAt: Date
}

enum ButlerNotificationPlanner {
    static func plans(events: [ButlerAgendaItem], now: Date) -> [ButlerNotificationPlan] {
        events.filter { !$0.isAllDay && $0.start > now.addingTimeInterval(31 * 60) }
            .sorted { $0.start < $1.start }
            .prefix(12)
            .map { event in
                ButlerNotificationPlan(
                    identifier: "butler.upcoming." + event.id,
                    title: "30 分鐘後有行程",
                    body: "「\(event.title)」即將開始。請確認準備及出發時間。",
                    fireAt: event.start.addingTimeInterval(-30 * 60)
                )
            }
    }
}

@MainActor
enum ButlerLocalNotifications {
    private static let prefix = "butler.upcoming."

    static func enableAndSync(events: [ButlerAgendaItem]) async -> (Bool, String) {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            guard granted else { return (false, "通知權限未獲授予。") }
            return (true, await sync(events: events))
        } catch {
            return (false, "無法啟用本機提醒：\(error.localizedDescription)")
        }
    }

    /// Reconcile existing Butler notifications, including event edits/deletions.
    /// Called on explicit opt-in and when the Today screen refreshes.
    static func sync(events: [ButlerAgendaItem]) async -> String {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        let auth = await center.notificationSettings().authorizationStatus
        guard auth == .authorized || auth == .provisional else {
            return "尚未允許通知，未建立任何提醒。"
        }

        let plans = ButlerNotificationPlanner.plans(events: events, now: Date())
        var scheduled = 0
        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            let time = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: plan.fireAt
            )
            let request = UNNotificationRequest(
                identifier: plan.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: time, repeats: false)
            )
            do {
                try await center.add(request)
                scheduled += 1
            } catch {
                // Fail closed per event; no retry loop in the foreground UI.
            }
        }
        return "已安排 \(scheduled) 項本機提醒。只涵蓋目前已讀取的行程。"
    }

    static func disable() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
