import SwiftUI

struct MonthCalendarView: View {
    @EnvironmentObject private var store: CalendarStore

    let onCreateEvent: (Date) -> Void
    let onEditEvent: (ScheduleEvent) -> Void
    var onEditTodo: ((TodoItem) -> Void)? = nil

    @StateObject private var targetedDate = StateBox<Date?>(nil)

    private let weekdayHeaders = ["일", "월", "화", "수", "목", "금", "토"]

    private var monthGridDates: [Date] {
        let cal = Calendar.current
        guard let monthInterval = cal.dateInterval(of: .month, for: store.selectedDate) else {
            return []
        }
        let firstDay = monthInterval.start
        let weekday = cal.component(.weekday, from: firstDay) // 1 = Sunday ... 7 = Saturday
        let leadingDays = weekday - 1
        guard let gridStart = cal.date(byAdding: .day, value: -leadingDays, to: firstDay) else {
            return []
        }
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private var monthWeeks: [[Date]] {
        stride(from: 0, to: monthGridDates.count, by: 7).compactMap { i -> [Date]? in
            let end = min(i + 7, monthGridDates.count)
            guard i < end else { return nil }
            return Array(monthGridDates[i..<end])
        }
    }

    private func weeklyTodos(for weekDays: [Date]) -> [TodoItem] {
        guard let firstDay = weekDays.first else { return [] }
        let cal = Calendar.current
        return store.todos.filter { todo in
            guard todo.scope == .thisWeek else { return false }
            let base = todo.dueDate ?? todo.createdAt
            return cal.isDate(base, equalTo: firstDay, toGranularity: .weekOfYear) &&
                   cal.isDate(base, equalTo: firstDay, toGranularity: .yearForWeekOfYear)
        }
    }

    private func weeklyEvents(for weekDays: [Date]) -> [ScheduleEvent] {
        guard let firstDay = weekDays.first else { return [] }
        let cal = Calendar.current
        return store.events.filter { event in
            guard event.periodType == .thisWeek else { return false }
            return cal.isDate(event.startDate, equalTo: firstDay, toGranularity: .weekOfYear) &&
                   cal.isDate(event.startDate, equalTo: firstDay, toGranularity: .yearForWeekOfYear)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Weekday header
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { label in
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(label == "일" ? .red.opacity(0.8) : (label == "토" ? .blue.opacity(0.8) : .secondary))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }

            Divider()

            // 6 Weeks Rows
            GeometryReader { geo in
                let rowHeight = max(88, geo.size.height / CGFloat(max(1, monthWeeks.count)))
                VStack(spacing: 0) {
                    ForEach(Array(monthWeeks.enumerated()), id: \.offset) { _, weekDays in
                        weekRowView(weekDays: weekDays, height: rowHeight)
                    }
                }
            }
        }
        .background(Color.clear)
    }

    private func weekRowView(weekDays: [Date], height: CGFloat) -> some View {
        let weeklyTasks = weeklyTodos(for: weekDays)
        let weeklyEventsList = weeklyEvents(for: weekDays)
        let hasWeekly = !weeklyTasks.isEmpty || !weeklyEventsList.isEmpty

        return VStack(spacing: 0) {
            // 1. Date headers for all 7 days of this week row
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { date in
                    let cal = Calendar.current
                    let isCurrentMonth = cal.isDate(date, equalTo: store.selectedDate, toGranularity: .month)
                    let isToday = cal.isDateInToday(date)
                    let dueTodosCount = store.todos(on: date).filter { $0.scope == .today && !$0.isCompleted }.count
                    cellHeader(date: date, isCurrentMonth: isCurrentMonth, isToday: isToday, dueTodosCount: dueTodosCount)
                        .padding(.horizontal, 5)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.selectedDate = date
                        }
                        .onTapGesture(count: 2) {
                            store.selectedDate = date
                            store.viewMode = .day
                        }
                }
            }

            // 2. Spanning bar(s) for the week — BELOW the date numbers!
            if hasWeekly {
                VStack(spacing: 2) {
                    ForEach(weeklyEventsList) { event in
                        weeklyEventSpanningBar(event: event)
                    }
                    ForEach(weeklyTasks) { todo in
                        weeklyTodoSpanningBar(todo: todo)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
            }

            // 3. Daily event cells for the 7 days
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { date in
                    monthCellDaily(date: date)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .overlay(
            GeometryReader { geo in
                let colWidth = geo.size.width / 7.0
                Path { path in
                    for i in 1..<7 {
                        let x = colWidth * CGFloat(i)
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    path.move(to: CGPoint(x: 0, y: geo.size.height))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                }
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
        )
    }

    private func weeklyTodoSpanningBar(todo: TodoItem) -> some View {
        HStack(spacing: 6) {
            Button {
                store.toggleTodoCompletion(todo.id)
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(todo.isCompleted ? .secondary : todo.category.color)
            }
            .buttonStyle(.plain)

            Text("주간 할 일")
                .font(.system(size: 8.5, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Capsule().fill(todo.category.color.opacity(0.25)))
                .foregroundStyle(todo.category.color)

            if let folderPath = todo.linkedFolderPath, !folderPath.isEmpty {
                Image(systemName: "folder.fill")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.22))
            }

            Text(todo.title)
                .font(.system(size: 11.5, weight: .semibold))
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            if let due = todo.dueDate {
                Text(Self.shortDateFormatter.string(from: due))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(todo.category.color.opacity(todo.isCompleted ? 0.08 : 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(todo.category.color.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onEditTodo?(todo)
        }
    }

    private func weeklyEventSpanningBar(event: ScheduleEvent) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(event.category.color)
                .frame(width: 6, height: 6)

            Text("주간 일정")
                .font(.system(size: 8.5, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Capsule().fill(event.category.color.opacity(0.25)))
                .foregroundStyle(event.category.color)

            if event.linkedFolderPath != nil {
                Image(systemName: "folder.fill")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.22))
            }

            Text(event.title)
                .font(.system(size: 11.5, weight: .semibold))
                .strikethrough(event.isCompleted)
                .foregroundStyle(event.isCompleted ? .secondary : .primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(event.category.color.opacity(0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(event.category.color.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onEditEvent(event)
        }
    }

    private func monthCellDaily(date: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(date, inSameDayAs: store.selectedDate)
        // Daily events and daily todos (weekly items are spanned above as one big bar!)
        let dayEvents = store.events(on: date).filter { $0.periodType != .thisWeek }
        let dayTodos = store.todos(on: date).filter { $0.scope == .today }
        let isTargeted = targetedDate.value.map { cal.isDate($0, inSameDayAs: date) } ?? false

        return VStack(alignment: .leading, spacing: 2) {
            cellItemsList(dayEvents: dayEvents, dayTodos: dayTodos)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            isTargeted
                ? Color.accentColor.opacity(0.14)
                : (isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            store.selectedDate = date
            store.viewMode = .day
        }
        .onTapGesture {
            store.selectedDate = date
        }
        .contextMenu {
            Button("이 날짜에 새 일정 추가") {
                let defaultStart = cal.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
                onCreateEvent(defaultStart)
            }
            Button("일간 뷰로 보기") {
                store.selectedDate = date
                store.viewMode = .day
            }
        }
        .dropDestination(for: String.self) { items, _ in
            handleDrop(items: items, onto: date)
        } isTargeted: { hovering in
            targetedDate.value = hovering ? date : (isTargeted ? nil : targetedDate.value)
        }
    }

    private func handleDrop(items: [String], onto date: Date) -> Bool {
        guard let payload = items.first else { return false }
        let target = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        return store.handleDropPayload(payload, at: target)
    }

    private func cellHeader(date: Date, isCurrentMonth: Bool, isToday: Bool, dueTodosCount: Int) -> some View {
        let cal = Calendar.current
        let dayNum = cal.component(.day, from: date)
        let weekday = cal.component(.weekday, from: date)
        let holidayName = store.holiday(on: date)
        let isHoliday = (holidayName != nil)

        let dayColor: Color
        if isToday {
            dayColor = Color.white
        } else if isHoliday || weekday == 1 {
            dayColor = isCurrentMonth ? Color.red : Color.red.opacity(0.4)
        } else if weekday == 7 {
            dayColor = isCurrentMonth ? Color.blue : Color.blue.opacity(0.4)
        } else {
            dayColor = isCurrentMonth ? Color.primary : Color.secondary.opacity(0.45)
        }

        return HStack(spacing: 4) {
            Text("\(dayNum)")
                .font(.caption.weight(isToday ? .bold : .medium))
                .foregroundStyle(dayColor)
                .frame(width: 22, height: 22)
                .background(
                    Circle().fill(isToday ? Color.accentColor : Color.clear)
                )

            if let holidayName {
                Text(holidayName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isCurrentMonth ? Color.red : Color.red.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            if dueTodosCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "checklist")
                        .font(.system(size: 9))
                    Text("\(dueTodosCount)")
                        .font(.system(size: 10).monospacedDigit())
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.orange.opacity(0.12)))
            }
        }
    }

    private func cellItemsList(dayEvents: [ScheduleEvent], dayTodos: [TodoItem]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(dayEvents.prefix(3)) { event in
                HStack(spacing: 4) {
                    Circle()
                        .fill(event.category.color)
                        .frame(width: 5, height: 5)
                    if event.periodType == .timed {
                        Text(Self.timeFormatter.string(from: event.startDate))
                            .font(.system(size: 9).monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text(event.periodType == .allDay ? "종일" : event.periodType.rawValue)
                            .font(.system(size: 9).weight(.semibold))
                            .foregroundStyle(event.category.color)
                    }
                    if event.recurrence != .none {
                        Image(systemName: "repeat")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    if event.linkedFolderPath != nil {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 7.5))
                            .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.22))
                    }
                    Text(event.title)
                        .font(.system(size: 11, weight: .medium))
                        .strikethrough(event.isCompleted)
                        .foregroundStyle(event.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(event.category.color.opacity(event.periodType == .timed ? 0.14 : 0.22))
                )
                .onTapGesture {
                    onEditEvent(event)
                }
            }

            let remainingSlots = max(0, 4 - dayEvents.count)
            ForEach(dayTodos.prefix(remainingSlots)) { todo in
                HStack(spacing: 3) {
                    Button {
                        store.toggleTodoCompletion(todo.id)
                    } label: {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 9))
                            .foregroundStyle(todo.isCompleted ? .secondary : todo.category.color)
                    }
                    .buttonStyle(.plain)

                    if todo.scope == .thisWeek {
                        Text("주간")
                            .font(.system(size: 7.5, weight: .bold))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 0.5)
                            .background(Capsule().fill(todo.category.color.opacity(0.2)))
                            .foregroundStyle(todo.category.color)
                    } else if todo.scope == .thisMonth {
                        Text("월간")
                            .font(.system(size: 7.5, weight: .bold))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 0.5)
                            .background(Capsule().fill(todo.category.color.opacity(0.2)))
                            .foregroundStyle(todo.category.color)
                    }

                    if todo.linkedFolderPath != nil {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 7.5))
                            .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.22))
                    }

                    Text(todo.title)
                        .font(.system(size: 11, weight: .medium))
                        .strikethrough(todo.isCompleted)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(todo.category.color.opacity(todo.isCompleted ? 0.08 : 0.16))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onEditTodo?(todo)
                }
            }

            let totalCount = dayEvents.count + dayTodos.count
            if totalCount > 4 {
                Text("+\(totalCount - 4)개 더")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d(E)"
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()
}
