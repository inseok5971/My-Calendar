import SwiftUI

struct DayTimelineView: View {
    @EnvironmentObject private var store: CalendarStore

    let onCreateEvent: (Date) -> Void
    let onEditEvent: (ScheduleEvent) -> Void
    var onEditTodo: ((TodoItem) -> Void)? = nil

    @StateObject private var targetedHour = StateBox<Int?>(nil)

    private let hourHeight: CGFloat = 64
    private let labelWidth: CGFloat = 56

    private var dayEvents: [ScheduleEvent] {
        store.events(on: store.selectedDate)
    }

    private var allDayEvents: [ScheduleEvent] {
        dayEvents.filter { $0.periodType != .timed }
    }

    private var timedEvents: [ScheduleEvent] {
        dayEvents.filter { $0.periodType == .timed }
    }

    private var dayTodos: [TodoItem] {
        store.todos(on: store.selectedDate)
    }

    var body: some View {
        let holiday = store.holiday(on: store.selectedDate)
        VStack(spacing: 0) {
            if !allDayEvents.isEmpty || !dayTodos.isEmpty || holiday != nil {
                allDayHeader
                Divider()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Hour grid rows
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                hourRow(hour: hour)
                                    .id(hour)
                            }
                        }

                        // Event blocks overlay
                        GeometryReader { geo in
                            let contentWidth = max(120, geo.size.width - labelWidth - 20)
                            ForEach(timedEvents) { event in
                                eventBlock(event: event, availableWidth: contentWidth)
                            }
                        }

                        // Current time line
                        if Calendar.current.isDateInToday(store.selectedDate) {
                            currentTimeIndicator
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.trailing, 12)
                }
                .onAppear {
                    let targetHour = max(0, Calendar.current.component(.hour, from: Date()) - 2)
                    proxy.scrollTo(targetHour, anchor: .top)
                }
            }
        }
        .background(Color.clear)
    }

    private var allDayHeader: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("종일/할 일")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .trailing)
                .padding(.trailing, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let holiday = store.holiday(on: store.selectedDate) {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 9))
                            Text("공휴일: \(holiday)")
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(Color.red.opacity(0.18))
                        )
                        .foregroundStyle(Color.red)
                    }

                    ForEach(allDayEvents) { event in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(event.category.color)
                                .frame(width: 6, height: 6)
                            Text(event.title)
                                .font(.caption.weight(.medium))
                            Text(event.periodType.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(event.category.color.opacity(0.18))
                        )
                        .onTapGesture {
                            onEditEvent(event)
                        }
                    }

                    ForEach(dayTodos) { todo in
                        HStack(spacing: 6) {
                            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 8))
                                .foregroundStyle(todo.category.color)
                            Text(todo.title)
                                .font(.caption.weight(.medium))
                                .strikethrough(todo.isCompleted)
                                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(todo.category.color.opacity(todo.isCompleted ? 0.08 : 0.16))
                        )
                        .onTapGesture {
                            if let onEditTodo {
                                onEditTodo(todo)
                            } else {
                                store.toggleTodoCompletion(todo.id)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.trailing, 14)
        .background(Color.primary.opacity(0.02))
    }

    private func hourRow(hour: Int) -> some View {
        let isTargeted = targetedHour.value == hour
        return HStack(alignment: .top, spacing: 0) {
            Text(String(format: "%02d:00", hour))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .trailing)
                .padding(.trailing, 10)
                .offset(y: -7)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    Divider()
                        .opacity(0.6)
                    Spacer()
                }

                if isTargeted {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        )
                        .padding(.vertical, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: hourHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                onCreateEvent(dateFor(hour: hour))
            }
            .dropDestination(for: String.self) { items, _ in
                guard let payload = items.first else { return false }
                return store.handleDropPayload(payload, at: dateFor(hour: hour))
            } isTargeted: { hovering in
                targetedHour.value = hovering ? hour : (targetedHour.value == hour ? nil : targetedHour.value)
            }
        }
    }

    private func eventBlock(event: ScheduleEvent, availableWidth: CGFloat) -> some View {
        let cal = Calendar.current
        let startComps = cal.dateComponents([.hour, .minute], from: event.startDate)
        let startMinutes = CGFloat((startComps.hour ?? 0) * 60 + (startComps.minute ?? 0))
        let yOffset = (startMinutes / 60.0) * hourHeight
        let blockHeight = max(30, (CGFloat(event.durationMinutes) / 60.0) * hourHeight - 3)

        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.category.color)
                .frame(width: 4)
                .padding(.vertical, 4)

            HStack(alignment: .top, spacing: 10) {
                PillToggleCheck(
                    isOn: event.isCompleted,
                    tintColor: event.category.color,
                    action: { store.toggleEventCompletion(event.id) }
                )
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(event.title)
                            .font(.callout.weight(.medium))
                            .strikethrough(event.isCompleted)
                            .foregroundStyle(event.isCompleted ? .secondary : .primary)
                            .lineLimit(1)

                        if !event.reminderOffsets.isEmpty && !event.isCompleted {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(event.category.color)
                        }
                    }

                    if blockHeight >= 44 {
                        Text("\(Self.timeFormatter.string(from: event.startDate)) – \(Self.timeFormatter.string(from: event.endDate))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Text(event.category.rawValue)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(event.category.color.opacity(0.15)))
                    .foregroundStyle(event.category.color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(width: availableWidth, height: blockHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(event.category.color.opacity(event.isCompleted ? 0.06 : 0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(event.category.color.opacity(0.3), lineWidth: 1)
        )
        .offset(x: labelWidth + 8, y: yOffset + 1.5)
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

    private var currentTimeIndicator: some View {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minutes = CGFloat((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
        let yOffset = (minutes / 60.0) * hourHeight

        return HStack(spacing: 0) {
            Spacer().frame(width: labelWidth - 4)
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(Color.red)
                .frame(height: 1.5)
        }
        .offset(y: yOffset - 4)
        .allowsHitTesting(false)
    }

    private func dateFor(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: store.selectedDate) ?? store.selectedDate
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
