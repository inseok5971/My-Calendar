import SwiftUI

struct WeekTimelineView: View {
    @EnvironmentObject private var store: CalendarStore

    let onCreateEvent: (Date) -> Void
    let onEditEvent: (ScheduleEvent) -> Void
    var onEditTodo: ((TodoItem) -> Void)? = nil

    @StateObject private var targetedSlot = StateBox<SlotKey?>(nil)

    private let hourHeight: CGFloat = 54
    private let labelWidth: CGFloat = 52

    private struct SlotKey: Equatable {
        let dayIndex: Int
        let hour: Int
    }

    private var weekDays: [Date] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .weekOfYear, for: store.selectedDate) else {
            return [store.selectedDate]
        }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private var allDayEventsInWeek: [ScheduleEvent] {
        let cal = Calendar.current
        guard let firstDay = weekDays.first, let lastDay = weekDays.last else { return [] }
        let start = cal.startOfDay(for: firstDay)
        let end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: lastDay) ?? lastDay
        return store.events.filter { $0.periodType != .timed && $0.startDate <= end && $0.endDate >= start }
    }

    private var weeklyTodosInWeek: [TodoItem] {
        guard let firstDay = weekDays.first, let lastDay = weekDays.last else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: firstDay)
        let end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: lastDay) ?? lastDay
        return store.todos.filter { todo in
            guard todo.scope == .thisWeek else { return false }
            let base = todo.dueDate ?? todo.createdAt
            guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: base) else { return false }
            return weekInterval.contains(start) || (weekInterval.start <= end && weekInterval.end >= start)
        }
    }

    private var weeklyEventsInWeek: [ScheduleEvent] {
        guard let firstDay = weekDays.first, let lastDay = weekDays.last else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: firstDay)
        let end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: lastDay) ?? lastDay
        return store.events.filter { event in
            guard event.periodType == .thisWeek else { return false }
            guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: event.startDate) else { return false }
            return weekInterval.contains(start) || (weekInterval.start <= end && weekInterval.end >= start)
        }
    }

    private var hasAllDayOrTodosInWeek: Bool {
        if !weeklyTodosInWeek.isEmpty || !weeklyEventsInWeek.isEmpty { return true }
        if !allDayEventsInWeek.isEmpty { return true }
        for day in weekDays {
            if !store.todos(on: day).isEmpty { return true }
        }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            weekHeader
            Divider()
            if hasAllDayOrTodosInWeek {
                allDayWeekHeader
                Divider()
            }
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                hourRow(hour: hour)
                                    .id(hour)
                            }
                        }

                        // Events overlay per day column
                        GeometryReader { geo in
                            let colWidth = max(40, (geo.size.width - labelWidth) / CGFloat(max(1, weekDays.count)))
                            ForEach(Array(weekDays.enumerated()), id: \.offset) { dayIndex, day in
                                let dayEvents = store.events(on: day).filter { $0.periodType == .timed }
                                ForEach(dayEvents) { event in
                                    weekEventBlock(event: event, dayIndex: dayIndex, colWidth: colWidth)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
                .onAppear {
                    let targetHour = max(0, Calendar.current.component(.hour, from: Date()) - 2)
                    proxy.scrollTo(targetHour, anchor: .top)
                }
            }
        }
        .background(Color.clear)
    }

    private var weekHeader: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: labelWidth)

            ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                let cal = Calendar.current
                let isToday = cal.isDateInToday(day)
                let isSelected = cal.isDate(day, inSameDayAs: store.selectedDate)
                let count = store.events(on: day).count
                let holidayName = store.holiday(on: day)
                let isHoliday = (holidayName != nil)
                let weekday = cal.component(.weekday, from: day)

                let dayColor: Color = isToday
                    ? Color.white
                    : ((isHoliday || weekday == 1)
                        ? Color.red
                        : (weekday == 7 ? Color.blue : (isSelected ? Color.accentColor : Color.primary)))

                Button {
                    store.selectedDate = day
                } label: {
                    VStack(spacing: 3) {
                        Text(Self.weekdayFormatter.string(from: day))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(isToday ? Color.accentColor : (isHoliday || weekday == 1 ? Color.red : (weekday == 7 ? Color.blue : Color.secondary)))

                        HStack(spacing: 4) {
                            Text(Self.dayNumberFormatter.string(from: day))
                                .font(.callout.weight(isToday ? .bold : .medium))
                                .foregroundStyle(dayColor)
                                .frame(width: 26, height: 26)
                                .background(
                                    Circle()
                                        .fill(isToday ? Color.accentColor : (isSelected ? Color.accentColor.opacity(0.14) : Color.clear))
                                )
                        }

                        if let holidayName {
                            Text(holidayName)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.red)
                                .lineLimit(1)
                        } else if count > 0 {
                            Text("\(count)개")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(" ")
                                .font(.system(size: 10))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isToday ? Color.accentColor.opacity(0.04) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var allDayWeekHeader: some View {
        VStack(spacing: 3) {
            // Spanning full-width weekly bar(s) across the entire week header
            if !weeklyTodosInWeek.isEmpty || !weeklyEventsInWeek.isEmpty {
                HStack(spacing: 0) {
                    Text("주간")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: labelWidth, alignment: .trailing)
                        .padding(.trailing, 8)

                    VStack(spacing: 2) {
                        ForEach(weeklyEventsInWeek) { event in
                            HStack(spacing: 4) {
                                Circle().fill(event.category.color).frame(width: 6, height: 6)
                                Text("주간 일정").font(.system(size: 8, weight: .bold)).foregroundStyle(event.category.color)
                                Text(event.title).font(.system(size: 10.5, weight: .semibold)).lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 4).fill(event.category.color.opacity(0.18)))
                            .contentShape(Rectangle())
                            .onTapGesture { onEditEvent(event) }
                        }

                        ForEach(weeklyTodosInWeek) { todo in
                            HStack(spacing: 4) {
                                Button {
                                    store.toggleTodoCompletion(todo.id)
                                } label: {
                                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(todo.isCompleted ? .secondary : todo.category.color)
                                }
                                .buttonStyle(.plain)

                                Text("주간 할 일").font(.system(size: 8, weight: .bold)).foregroundStyle(todo.category.color)
                                Text(todo.title).font(.system(size: 10.5, weight: .semibold))
                                    .strikethrough(todo.isCompleted)
                                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 4).fill(todo.category.color.opacity(todo.isCompleted ? 0.08 : 0.16)))
                            .contentShape(Rectangle())
                            .onTapGesture { onEditTodo?(todo) }
                        }
                    }
                    .padding(.trailing, 8)
                }
            }

            // Day columns for daily all-day items
            HStack(spacing: 0) {
                Text("종일")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: labelWidth, alignment: .trailing)
                    .padding(.trailing, 8)

                HStack(spacing: 4) {
                    ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                        let dayAllDay = store.events(on: day).filter { $0.periodType != .timed && $0.periodType != .thisWeek }
                        let dayTodos = store.todos(on: day).filter { $0.scope != .thisWeek }
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(dayAllDay.prefix(2)) { event in
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(event.category.color)
                                        .frame(width: 5, height: 5)
                                    Text(event.title)
                                        .font(.system(size: 10, weight: .medium))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Capsule().fill(event.category.color.opacity(0.18)))
                                .onTapGesture {
                                    onEditEvent(event)
                                }
                            }

                            ForEach(dayTodos.prefix(2)) { todo in
                                HStack(spacing: 2) {
                                    Button {
                                        store.toggleTodoCompletion(todo.id)
                                    } label: {
                                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 8))
                                            .foregroundStyle(todo.isCompleted ? .secondary : todo.category.color)
                                    }
                                    .buttonStyle(.plain)

                                    Text(todo.title)
                                        .font(.system(size: 10, weight: .medium))
                                        .strikethrough(todo.isCompleted)
                                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Capsule().fill(todo.category.color.opacity(todo.isCompleted ? 0.08 : 0.16)))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onEditTodo?(todo)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .padding(.trailing, 8)
            }
        }
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.02))
    }

    private func hourRow(hour: Int) -> some View {
        HStack(spacing: 0) {
            Text(String(format: "%02d:00", hour))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .trailing)
                .padding(.trailing, 8)
                .offset(y: -7)

            ForEach(Array(weekDays.enumerated()), id: \.offset) { dayIndex, day in
                let slot = SlotKey(dayIndex: dayIndex, hour: hour)
                let isTargeted = targetedSlot.value == slot
                let isToday = Calendar.current.isDateInToday(day)

                ZStack {
                    Rectangle()
                        .fill(isToday ? Color.accentColor.opacity(0.02) : Color.clear)

                    if isTargeted {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
                            )
                            .padding(2)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: hourHeight)
                .overlay(alignment: .top) {
                    Divider().opacity(0.5)
                }
                .overlay(alignment: .leading) {
                    Divider().opacity(0.4)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onCreateEvent(dateFor(day: day, hour: hour))
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let payload = items.first else { return false }
                    return store.handleDropPayload(payload, at: dateFor(day: day, hour: hour))
                } isTargeted: { hovering in
                    targetedSlot.value = hovering ? slot : (targetedSlot.value == slot ? nil : targetedSlot.value)
                }
            }
        }
    }

    private func weekEventBlock(event: ScheduleEvent, dayIndex: Int, colWidth: CGFloat) -> some View {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: event.startDate)
        let startMinutes = CGFloat((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
        let yOffset = (startMinutes / 60.0) * hourHeight
        let blockHeight = max(24, (CGFloat(event.durationMinutes) / 60.0) * hourHeight - 2)
        let xOffset = labelWidth + CGFloat(dayIndex) * colWidth + 2

        return HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.category.color)
                .frame(width: 3)
                .padding(.vertical, 3)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Text(event.title)
                        .font(.caption.weight(.medium))
                        .strikethrough(event.isCompleted)
                        .foregroundStyle(event.isCompleted ? .secondary : .primary)
                        .lineLimit(1)

                    if !event.reminderOffsets.isEmpty && !event.isCompleted {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(event.category.color)
                    }
                }

                if blockHeight >= 36 {
                    Text(Self.timeFormatter.string(from: event.startDate))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .frame(width: max(30, colWidth - 4), height: blockHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(event.category.color.opacity(event.isCompleted ? 0.07 : 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(event.category.color.opacity(0.32), lineWidth: 1)
        )
        .offset(x: xOffset, y: yOffset + 1)
        .draggable("event:\(event.id.uuidString)")
        .onTapGesture {
            onEditEvent(event)
        }
        .contextMenu {
            Button(event.isCompleted ? "미완료로 표시" : "완료로 표시") {
                store.toggleEventCompletion(event.id)
            }
            Button("수정") {
                onEditEvent(event)
            }
            Divider()
            Button("삭제", role: .destructive) {
                store.deleteEvent(event.id)
            }
        }
    }

    private func dateFor(day: Date, hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "E"
        return f
    }()

    private static let dayNumberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
