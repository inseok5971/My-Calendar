import AppKit
import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject private var store: CalendarStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let active = store.activeEventsNow().first
            let remaining = store.remainingEventsToday()
            let todayTodos = store.todos.filter { !$0.isCompleted && $0.scope == .today }

            VStack(alignment: .leading, spacing: 12) {
                // Next / Active event card
                if let active {
                    let minsLeft = max(1, Int(ceil(active.endDate.timeIntervalSince(now) / 60)))
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("현재 진행 중 · \(minsLeft)분 남음")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(active.category.color)
                            Text(active.title)
                                .font(.callout.weight(.semibold))
                        }
                        Spacer()
                        Button("완료") {
                            store.toggleEventCompletion(active.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(active.category.color.opacity(0.12))
                    )
                } else if let next = remaining.first(where: { $0.startDate > now }) {
                    let minsUntil = max(1, Int(ceil(next.startDate.timeIntervalSince(now) / 60)))
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("다음 일정 · \(minsUntil)분 후 (\(Self.timeFormatter.string(from: next.startDate)))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(next.category.color)
                            Text(next.title)
                                .font(.callout.weight(.semibold))
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(next.category.color.opacity(0.12))
                    )
                }

                // Today's remaining schedule
                VStack(alignment: .leading, spacing: 6) {
                    Text("오늘 남은 일정 (\(remaining.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if remaining.isEmpty {
                        Text("오늘 남은 일정이 없습니다.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(remaining.prefix(4)) { event in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(event.category.color)
                                    .frame(width: 6, height: 6)
                                Text(Self.timeFormatter.string(from: event.startDate))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(event.title)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                }

                Divider()

                // Today's Todos quick check-off
                VStack(alignment: .leading, spacing: 6) {
                    Text("오늘 할 일 (\(todayTodos.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if todayTodos.isEmpty {
                        Text("남은 오늘 할 일이 없습니다.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(todayTodos.prefix(5)) { todo in
                            HStack(spacing: 8) {
                                PillToggleCheck(
                                    isOn: todo.isCompleted,
                                    tintColor: todo.category.color,
                                    action: { store.toggleTodoCompletion(todo.id) }
                                )
                                Text(todo.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                }

                Divider()

                // Quick actions
                HStack {
                    Button("스케줄러") {
                        AppThemeHelper.switchToMainWindow(store: store, opacity: store.settings.mainWindowOpacity) { id in openWindow(id: id) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("미니 보드") {
                        AppThemeHelper.switchToMiniBoard(store: store, opacity: store.settings.stickyWindowOpacity) { id in openWindow(id: id) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Spacer()

                    Button("종료") {
                        NSApp.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(width: 310)
            .preferredColorScheme(store.settings.theme.colorScheme)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
