import Combine
import Foundation

@MainActor
final class CalendarStore: ObservableObject {
    @Published var events: [ScheduleEvent] = []
    @Published var todos: [TodoItem] = []
    @Published var settings: AppSettings = AppSettings()
    @Published var quickMemoText: String = ""
    @Published var stickyNotes: [StickyNote] = []

    @Published var selectedDate: Date = Date()
    @Published var viewMode: CalendarViewMode = .month
    @Published var menuBarTitleText: String = "캘린더"
    @Published var isAILoading: Bool = false
    @Published var aiBannerMessage: String? = nil
    var hasInitializedWindows: Bool = false

    private let fileURL: URL
    private var menuBarTimer: Timer?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = appSupport.appendingPathComponent("MyCalendar", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = folder.appendingPathComponent("data.json")
        load()
        refreshMenuBarTitle()
        menuBarTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMenuBarTitle()
            }
        }
    }

    // MARK: - Persistence

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            seedInitialData()
            save()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(PersistedData.self, from: data)
            self.events = decoded.events
            self.todos = decoded.todos
            self.settings = decoded.settings
            self.quickMemoText = decoded.quickMemoText
            if decoded.stickyNotes.isEmpty && !decoded.quickMemoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.stickyNotes = [StickyNote(title: "빠른 메모", content: decoded.quickMemoText, color: .yellow)]
            } else {
                self.stickyNotes = decoded.stickyNotes
            }
        } catch {
            seedInitialData()
            save()
        }
    }

    func save() {
        do {
            let payload = PersistedData(
                events: events,
                todos: todos,
                settings: settings,
                quickMemoText: quickMemoText,
                stickyNotes: stickyNotes
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Silently ignore write errors in UI layer
        }
        refreshMenuBarTitle()
    }

    func refreshMenuBarTitle() {
        let nextTitle = menuBarTitle(at: Date())
        if menuBarTitleText != nextTitle {
            menuBarTitleText = nextTitle
        }
    }

    // MARK: - Event CRUD

    func addEventWithAI(prompt: String) async -> ScheduleEvent? {
        isAILoading = true
        defer { isAILoading = false }
        do {
            let parsed = try await AIService.shared.parseNaturalLanguage(
                prompt: prompt,
                baseDate: selectedDate,
                apiKey: settings.geminiApiKey
            )
            let newEvent = ScheduleEvent(
                title: parsed.title,
                notes: parsed.notes,
                startDate: parsed.startDate,
                endDate: parsed.endDate,
                category: parsed.category,
                linkedFolderPath: parsed.linkedFolderPath
            )
            addEvent(newEvent)
            aiBannerMessage = "✨ AI 일정 등록 완료: \(parsed.title)"
            return newEvent
        } catch {
            aiBannerMessage = "❌ AI 일정 등록 실패: \(error.localizedDescription)"
            return nil
        }
    }

    func requestFolderAISummary(for eventID: UUID) async {
        guard let index = events.firstIndex(where: { $0.id == eventID }),
              let folderPath = events[index].linkedFolderPath, !folderPath.isEmpty else { return }
        isAILoading = true
        defer { isAILoading = false }
        let summary = await AIService.shared.summarizeFolder(folderPath: folderPath, apiKey: settings.geminiApiKey)
        events[index].aiSummary = summary
        save()
    }

    func addEvent(_ event: ScheduleEvent) {
        events.append(event)
        events.sort { $0.startDate < $1.startDate }
        save()
    }

    func updateEvent(_ event: ScheduleEvent) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index] = event
        events.sort { $0.startDate < $1.startDate }
        // Sync completion with linked todo if applicable
        if let todoID = event.linkedTodoID,
           let todoIndex = todos.firstIndex(where: { $0.id == todoID }) {
            todos[todoIndex].isCompleted = event.isCompleted
        }
        save()
    }

    func deleteEvent(_ id: UUID) {
        if let event = events.first(where: { $0.id == id }),
           let todoID = event.linkedTodoID,
           let todoIndex = todos.firstIndex(where: { $0.id == todoID }) {
            todos[todoIndex].scheduledEventID = nil
        }
        events.removeAll { $0.id == id }
        save()
    }

    func toggleEventCompletion(_ id: UUID, on date: Date = Date()) {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        if events[index].recurrence == .none {
            events[index].isCompleted.toggle()
            let completed = events[index].isCompleted
            if let todoID = events[index].linkedTodoID,
               let todoIndex = todos.firstIndex(where: { $0.id == todoID }) {
                todos[todoIndex].isCompleted = completed
            }
        } else {
            let key = ScheduleEvent.dateKey(for: date)
            if events[index].completedDates.contains(key) {
                events[index].completedDates.remove(key)
            } else {
                events[index].completedDates.insert(key)
            }
        }
        save()
    }

    func moveEvent(_ id: UUID, to newStartDate: Date) {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        let duration = events[index].endDate.timeIntervalSince(events[index].startDate)
        events[index].startDate = newStartDate
        events[index].endDate = newStartDate.addingTimeInterval(max(900, duration))
        events.sort { $0.startDate < $1.startDate }
        save()
    }

    // MARK: - Todo CRUD & Drag-Drop Scheduling

    func addTodo(_ todo: TodoItem) {
        todos.insert(todo, at: 0)
        save()
    }

    func updateTodo(_ todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index] = todo
        if let eventID = todo.scheduledEventID,
           let eventIndex = events.firstIndex(where: { $0.id == eventID }) {
            events[eventIndex].isCompleted = todo.isCompleted
            events[eventIndex].title = todo.title
            events[eventIndex].category = todo.category
        }
        save()
    }

    func deleteTodo(_ id: UUID) {
        todos.removeAll { $0.id == id }
        save()
    }

    func toggleTodoCompletion(_ id: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].isCompleted.toggle()
        let completed = todos[index].isCompleted
        if let eventID = todos[index].scheduledEventID,
           let eventIndex = events.firstIndex(where: { $0.id == eventID }) {
            events[eventIndex].isCompleted = completed
        }
        save()
    }

    func moveTodoScope(_ id: UUID, to scope: TodoScope) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].scope = scope
        save()
    }

    // MARK: - Sticky Notes CRUD

    func addStickyNote(title: String = "", content: String = "", color: StickyNoteColor = .yellow) {
        let note = StickyNote(title: title, content: content, color: color, updatedAt: Date())
        stickyNotes.insert(note, at: 0)
        save()
    }

    func updateStickyNote(_ note: StickyNote) {
        guard let index = stickyNotes.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = note
        updated.updatedAt = Date()
        stickyNotes[index] = updated
        save()
    }

    func deleteStickyNote(_ id: UUID) {
        stickyNotes.removeAll { $0.id == id }
        save()
    }

    @discardableResult
    func scheduleTodo(_ todoID: UUID, at startDate: Date) -> ScheduleEvent? {
        guard let index = todos.firstIndex(where: { $0.id == todoID }) else { return nil }
        let todo = todos[index]
        let endDate = startDate.addingTimeInterval(TimeInterval(max(15, todo.estimatedMinutes) * 60))

        // If already scheduled, move existing event instead of duplicating
        if let existingEventID = todo.scheduledEventID,
           let eventIndex = events.firstIndex(where: { $0.id == existingEventID }) {
            events[eventIndex].startDate = startDate
            events[eventIndex].endDate = endDate
            events.sort { $0.startDate < $1.startDate }
            save()
            return events[eventIndex]
        }

        let newEvent = ScheduleEvent(
            title: todo.title,
            notes: todo.notes,
            startDate: startDate,
            endDate: endDate,
            category: todo.category,
            reminderOffsets: [.tenMin, .atTime],
            isCompleted: todo.isCompleted,
            linkedTodoID: todo.id
        )
        events.append(newEvent)
        events.sort { $0.startDate < $1.startDate }
        todos[index].scheduledEventID = newEvent.id
        save()
        return newEvent
    }

    @discardableResult
    func handleDropPayload(_ payload: String, at targetDate: Date) -> Bool {
        if payload.hasPrefix("todo:"),
           let uuid = UUID(uuidString: String(payload.dropFirst(5))) {
            return scheduleTodo(uuid, at: targetDate) != nil
        }
        if payload.hasPrefix("event:"),
           let uuid = UUID(uuidString: String(payload.dropFirst(6))) {
            moveEvent(uuid, to: targetDate)
            return true
        }
        return false
    }

    // MARK: - Queries & Summary

    func holiday(on date: Date) -> String? {
        KoreanHolidayService.holidayName(for: date)
    }

    func isHoliday(_ date: Date) -> Bool {
        KoreanHolidayService.isHoliday(date)
    }

    func events(on date: Date) -> [ScheduleEvent] {
        return events.compactMap { event in
            guard event.occurs(on: date) else { return nil }
            return event.instance(for: date)
        }.sorted { $0.startDate < $1.startDate }
    }

    func todos(on date: Date) -> [TodoItem] {
        let cal = Calendar.current
        let targetDay = cal.startOfDay(for: date)
        return todos.filter { todo in
            switch todo.scope {
            case .today:
                let base = todo.dueDate ?? todo.createdAt
                return cal.isDate(base, inSameDayAs: targetDay) || (cal.isDateInToday(targetDay) && cal.isDateInToday(base))
            case .thisWeek:
                let base = todo.dueDate ?? todo.createdAt
                guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: base) else {
                    return cal.isDate(base, inSameDayAs: targetDay)
                }
                return weekInterval.contains(targetDay)
            case .thisMonth:
                let base = todo.dueDate ?? todo.createdAt
                guard let monthInterval = cal.dateInterval(of: .month, for: base) else {
                    return cal.isDate(base, inSameDayAs: targetDay)
                }
                return monthInterval.contains(targetDay)
            }
        }
    }

    func events(from start: Date, to end: Date) -> [ScheduleEvent] {
        let cal = Calendar.current
        var results: [ScheduleEvent] = []
        var cur = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)

        while cur <= endDay {
            let dayEvents = events(on: cur)
            for e in dayEvents {
                if !results.contains(where: { $0.id == e.id && cal.isDate($0.startDate, inSameDayAs: e.startDate) }) {
                    results.append(e)
                }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cur) else { break }
            cur = next
        }
        return results.sorted { $0.startDate < $1.startDate }
    }

    func remainingEventsToday() -> [ScheduleEvent] {
        let now = Date()
        return events(on: now).filter { event in
            event.periodType != .thisWeek && event.periodType != .thisMonth && !event.isCompleted && event.endDate > now
        }.sorted { $0.startDate < $1.startDate }
    }

    func upcomingEventsWithin(minutes: Int) -> [ScheduleEvent] {
        let now = Date()
        let horizon = now.addingTimeInterval(TimeInterval(minutes * 60))
        return events(on: now).filter {
            !$0.isCompleted && $0.startDate >= now.addingTimeInterval(-60) && $0.startDate <= horizon
        }.sorted { $0.startDate < $1.startDate }
    }

    func activeEventsNow() -> [ScheduleEvent] {
        let now = Date()
        return events(on: now).filter {
            !$0.isCompleted && $0.startDate <= now && $0.endDate > now
        }.sorted { $0.startDate < $1.startDate }
    }

    func dueOrOverdueTodos() -> [TodoItem] {
        let cal = Calendar.current
        let endOfToday = cal.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
        return todos.filter { todo in
            guard !todo.isCompleted else { return false }
            if todo.scope == .today {
                return (todo.dueDate ?? todo.createdAt) <= endOfToday
            }
            if let due = todo.dueDate {
                return due <= endOfToday
            }
            return false
        }
    }

    func todayCompletionProgress() -> (completed: Int, total: Int) {
        let todayEvents = events(on: Date()).filter { $0.periodType != .thisWeek && $0.periodType != .thisMonth }
        let todayTodos = todos.filter { $0.scope == .today }
        let total = todayEvents.count + todayTodos.count
        let completed = todayEvents.filter(\.isCompleted).count + todayTodos.filter(\.isCompleted).count
        return (completed, total)
    }

    func menuBarTitle(at now: Date = Date()) -> String {
        if let active = activeEventsNow().first {
            let minsLeft = max(1, Int(ceil(active.endDate.timeIntervalSince(now) / 60)))
            return "\(active.title) (\(minsLeft)분 남음)"
        }
        if let next = remainingEventsToday().first(where: { $0.startDate > now }) {
            let minsUntil = max(1, Int(ceil(next.startDate.timeIntervalSince(now) / 60)))
            if minsUntil <= 180 {
                return "\(next.title) · \(minsUntil)분 후"
            }
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return "\(f.string(from: next.startDate)) \(next.title)"
        }
        // If no upcoming calendar event, check upcoming due todos today
        let cal = Calendar.current
        let upcomingDueTodos = todos.filter {
            !$0.isCompleted && ($0.dueDate.map { cal.isDateInToday($0) && $0 > now } ?? false)
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        if let nextTodo = upcomingDueTodos.first, let due = nextTodo.dueDate {
            let minsUntil = max(1, Int(ceil(due.timeIntervalSince(now) / 60)))
            if minsUntil <= 180 {
                return "마감: \(nextTodo.title) · \(minsUntil)분 전"
            }
        }
        let todayTodoCount = todos.filter { !$0.isCompleted && $0.scope == .today }.count
        if todayTodoCount > 0 {
            return "오늘 할 일 \(todayTodoCount)"
        }
        return "캘린더"
    }

    // MARK: - Navigation

    func navigate(by step: Int) {
        let cal = Calendar.current
        switch viewMode {
        case .day:
            selectedDate = cal.date(byAdding: .day, value: step, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = cal.date(byAdding: .weekOfYear, value: step, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = cal.date(byAdding: .month, value: step, to: selectedDate) ?? selectedDate
        }
    }

    // MARK: - Initial Sample Data

    private func seedInitialData() {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let baseHour = min(max(hour + 1, 9), 20)

        let start1 = cal.date(bySettingHour: baseHour, minute: 0, second: 0, of: now) ?? now
        let start2 = cal.date(bySettingHour: min(baseHour + 2, 22), minute: 0, second: 0, of: now) ?? now

        events = [
            ScheduleEvent(
                title: "집중 업무 타임블록",
                notes: "핵심 작업 처리 및 진행 상황 정리",
                startDate: start1,
                endDate: start1.addingTimeInterval(3600),
                category: .work,
                reminderOffsets: [.tenMin, .atTime]
            ),
            ScheduleEvent(
                title: "저녁 스트레칭 & 산책",
                notes: "가볍게 리프레시하기",
                startDate: start2,
                endDate: start2.addingTimeInterval(2700),
                category: .health,
                reminderOffsets: [.fiveMin, .atTime]
            )
        ]

        todos = [
            TodoItem(
                title: "왼쪽 할 일을 타임라인으로 드래그해 배치하기",
                notes: "원하는 시간대에 놓으면 자동으로 타임블록이 생성됩니다.",
                dueDate: now,
                estimatedMinutes: 30,
                priority: .high,
                category: .work,
                scope: .today
            ),
            TodoItem(
                title: "주간 목표 점검 및 정리",
                dueDate: cal.date(byAdding: .day, value: 1, to: now),
                estimatedMinutes: 45,
                priority: .medium,
                category: .study,
                scope: .thisWeek
            ),
            TodoItem(
                title: "독서 30분",
                estimatedMinutes: 30,
                priority: .low,
                category: .personal,
                scope: .today
            )
        ]

        stickyNotes = [
            StickyNote(
                title: "업무 메모",
                content: "• 미팅 전 핵심 안건 3줄 정리\n• 금요일 오후 주간 리포트 공유",
                color: .yellow
            )
        ]
    }
}
