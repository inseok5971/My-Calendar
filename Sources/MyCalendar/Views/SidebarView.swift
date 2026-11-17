import Combine
import SwiftUI

enum SidebarBoardTab: String, CaseIterable, Identifiable {
    case today = "오늘"
    case thisWeek = "이번 주"
    case thisMonth = "이번 달"
    case memo = "메모"

    var id: String { rawValue }
}

struct SidebarView: View {
    @EnvironmentObject private var store: CalendarStore
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.openWindow) private var openWindow

    @StateObject private var ui = SidebarUIState()

    @MainActor
    private final class SidebarUIState: ObservableObject {
        @Published var activeTab: SidebarBoardTab = .today
        @Published var quickTodoTitle: String = ""
        @Published var showCompletedTodos: Bool = false
        @Published var editingTodo: TodoItem?
        @Published var editingEvent: ScheduleEvent?
        @Published var isAddingTodoDetail: Bool = false
    }

    private var activeScope: TodoScope {
        switch ui.activeTab {
        case .today: return .today
        case .thisWeek: return .thisWeek
        case .thisMonth: return .thisMonth
        case .memo: return .today
        }
    }

    private var filteredEvents: [ScheduleEvent] {
        let cal = Calendar.current
        let events: [ScheduleEvent]
        if ui.activeTab == .today {
            events = store.events(on: Date()).filter { $0.periodType != .thisWeek && $0.periodType != .thisMonth }
        } else if ui.activeTab == .thisWeek {
            let startOfWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            let endOfWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date()
            events = store.events(from: startOfWeek, to: endOfWeek)
        } else if ui.activeTab == .thisMonth {
            let startOfMonth = cal.dateInterval(of: .month, for: Date())?.start ?? Date()
            let endOfMonth = cal.dateInterval(of: .month, for: Date())?.end ?? Date()
            events = store.events(from: startOfMonth, to: endOfMonth)
        } else {
            events = []
        }
        return events.filter { event in
            ui.showCompletedTodos ? true : !event.isCompleted
        }.sorted { $0.startDate < $1.startDate }
    }

    private var filteredTodos: [TodoItem] {
        store.todos.filter { todo in
            let matchesScope: Bool
            switch ui.activeTab {
            case .today:
                matchesScope = (todo.scope == .today)
            case .thisWeek:
                matchesScope = (todo.scope == .thisWeek)
            case .thisMonth:
                matchesScope = (todo.scope == .thisMonth)
            case .memo:
                matchesScope = false
            }
            let matchesDone = ui.showCompletedTodos ? true : !todo.isCompleted
            return matchesScope && matchesDone
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            todaySummaryCard
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Divider()

            Picker("보드", selection: $ui.activeTab) {
                ForEach(SidebarBoardTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            if ui.activeTab == .memo {
                StickyNotesBoardView()
            } else {
                todoHeader
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)

                quickAddBar
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        if filteredEvents.isEmpty && filteredTodos.isEmpty {
                            emptyTodoView
                        } else {
                            ForEach(Array(filteredEvents.enumerated()), id: \.element.id) { index, event in
                                EventRowCard(
                                    index: index + 1,
                                    event: event,
                                    onToggle: { store.toggleEventCompletion(event.id, on: event.startDate) },
                                    onEdit: { ui.editingEvent = event },
                                    onDelete: { store.deleteEvent(event.id) }
                                )
                            }

                            ForEach(Array(filteredTodos.enumerated()), id: \.element.id) { index, todo in
                                TodoRowCard(
                                    index: filteredEvents.count + index + 1,
                                    todo: todo,
                                    onToggle: { store.toggleTodoCompletion(todo.id) },
                                    onEdit: { ui.editingTodo = todo },
                                    onScheduleNow: { scheduleTodoAtNextSlot(todo) },
                                    onSwitchScope: {
                                        let next: TodoScope
                                        switch todo.scope {
                                        case .today: next = .thisWeek
                                        case .thisWeek: next = .thisMonth
                                        case .thisMonth: next = .today
                                        }
                                        store.moveTodoScope(todo.id, to: next)
                                    },
                                    onDelete: { store.deleteTodo(todo.id) }
                                )
                                .draggable("todo:\(todo.id.uuidString)")
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color.clear)
        .sheet(item: $ui.editingTodo) { todo in
            TodoEditorSheet(todo: todo) { updated in
                store.updateTodo(updated)
            } onDelete: {
                store.deleteTodo(todo.id)
            }
        }
        .sheet(item: $ui.editingEvent) { event in
            EventEditorSheet(event: event) { updated in
                store.updateEvent(updated)
            } onDelete: {
                store.deleteEvent(event.id)
            }
        }
        .sheet(isPresented: $ui.isAddingTodoDetail) {
            TodoEditorSheet(todo: nil, initialScope: activeScope) { newTodo in
                var item = newTodo
                item.scope = activeScope
                store.addTodo(item)
            }
        }
    }

    // MARK: - Today Summary Card

    private var todaySummaryCard: some View {
        let remaining = store.remainingEventsToday()
        let progress = store.todayCompletionProgress()
        let dueCount = store.dueOrOverdueTodos().count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("오늘의 요약", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let holiday = store.holiday(on: Date()) {
                    Text(holiday)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red.opacity(0.12)))
                }

                Spacer()

                Button {
                    notificationManager.sendDailySummaryNow(store: store)
                } label: {
                    Image(systemName: "bell.badge")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("오늘의 일정 요약 알림 보내기")
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("남은 일정")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(remaining.count)건")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }

                Divider()
                    .frame(height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text("마감/지연 할 일")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(dueCount)건")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(dueCount > 0 ? .orange : .primary)
                        .monospacedDigit()
                }

                Spacer()
            }

            if progress.total > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("오늘 완료율")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(progress.completed)/\(progress.total)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(progress.completed), total: Double(progress.total))
                        .tint(.accentColor)
                }
            }

            if let next = remaining.first {
                HStack(spacing: 6) {
                    Circle()
                        .fill(next.category.color)
                        .frame(width: 6, height: 6)
                    Text("다음: \(Self.timeFormatter.string(from: next.startDate)) \(next.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    // MARK: - Todo Header & Quick Add

    private var todoHeader: some View {
        let count = filteredEvents.count + filteredTodos.count
        return HStack {
            Text(activeScope.rawValue)
                .font(.subheadline.weight(.semibold))

            Text("\(count)")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.08)))

            Spacer()

            Button {
                ui.showCompletedTodos.toggle()
            } label: {
                Text(ui.showCompletedTodos ? "완료 숨기기" : "완료 포함")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                ui.isAddingTodoDetail = true
            } label: {
                Label("할 일 추가", systemImage: "plus.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help("새 할 일(스케줄러) 추가")
        }
    }

    private var quickAddBar: some View {
        HStack(spacing: 8) {
            TextField("\(activeScope.rawValue) 추가 (Enter)", text: $ui.quickTodoTitle)
                .textFieldStyle(.plain)
                .font(.callout)
                .onSubmit {
                    addQuickTodo()
                }

            if !ui.quickTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    addQuickTodo()
                } label: {
                    Image(systemName: "return")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var emptyTodoView: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("\(activeScope.rawValue)이 없습니다")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("위 입력창에 추가한 뒤 타임라인으로 드래그하세요.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func addQuickTodo() {
        let trimmed = ui.quickTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let cal = Calendar.current
        let now = Date()
        let dueDate: Date?
        switch activeScope {
        case .today:
            dueDate = now
        case .thisWeek:
            let startOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = cal.date(byAdding: .day, value: 6, to: startOfWeek) ?? now
            dueDate = cal.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek) ?? endOfWeek
        case .thisMonth:
            dueDate = (cal.dateInterval(of: .month, for: now)?.end ?? now).addingTimeInterval(-1)
        }
        store.addTodo(TodoItem(title: trimmed, dueDate: dueDate, scope: activeScope))
        ui.quickTodoTitle = ""
    }

    private func scheduleTodoAtNextSlot(_ todo: TodoItem) {
        let cal = Calendar.current
        let now = Date()
        let nextHour = (cal.component(.hour, from: now) + 1) % 24
        let targetDate = cal.date(bySettingHour: nextHour, minute: 0, second: 0, of: store.selectedDate) ?? now
        store.scheduleTodo(todo.id, at: targetDate)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
