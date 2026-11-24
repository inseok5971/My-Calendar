import Combine
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var store: CalendarStore
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.openWindow) private var openWindow

    @StateObject private var ui = MainUIState()

    @MainActor
    private final class MainUIState: ObservableObject {
        @Published var creatingEventStartDate: Date?
        @Published var editingEvent: ScheduleEvent?
        @Published var editingTodo: TodoItem?
        @Published var isCreatingTodo: Bool = false
        @Published var showSettings: Bool = false
        @Published var aiInputText: String = ""
    }

    var body: some View {

        ZStack(alignment: .topTrailing) {
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 260, ideal: 290, max: 360)
            } detail: {
                VStack(spacing: 0) {
                    aiQuickAddBar
                    if let banner = store.aiBannerMessage {
                        aiStatusBanner(banner)
                    }
                    reminderBanner
                    mainCalendarContent
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    HStack(spacing: 4) {
                        Button {
                            store.navigate(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .help("이전")

                        Button("오늘") {
                            store.selectedDate = Date()
                        }

                        Button {
                            store.navigate(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .help("다음")
                    }

                    Text(headerTitle)
                        .font(.headline)
                        .padding(.leading, 8)
                }

                ToolbarItem(placement: .principal) {
                    Picker("보기", selection: $store.viewMode) {
                        ForEach(CalendarViewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        let cal = Calendar.current
                        let hour = cal.component(.hour, from: Date())
                        let start = cal.date(bySettingHour: (hour + 1) % 24, minute: 0, second: 0, of: store.selectedDate) ?? store.selectedDate
                        ui.creatingEventStartDate = start
                    } label: {
                        Label("새 일정", systemImage: "calendar.badge.plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    .help("새 일정 등록 (⌘N)")

                    Button {
                        ui.isCreatingTodo = true
                    } label: {
                        Label("새 할 일", systemImage: "checkmark.circle.badge.plus")
                    }
                    .keyboardShortcut("t", modifiers: .command)
                    .help("새 할 일(To-do) 등록 (⌘T)")

                    Button {
                        AppThemeHelper.switchToMiniBoard(store: store, opacity: store.settings.stickyWindowOpacity) { id in openWindow(id: id) }
                    } label: {
                        Label("미니 보드", systemImage: "pip.enter")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .help("항상 위에 뜨는 미니 보드로 전환하고 스케줄러 창을 숨깁니다")

                    HStack(spacing: 4) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $store.settings.mainWindowOpacity, in: 0.45...1.0, step: 0.05)
                            .frame(width: 72)
                            .controlSize(.small)
                            .onChange(of: store.settings.mainWindowOpacity) { _, newVal in
                                AppThemeHelper.applyMainWindowOpacity(newVal)
                                store.save()
                            }
                        let percentInt: Int = Int(round(store.settings.mainWindowOpacity * 100.0))
                        Text("\(percentInt)%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .trailing)
                    }
                    .help("스케줄러 창 불투명도 조절")

                    Button {
                        ui.showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .help("알림 및 테마 설정")
                }
            }

            // Floating In-App Toast Overlay
            toastOverlay
                .padding(.top, 48)
                .padding(.trailing, 20)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .sheet(item: Binding(
            get: { ui.creatingEventStartDate.map { IdentifiableDate(date: $0) } },
            set: { ui.creatingEventStartDate = $0?.date }
        )) { item in
            EventEditorSheet(event: nil, initialStartDate: item.date) { newEvent in
                store.addEvent(newEvent)
            }
        }
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
        .sheet(isPresented: $ui.isCreatingTodo) {
            TodoEditorSheet(todo: nil) { newTodo in
                store.addTodo(newTodo)
            }
        }
        .sheet(isPresented: $ui.showSettings) {
            SettingsSheet()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                AppThemeHelper.applyTheme(store.settings.theme)
                AppThemeHelper.applyMainWindowOpacity(store.settings.mainWindowOpacity)
            }
        }
        .preferredColorScheme(store.settings.theme.colorScheme)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainCalendarContent: some View {
        switch store.viewMode {
        case .day:
            DayTimelineView(
                onCreateEvent: { date in ui.creatingEventStartDate = date },
                onEditEvent: { event in ui.editingEvent = event },
                onEditTodo: { todo in ui.editingTodo = todo }
            )
        case .week:
            WeekTimelineView(
                onCreateEvent: { date in ui.creatingEventStartDate = date },
                onEditEvent: { event in ui.editingEvent = event },
                onEditTodo: { todo in ui.editingTodo = todo }
            )
        case .month:
            MonthCalendarView(
                onCreateEvent: { date in ui.creatingEventStartDate = date },
                onEditEvent: { event in ui.editingEvent = event },
                onEditTodo: { todo in ui.editingTodo = todo }
            )
        }
    }

    // MARK: - Visual Reminder Banner

    @ViewBuilder
    private var reminderBanner: some View {
        let activeNow = store.activeEventsNow()
        let upcoming = store.upcomingEventsWithin(minutes: 30)
        let dueTodos = store.dueOrOverdueTodos()

        if let current = activeNow.first {
            bannerBar(
                icon: "clock.badge.checkmark.fill",
                color: current.category.color,
                text: "진행 중: \(current.title) (종료 \(Self.timeFormatter.string(from: current.endDate)))",
                actionTitle: "완료",
                action: { store.toggleEventCompletion(current.id) }
            )
        } else if let next = upcoming.first {
            let minsLeft = max(0, Int(ceil(next.startDate.timeIntervalSinceNow / 60)))
            bannerBar(
                icon: "bell.and.waves.left.and.right.fill",
                color: next.category.color,
                text: "\(minsLeft)분 후 시작: \(next.title) (\(Self.timeFormatter.string(from: next.startDate)))",
                actionTitle: "보기",
                action: { ui.editingEvent = next }
            )
        } else if !dueTodos.isEmpty {
            bannerBar(
                icon: "exclamationmark.circle.fill",
                color: .orange,
                text: "오늘 마감 또는 지연된 할 일이 \(dueTodos.count)건 있습니다. 타임라인으로 드래그해 배치해보세요.",
                actionTitle: nil,
                action: nil
            )
        }
    }

    private func bannerBar(
        icon: String,
        color: Color,
        text: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.callout)

            Text(text)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Toast Overlay

    private var toastOverlay: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ForEach(notificationManager.activeToasts) { toast in
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(toast.category.color)
                        .frame(width: 4)
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(toast.title)
                            .font(.callout.weight(.semibold))
                        Text(toast.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            if let eventID = toast.eventID {
                                Button("완료") {
                                    store.toggleEventCompletion(eventID)
                                    notificationManager.dismissToast(toast.id)
                                }
                                .font(.caption.weight(.medium))
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                            }

                            Button("5분 뒤 다시 알림") {
                                notificationManager.snoozeToast(toast, store: store, minutes: 5)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                        .padding(.top, 2)
                    }

                    Spacer(minLength: 8)

                    Button {
                        notificationManager.dismissToast(toast.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .frame(width: 320)
                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    // MARK: - Formatting

    private var headerTitle: String {
        switch store.viewMode {
        case .day:
            return Self.dayTitleFormatter.string(from: store.selectedDate)
        case .week, .month:
            return Self.monthTitleFormatter.string(from: store.selectedDate)
        }
    }

    // MARK: - AI Smart Quick-Add Bar

    @ViewBuilder
    private var aiQuickAddBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(.purple)
                .font(.system(size: 13, weight: .bold))

            TextField("🤖 AI 스마트 일정 등록 (예: 내일 오후 3시 기획팀 회의, 폴더는 /Portfolio)", text: $ui.aiInputText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit {
                    submitAIPrompt()
                }

            if store.isAILoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button(action: submitAIPrompt) {
                    Text("AI 등록")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.small)
                .disabled(ui.aiInputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.08))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.purple.opacity(0.18)),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private func aiStatusBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundColor(.purple)
                .font(.caption)
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundColor(.primary)
            Spacer()
            Button {
                store.aiBannerMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.15))
    }

    private func submitAIPrompt() {
        let text = ui.aiInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        ui.aiInputText = ""
        Task {
            _ = await store.addEventWithAI(prompt: text)
        }
    }

    private static let dayTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일 (E)"
        return f
    }()

    private static let monthTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

private struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}
