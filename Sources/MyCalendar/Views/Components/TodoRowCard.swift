import SwiftUI

struct TodoRowCard: View {
    let index: Int
    let todo: TodoItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onScheduleNow: () -> Void
    let onSwitchScope: () -> Void
    let onDelete: () -> Void

    @StateObject private var hoverState = StateBox(false)
    @Environment(\.colorScheme) private var colorScheme

    private var isDueSoonOrOverdue: Bool {
        guard !todo.isCompleted, let due = todo.dueDate else { return false }
        let endOfToday = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
        return due <= endOfToday
    }

    private var innerSurfaceColor: Color {
        colorScheme == .dark ? Color(nsColor: .controlBackgroundColor) : Color.white
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(todo.isCompleted ? todo.category.color.opacity(0.45) : todo.category.color)

            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        onToggle()
                    }
                } label: {
                    ZStack {
                        if todo.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Text("\(index)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: 38)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(todo.title)
                                .font(.callout.weight(.medium))
                                .strikethrough(todo.isCompleted)
                                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                                .lineLimit(1)

                            if let folderPath = todo.linkedFolderPath, !folderPath.isEmpty {
                                MiniPostItFolderTag(folderPath: folderPath)
                            }
                        }

                        HStack(spacing: 6) {
                            if let due = todo.dueDate {
                                Text(Self.shortDateFormatter.string(from: due))
                                    .font(.caption2)
                                    .foregroundStyle(isDueSoonOrOverdue ? .orange : .secondary)
                            }

                            if todo.scheduledEventID != nil {
                                Text("배치됨")
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(todo.category.color.opacity(0.15)))
                                    .foregroundStyle(todo.category.color)
                            }
                        }
                    }

                    Spacer(minLength: 4)

                    if hoverState.value {
                        let nextScopeLabel: String = {
                            switch todo.scope {
                            case .today: return "이번 주 할 일로 이동"
                            case .thisWeek: return "이번 달 할 일로 이동"
                            case .thisMonth: return "오늘 할 일로 이동"
                            }
                        }()
                        Menu {
                            Button("선택한 날짜에 배치", action: onScheduleNow)
                            Button(nextScopeLabel, action: onSwitchScope)
                            Button("수정", action: onEdit)
                            Divider()
                            Button("삭제", role: .destructive, action: onDelete)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 22, height: 22)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    } else {
                        Image(systemName: todo.category.symbol)
                            .font(.caption)
                            .foregroundStyle(todo.isCompleted ? Color.secondary.opacity(0.45) : todo.category.color.opacity(0.85))
                            .frame(width: 22, height: 22)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(innerSurfaceColor)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 5, x: -2, y: 2)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
                )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onHover { hovering in
            hoverState.value = hovering
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
        .contextMenu {
            Button("선택한 날짜에 배치", action: onScheduleNow)
            Button(todo.scope == .today ? "이번 주 할 일로 이동" : "오늘 할 일로 이동", action: onSwitchScope)
            Button("수정", action: onEdit)
            Divider()
            Button("삭제", role: .destructive, action: onDelete)
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M/d"
        return f
    }()
}
