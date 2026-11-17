import Foundation
import SwiftUI

enum CalendarViewMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case day = "일간"
    case week = "주간"
    case month = "월간"

    var id: String { rawValue }
}

enum AppTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "시스템 설정"
    case light = "라이트"
    case dark = "다크"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum EventCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case work = "업무"
    case personal = "개인"
    case health = "건강"
    case study = "학습"
    case other = "기타"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .work: return Color(red: 0.24, green: 0.49, blue: 0.96)
        case .personal: return Color(red: 0.56, green: 0.36, blue: 0.92)
        case .health: return Color(red: 0.16, green: 0.72, blue: 0.52)
        case .study: return Color(red: 0.93, green: 0.54, blue: 0.19)
        case .other: return Color(red: 0.48, green: 0.53, blue: 0.60)
        }
    }

    var symbol: String {
        switch self {
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .health: return "heart.fill"
        case .study: return "book.fill"
        case .other: return "tag.fill"
        }
    }
}

enum ReminderOffset: Int, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case atTime = 0
    case fiveMin = 5
    case tenMin = 10
    case fifteenMin = 15
    case thirtyMin = 30
    case oneHour = 60

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .atTime: return "정각"
        case .fiveMin: return "5분 전"
        case .tenMin: return "10분 전"
        case .fifteenMin: return "15분 전"
        case .thirtyMin: return "30분 전"
        case .oneHour: return "1시간 전"
        }
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue * 60)
    }
}

enum TodoPriority: String, CaseIterable, Identifiable, Codable, Sendable {
    case low = "낮음"
    case medium = "보통"
    case high = "높음"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .low: return .secondary
        case .medium: return .orange
        case .high: return .red
        }
    }
}

enum TodoScope: String, CaseIterable, Identifiable, Codable, Sendable {
    case today = "오늘 할 일"
    case thisWeek = "이번 주 할 일"
    case thisMonth = "이번 달 할 일"

    var id: String { rawValue }
}

enum EventPeriodType: String, CaseIterable, Identifiable, Codable, Sendable {
    case timed = "시간 지정"
    case allDay = "하루 종일"
    case thisWeek = "이번 주 동안"
    case thisMonth = "이번 달 동안"
    case customRange = "기간 지정"

    var id: String { rawValue }
}

enum RecurrenceRule: String, CaseIterable, Identifiable, Codable, Sendable {
    case none = "반복 없음"
    case daily = "매일"
    case weekdays = "주중 (월~금)"
    case weekly = "매주"
    case biweekly = "격주 (2주)"
    case monthly = "매월"
    case yearly = "매년"

    var id: String { rawValue }

    var shortLabel: String? {
        switch self {
        case .none: return nil
        case .daily: return "매일"
        case .weekdays: return "주중"
        case .weekly: return "매주"
        case .biweekly: return "격주"
        case .monthly: return "매월"
        case .yearly: return "매년"
        }
    }
}

struct ScheduleEvent: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var title: String
    var notes: String = ""
    var startDate: Date
    var endDate: Date
    var category: EventCategory = .work
    var reminderOffsets: [ReminderOffset] = [.tenMin, .atTime]
    var isCompleted: Bool = false
    var linkedTodoID: UUID? = nil
    var periodType: EventPeriodType = .timed
    var isAllDay: Bool = false
    var recurrence: RecurrenceRule = .none
    var recurrenceEndDate: Date? = nil
    var completedDates: Set<String> = []
    var linkedFolderPath: String? = nil

    var linkedFolderName: String? {
        guard let linkedFolderPath, !linkedFolderPath.isEmpty else { return nil }
        return (linkedFolderPath as NSString).lastPathComponent
    }

    var durationMinutes: Int {
        max(15, Int(endDate.timeIntervalSince(startDate) / 60))
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, startDate, endDate, category, reminderOffsets, isCompleted, linkedTodoID, periodType, isAllDay, recurrence, recurrenceEndDate, completedDates, linkedFolderPath
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        startDate: Date,
        endDate: Date,
        category: EventCategory = .work,
        reminderOffsets: [ReminderOffset] = [.tenMin, .atTime],
        isCompleted: Bool = false,
        linkedTodoID: UUID? = nil,
        periodType: EventPeriodType = .timed,
        isAllDay: Bool = false,
        recurrence: RecurrenceRule = .none,
        recurrenceEndDate: Date? = nil,
        completedDates: Set<String> = [],
        linkedFolderPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.category = category
        self.reminderOffsets = reminderOffsets
        self.isCompleted = isCompleted
        self.linkedTodoID = linkedTodoID
        self.periodType = periodType
        self.isAllDay = isAllDay
        self.recurrence = recurrence
        self.recurrenceEndDate = recurrenceEndDate
        self.completedDates = completedDates
        self.linkedFolderPath = linkedFolderPath
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decode(Date.self, forKey: .endDate)
        category = try c.decodeIfPresent(EventCategory.self, forKey: .category) ?? .work
        reminderOffsets = try c.decodeIfPresent([ReminderOffset].self, forKey: .reminderOffsets) ?? [.tenMin, .atTime]
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        linkedTodoID = try c.decodeIfPresent(UUID.self, forKey: .linkedTodoID)
        periodType = try c.decodeIfPresent(EventPeriodType.self, forKey: .periodType) ?? .timed
        isAllDay = try c.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? (periodType != .timed)
        recurrence = try c.decodeIfPresent(RecurrenceRule.self, forKey: .recurrence) ?? .none
        recurrenceEndDate = try c.decodeIfPresent(Date.self, forKey: .recurrenceEndDate)
        completedDates = try c.decodeIfPresent(Set<String>.self, forKey: .completedDates) ?? []
        linkedFolderPath = try c.decodeIfPresent(String.self, forKey: .linkedFolderPath)
    }

    static func dateKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func isCompleted(on date: Date) -> Bool {
        if recurrence == .none {
            return isCompleted
        }
        let key = Self.dateKey(for: date)
        return completedDates.contains(key)
    }

    /// Checks if this event (or any of its recurring instances) occurs on `targetDate`
    func occurs(on targetDate: Date) -> Bool {
        let cal = Calendar.current
        let targetStart = cal.startOfDay(for: targetDate)
        let eventStartDay = cal.startOfDay(for: startDate)

        if recurrence == .none {
            let eventEndDay = cal.startOfDay(for: endDate)
            return targetStart >= eventStartDay && targetStart <= eventEndDay
        }

        // Cannot occur before event's initial start date
        if targetStart < eventStartDay {
            return false
        }

        // Cannot occur after recurrence end date if set
        if let recurrenceEndDate, targetStart > cal.startOfDay(for: recurrenceEndDate) {
            return false
        }

        switch recurrence {
        case .none:
            return false
        case .daily:
            return true
        case .weekdays:
            let weekday = cal.component(.weekday, from: targetDate)
            return weekday >= 2 && weekday <= 6 // Mon (2) to Fri (6)
        case .weekly:
            let eventWeekday = cal.component(.weekday, from: startDate)
            let targetWeekday = cal.component(.weekday, from: targetDate)
            return eventWeekday == targetWeekday
        case .biweekly:
            let eventWeekday = cal.component(.weekday, from: startDate)
            let targetWeekday = cal.component(.weekday, from: targetDate)
            guard eventWeekday == targetWeekday else { return false }
            let daysDiff = cal.dateComponents([.day], from: eventStartDay, to: targetStart).day ?? 0
            let weeks = daysDiff / 7
            return weeks % 2 == 0
        case .monthly:
            let eventDay = cal.component(.day, from: startDate)
            let targetDay = cal.component(.day, from: targetDate)
            return eventDay == targetDay
        case .yearly:
            let eventMonth = cal.component(.month, from: startDate)
            let eventDay = cal.component(.day, from: startDate)
            let targetMonth = cal.component(.month, from: targetDate)
            let targetDay = cal.component(.day, from: targetDate)
            return eventMonth == targetMonth && eventDay == targetDay
        }
    }

    /// Returns a copy of the event adapted to `targetDate` for display
    func instance(for targetDate: Date) -> ScheduleEvent {
        guard recurrence != .none else { return self }
        let cal = Calendar.current
        let originalDuration = max(900, endDate.timeIntervalSince(startDate))

        let startComps = cal.dateComponents([.hour, .minute, .second], from: startDate)
        var targetComps = cal.dateComponents([.year, .month, .day], from: targetDate)
        targetComps.hour = startComps.hour ?? 0
        targetComps.minute = startComps.minute ?? 0
        targetComps.second = startComps.second ?? 0

        let instStart = cal.date(from: targetComps) ?? targetDate
        let instEnd = instStart.addingTimeInterval(originalDuration)

        var copy = self
        copy.startDate = instStart
        copy.endDate = instEnd
        copy.isCompleted = isCompleted(on: targetDate)
        return copy
    }
}

struct TodoItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var title: String
    var notes: String = ""
    var dueDate: Date? = nil
    var estimatedMinutes: Int = 60
    var priority: TodoPriority = .medium
    var category: EventCategory = .work
    var scope: TodoScope = .today
    var reminderOffsets: [ReminderOffset] = [.tenMin, .atTime]
    var isCompleted: Bool = false
    var scheduledEventID: UUID? = nil
    var createdAt: Date = Date()
    var linkedFolderPath: String? = nil

    var linkedFolderName: String? {
        guard let linkedFolderPath, !linkedFolderPath.isEmpty else { return nil }
        return (linkedFolderPath as NSString).lastPathComponent
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, dueDate, estimatedMinutes, priority, category, scope, reminderOffsets, isCompleted, scheduledEventID, createdAt, linkedFolderPath
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        estimatedMinutes: Int = 60,
        priority: TodoPriority = .medium,
        category: EventCategory = .work,
        scope: TodoScope = .today,
        reminderOffsets: [ReminderOffset] = [.tenMin, .atTime],
        isCompleted: Bool = false,
        scheduledEventID: UUID? = nil,
        createdAt: Date = Date(),
        linkedFolderPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.priority = priority
        self.category = category
        self.scope = scope
        self.reminderOffsets = reminderOffsets
        self.isCompleted = isCompleted
        self.scheduledEventID = scheduledEventID
        self.createdAt = createdAt
        self.linkedFolderPath = linkedFolderPath
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        estimatedMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedMinutes) ?? 60
        priority = try c.decodeIfPresent(TodoPriority.self, forKey: .priority) ?? .medium
        category = try c.decodeIfPresent(EventCategory.self, forKey: .category) ?? .work
        scope = try c.decodeIfPresent(TodoScope.self, forKey: .scope) ?? .today
        reminderOffsets = try c.decodeIfPresent([ReminderOffset].self, forKey: .reminderOffsets) ?? [.tenMin, .atTime]
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        scheduledEventID = try c.decodeIfPresent(UUID.self, forKey: .scheduledEventID)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        linkedFolderPath = try c.decodeIfPresent(String.self, forKey: .linkedFolderPath)
    }
}

enum WindowDisplayMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case mainCalendar = "스케줄러"
    case miniBoard = "미니 보드"
    case menuBarOnly = "상단바만 (창 숨김)"

    var id: String { rawValue }
}

struct AppSettings: Codable, Equatable, Sendable {
    var theme: AppTheme = .system
    var mainWindowOpacity: Double = 1.0
    var stickyWindowOpacity: Double = 0.95
    var openMiniBoardOnLaunch: Bool = false
    var enableDesktopNotifications: Bool = true
    var enableInAppToasts: Bool = true
    var enableSound: Bool = true
    var soundName: String = "Glass"
    var preReminderMenuBarOnly: Bool = false
    var enableDailySummary: Bool = true
    var dailySummaryHour: Int = 9
    var dailySummaryMinute: Int = 0
    var lastWindowMode: WindowDisplayMode = .mainCalendar
    var launchAtLogin: Bool = true
    var startMinimizedToMenuBar: Bool = false
    var isMiniBoardPinnedOnTop: Bool = true

    enum CodingKeys: String, CodingKey {
        case theme, mainWindowOpacity, stickyWindowOpacity, openMiniBoardOnLaunch, enableDesktopNotifications, enableInAppToasts, enableSound, soundName, preReminderMenuBarOnly, enableDailySummary, dailySummaryHour, dailySummaryMinute, lastWindowMode, launchAtLogin, startMinimizedToMenuBar, isMiniBoardPinnedOnTop
    }

    init(
        theme: AppTheme = .system,
        mainWindowOpacity: Double = 1.0,
        stickyWindowOpacity: Double = 0.95,
        openMiniBoardOnLaunch: Bool = false,
        enableDesktopNotifications: Bool = true,
        enableInAppToasts: Bool = true,
        enableSound: Bool = true,
        soundName: String = "Glass",
        preReminderMenuBarOnly: Bool = false,
        enableDailySummary: Bool = true,
        dailySummaryHour: Int = 9,
        dailySummaryMinute: Int = 0,
        lastWindowMode: WindowDisplayMode = .mainCalendar,
        launchAtLogin: Bool = true,
        startMinimizedToMenuBar: Bool = false,
        isMiniBoardPinnedOnTop: Bool = true
    ) {
        self.theme = theme
        self.mainWindowOpacity = mainWindowOpacity
        self.stickyWindowOpacity = stickyWindowOpacity
        self.openMiniBoardOnLaunch = openMiniBoardOnLaunch
        self.enableDesktopNotifications = enableDesktopNotifications
        self.enableInAppToasts = enableInAppToasts
        self.enableSound = soundName.isEmpty ? false : enableSound
        self.soundName = soundName
        self.preReminderMenuBarOnly = preReminderMenuBarOnly
        self.enableDailySummary = enableDailySummary
        self.dailySummaryHour = dailySummaryHour
        self.dailySummaryMinute = dailySummaryMinute
        self.lastWindowMode = lastWindowMode
        self.launchAtLogin = launchAtLogin
        self.startMinimizedToMenuBar = startMinimizedToMenuBar
        self.isMiniBoardPinnedOnTop = isMiniBoardPinnedOnTop
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        mainWindowOpacity = try c.decodeIfPresent(Double.self, forKey: .mainWindowOpacity) ?? 1.0
        stickyWindowOpacity = try c.decodeIfPresent(Double.self, forKey: .stickyWindowOpacity) ?? 0.95
        openMiniBoardOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .openMiniBoardOnLaunch) ?? false
        enableDesktopNotifications = try c.decodeIfPresent(Bool.self, forKey: .enableDesktopNotifications) ?? true
        enableInAppToasts = try c.decodeIfPresent(Bool.self, forKey: .enableInAppToasts) ?? true
        enableSound = try c.decodeIfPresent(Bool.self, forKey: .enableSound) ?? true
        soundName = try c.decodeIfPresent(String.self, forKey: .soundName) ?? "Glass"
        preReminderMenuBarOnly = try c.decodeIfPresent(Bool.self, forKey: .preReminderMenuBarOnly) ?? false
        enableDailySummary = try c.decodeIfPresent(Bool.self, forKey: .enableDailySummary) ?? true
        dailySummaryHour = try c.decodeIfPresent(Int.self, forKey: .dailySummaryHour) ?? 9
        dailySummaryMinute = try c.decodeIfPresent(Int.self, forKey: .dailySummaryMinute) ?? 0
        lastWindowMode = try c.decodeIfPresent(WindowDisplayMode.self, forKey: .lastWindowMode) ?? .mainCalendar
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        startMinimizedToMenuBar = try c.decodeIfPresent(Bool.self, forKey: .startMinimizedToMenuBar) ?? false
        isMiniBoardPinnedOnTop = try c.decodeIfPresent(Bool.self, forKey: .isMiniBoardPinnedOnTop) ?? true
    }
}

struct InAppToast: Identifiable, Equatable, Sendable {
    let id: UUID = UUID()
    let title: String
    let subtitle: String
    let category: EventCategory
    let eventID: UUID?
    let createdAt: Date = Date()
}

enum StickyNoteColor: String, CaseIterable, Identifiable, Codable, Sendable {
    case yellow = "노랑"
    case blue = "파랑"
    case green = "초록"
    case purple = "보라"
    case neutral = "기본"

    var id: String { rawValue }

    var fillColor: Color {
        switch self {
        case .yellow: return Color.yellow.opacity(0.13)
        case .blue: return Color.blue.opacity(0.10)
        case .green: return Color.green.opacity(0.10)
        case .purple: return Color.purple.opacity(0.10)
        case .neutral: return Color.primary.opacity(0.05)
        }
    }

    var borderColor: Color {
        switch self {
        case .yellow: return Color.orange.opacity(0.28)
        case .blue: return Color.blue.opacity(0.24)
        case .green: return Color.green.opacity(0.24)
        case .purple: return Color.purple.opacity(0.24)
        case .neutral: return Color.primary.opacity(0.10)
        }
    }

    var dotColor: Color {
        switch self {
        case .yellow: return .orange
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .neutral: return .secondary
        }
    }

    func next() -> StickyNoteColor {
        let all = Self.allCases
        guard let idx = all.firstIndex(of: self) else { return .yellow }
        return all[(idx + 1) % all.count]
    }
}

struct StickyNote: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var color: StickyNoteColor = .yellow
    var updatedAt: Date = Date()
}

struct PersistedData: Codable, Sendable {
    var events: [ScheduleEvent]
    var todos: [TodoItem]
    var settings: AppSettings
    var quickMemoText: String = ""
    var stickyNotes: [StickyNote] = []

    enum CodingKeys: String, CodingKey {
        case events, todos, settings, quickMemoText, stickyNotes
    }

    init(
        events: [ScheduleEvent],
        todos: [TodoItem],
        settings: AppSettings,
        quickMemoText: String = "",
        stickyNotes: [StickyNote] = []
    ) {
        self.events = events
        self.todos = todos
        self.settings = settings
        self.quickMemoText = quickMemoText
        self.stickyNotes = stickyNotes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        events = try c.decodeIfPresent([ScheduleEvent].self, forKey: .events) ?? []
        todos = try c.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        quickMemoText = try c.decodeIfPresent(String.self, forKey: .quickMemoText) ?? ""
        stickyNotes = try c.decodeIfPresent([StickyNote].self, forKey: .stickyNotes) ?? []
    }
}
