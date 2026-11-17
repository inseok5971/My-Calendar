import AppKit
import Combine
import Foundation
import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var activeToasts: [InAppToast] = []
    var isRunningInAppBundle: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private let notificationDelegate = NotificationDelegate()
    private var timer: Timer?
    private var firedReminderKeys: Set<String> = []
    private var lastDailySummaryDateKey: String?

    static let availableSounds = ["Glass", "Ping", "Pop", "Purr", "Submarine", "Hero", "Basso"]

    init() {
        if isRunningInAppBundle {
            UNUserNotificationCenter.current().delegate = notificationDelegate
        }
    }

    func startMonitoring(store: CalendarStore) {
        if isRunningInAppBundle {
            UNUserNotificationCenter.current().delegate = notificationDelegate
            requestPermissionIfNeeded()
        }
        timer?.invalidate()
        let t = Timer(timeInterval: 10, repeats: true) { [weak self, weak store] _ in
            Task { @MainActor in
                guard let self, let store else { return }
                self.evaluateReminders(store: store)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
        // Run an initial check shortly after launch
        Task {
            try? await Task.sleep(for: .seconds(1))
            evaluateReminders(store: store)
        }
    }

    func requestPermissionIfNeeded() {
        guard isRunningInAppBundle else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
                if settings.authorizationStatus == .notDetermined {
                    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        Task { @MainActor in
                            self.authorizationStatus = granted ? .authorized : .denied
                        }
                    }
                }
            }
        }
    }

    func refreshAuthorizationStatus() {
        guard isRunningInAppBundle else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func evaluateReminders(store: CalendarStore) {
        let now = Date()
        let settings = store.settings

        let todayEvents = store.events(on: now)
        for event in todayEvents where !event.isCompleted && event.periodType == .timed && !event.isAllDay {
            for offset in event.reminderOffsets {
                let triggerDate = event.startDate.addingTimeInterval(-offset.seconds)
                let delta = now.timeIntervalSince(triggerDate)
                // Fire if we are within [0, 90] seconds of the trigger time
                if delta >= 0 && delta <= 90 {
                    let key = "\(event.id.uuidString)-\(offset.rawValue)-\(Int(event.startDate.timeIntervalSince1970))"
                    if !firedReminderKeys.contains(key) {
                        firedReminderKeys.insert(key)
                        let timeStr = Self.timeFormatter.string(from: event.startDate)
                        let subtitle: String
                        if offset == .atTime {
                            subtitle = "시작 시간입니다 (\(timeStr))"
                        } else {
                            subtitle = "\(offset.label)입니다 (\(timeStr) 시작)"
                        }
                        deliverNotification(
                            title: event.title,
                            subtitle: subtitle,
                            category: event.category,
                            eventID: event.id,
                            settings: settings
                        )
                    }
                }
            }
        }

        // Evaluate Todos with due date reminders
        for todo in store.todos where !todo.isCompleted {
            guard let dueDate = todo.dueDate else { continue }
            for offset in todo.reminderOffsets {
                let triggerDate = dueDate.addingTimeInterval(-offset.seconds)
                let delta = now.timeIntervalSince(triggerDate)
                if delta >= 0 && delta <= 90 {
                    let key = "todo-\(todo.id.uuidString)-\(offset.rawValue)-\(Int(dueDate.timeIntervalSince1970))"
                    if !firedReminderKeys.contains(key) {
                        firedReminderKeys.insert(key)
                        let timeStr = Self.timeFormatter.string(from: dueDate)
                        let subtitle: String
                        if offset == .atTime {
                            subtitle = "마감 시간입니다 (\(timeStr))"
                        } else {
                            subtitle = "마감 \(offset.label)입니다 (\(timeStr) 마감)"
                        }
                        deliverNotification(
                            title: todo.title,
                            subtitle: subtitle,
                            category: todo.category,
                            eventID: todo.scheduledEventID,
                            settings: settings
                        )
                    }
                }
            }
        }

        // Daily summary check
        if settings.enableDailySummary {
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            if let hour = comps.hour, let minute = comps.minute,
               hour == settings.dailySummaryHour && minute == settings.dailySummaryMinute {
                let dateKey = "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
                if lastDailySummaryDateKey != dateKey {
                    lastDailySummaryDateKey = dateKey
                    sendDailySummaryNow(store: store)
                }
            }
        }
    }

    func sendDailySummaryNow(store: CalendarStore) {
        let remaining = store.remainingEventsToday()
        let dueTodayTodos = store.dueOrOverdueTodos()
        let title = "오늘의 일정 요약"
        let subtitle: String
        if remaining.isEmpty && dueTodayTodos.isEmpty {
            subtitle = "남은 일정과 마감 임박 할 일이 없습니다."
        } else {
            let nextText = remaining.first.map { "다음: \($0.title) (\(Self.timeFormatter.string(from: $0.startDate)))" } ?? "남은 일정 없음"
            subtitle = "남은 일정 \(remaining.count)건 · 마감/지연 할 일 \(dueTodayTodos.count)건 · \(nextText)"
        }
        deliverNotification(
            title: title,
            subtitle: subtitle,
            category: .personal,
            eventID: nil,
            settings: store.settings
        )
    }

    func sendTestNotification(settings: AppSettings) {
        deliverNotification(
            title: "알림 테스트",
            subtitle: "스케줄러 알림과 사운드가 정상 작동 중입니다.",
            category: .work,
            eventID: nil,
            settings: settings
        )
    }

    func snoozeToast(_ toast: InAppToast, store: CalendarStore, minutes: Int = 5) {
        dismissToast(toast.id)
        let title = toast.title
        let category = toast.category
        let eventID = toast.eventID
        Task {
            try? await Task.sleep(for: .seconds(minutes * 60))
            deliverNotification(
                title: "[다시 알림] \(title)",
                subtitle: "\(minutes)분 전 스누즈한 일정입니다.",
                category: category,
                eventID: eventID,
                settings: store.settings
            )
        }
    }

    func dismissToast(_ id: UUID) {
        activeToasts.removeAll { $0.id == id }
    }

    func playSound(named name: String) {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func deliverNotification(
        title: String,
        subtitle: String,
        category: EventCategory,
        eventID: UUID?,
        settings: AppSettings
    ) {
        if settings.enableSound {
            playSound(named: settings.soundName)
        }

        if settings.enableInAppToasts {
            let toast = InAppToast(
                title: title,
                subtitle: subtitle,
                category: category,
                eventID: eventID
            )
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                activeToasts.append(toast)
            }
            // Auto-dismiss after 12 seconds
            Task {
                try? await Task.sleep(for: .seconds(12))
                withAnimation {
                    dismissToast(toast.id)
                }
            }
        }

        if settings.enableDesktopNotifications && isRunningInAppBundle {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = subtitle
            if settings.enableSound {
                content.sound = .default
            }
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }
}
