import AppKit
import Combine
import SwiftUI

struct StickyNoteWidgetView: View {
    @EnvironmentObject private var store: CalendarStore
    @Environment(\.openWindow) private var openWindow
    @StateObject private var ui = WidgetUIState()

    @MainActor
    private final class WidgetUIState: ObservableObject {
        @Published var activeTab: SidebarBoardTab = .today
        @Published var quickTitle: String = ""
        @Published var editingEvent: ScheduleEvent?
        @Published var editingTodo: TodoItem?
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
        return events.filter { !$0.isCompleted }.sorted { $0.startDate < $1.startDate }
    }

    private var filteredTodos: [TodoItem] {
        store.todos.filter { todo in
            if todo.isCompleted { return false }
            switch ui.activeTab {
            case .today:
                return todo.scope == .today
            case .thisWeek:
                return todo.scope == .thisWeek
            case .thisMonth:
                return todo.scope == .thisMonth
            case .memo:
                return false
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            widgetHeader
            Divider()
            nextMeetingBanner
            Divider()

            Picker("보드", selection: $ui.activeTab) {
                ForEach(SidebarBoardTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if ui.activeTab == .memo {
                StickyNotesBoardView()
            } else {
                HStack(spacing: 6) {
                    TextField("\(activeScope.rawValue) 추가 (Enter)", text: $ui.quickTitle)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .onSubmit {
                            let trimmed = ui.quickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
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
                            ui.quickTitle = ""
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        if filteredEvents.isEmpty && filteredTodos.isEmpty {
                            Text("남은 \(activeScope.rawValue)이 없습니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 24)
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
                                    onScheduleNow: {},
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
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .sheet(item: $ui.editingEvent) { event in
            EventEditorSheet(event: event) { updated in
                store.updateEvent(updated)
            } onDelete: {
                store.deleteEvent(event.id)
            }
        }
        .sheet(item: $ui.editingTodo) { todo in
            TodoEditorSheet(todo: todo) { updated in
                store.updateTodo(updated)
            } onDelete: {
                store.deleteTodo(todo.id)
            }
        }
        .background(
            WindowAccessor { window in
                let isPinned = store.settings.isMiniBoardPinnedOnTop
                if isPinned {
                    window.level = .floating
                    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                } else {
                    window.level = .normal
                    window.collectionBehavior = []
                }
                window.isMovableByWindowBackground = true
            }
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                AppThemeHelper.applyTheme(store.settings.theme)
                AppThemeHelper.applyMiniBoardOpacity(store.settings.stickyWindowOpacity)
                AppThemeHelper.applyMiniBoardPin(store.settings.isMiniBoardPinnedOnTop)
            }
        }
        .preferredColorScheme(store.settings.theme.colorScheme)
    }

    private var widgetHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Label("미니 보드", systemImage: "rectangle.stack.fill")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    AppThemeHelper.switchToMainWindow(store: store, opacity: store.settings.mainWindowOpacity) { id in openWindow(id: id) }
                } label: {
                    Label("스케줄러", systemImage: "calendar")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("큰 스케줄러 창으로 전환하고 미니 보드를 숨깁니다")

                let isPinned = store.settings.isMiniBoardPinnedOnTop
                if isPinned {
                    Button {
                        store.settings.isMiniBoardPinnedOnTop = false
                        AppThemeHelper.applyMiniBoardPin(false)
                        store.save()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pin.fill")
                            Text("항상 위 고정")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help("현재 모든 창 맨 위에 고정되어 있습니다 (클릭하면 해제)")
                } else {
                    Button {
                        store.settings.isMiniBoardPinnedOnTop = true
                        AppThemeHelper.applyMiniBoardPin(true)
                        store.save()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pin.slash")
                            Text("고정 해제됨")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("다른 앱 창 위에서도 항상 보이도록 맨 위에 고정")
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Slider(value: $store.settings.stickyWindowOpacity, in: 0.45...1.0, step: 0.05)
                    .controlSize(.mini)
                    .onChange(of: store.settings.stickyWindowOpacity) { _, newVal in
                        AppThemeHelper.applyMiniBoardOpacity(newVal)
                        store.save()
                    }
                Text("\(Int(round(store.settings.stickyWindowOpacity * 100)))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var nextMeetingBanner: some View {
        let now = Date()
        let active = store.activeEventsNow().first
        let next = store.remainingEventsToday().first(where: { $0.startDate > now })

        return HStack(spacing: 8) {
            if let active {
                Circle()
                    .fill(active.category.color)
                    .frame(width: 8, height: 8)
                let minsLeft = max(1, Int(ceil(active.endDate.timeIntervalSince(now) / 60)))
                Text("진행 중: \(active.title) · \(minsLeft)분 남음")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            } else if let next {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(next.category.color)
                let minsUntil = max(1, Int(ceil(next.startDate.timeIntervalSince(now) / 60)))
                Text("다음: \(next.title) · \(minsUntil)분 후 (\(Self.timeFormatter.string(from: next.startDate)))")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("오늘 남은 미팅/일정이 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

private struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                callback(window)
            }
        }
    }
}
