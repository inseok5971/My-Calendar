import SwiftUI

struct EventRowCard: View {
    let index: Int
    let event: ScheduleEvent
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @StateObject private var hoverState = StateBox(false)
    @Environment(\.colorScheme) private var colorScheme

    private var innerSurfaceColor: Color {
        colorScheme == .dark ? Color(nsColor: .controlBackgroundColor) : Color.white
    }

    private var timeSubtitle: String {
        switch event.periodType {
        case .timed:
            return "\(Self.timeFormatter.string(from: event.startDate)) - \(Self.timeFormatter.string(from: event.endDate))"
        case .allDay:
            return "하루 종일"
        case .thisWeek:
            return "이번 주 내내"
        case .thisMonth:
            return "이번 달 내내"
        case .customRange:
            return "\(Self.dateFormatter.string(from: event.startDate)) ~ \(Self.dateFormatter.string(from: event.endDate))"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M/d"
        return f
    }()

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(event.isCompleted ? event.category.color.opacity(0.45) : event.category.color)

            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        onToggle()
                    }
                } label: {
                    ZStack {
                        if event.isCompleted {
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
                            Text(event.title)
                                .font(.callout.weight(.medium))
                                .strikethrough(event.isCompleted)
                                .foregroundStyle(event.isCompleted ? .secondary : .primary)
                                .lineLimit(1)

                            if let folderPath = event.linkedFolderPath, !folderPath.isEmpty {
                                MiniPostItFolderTag(folderPath: folderPath)
                            }
                        }

                        HStack(spacing: 6) {
                            HStack(spacing: 2) {
                                Image(systemName: event.periodType == .timed ? "clock" : "calendar")
                                    .font(.system(size: 9))
                                Text(timeSubtitle)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)

                            Text(event.periodType == .timed ? "일정" : event.periodType.rawValue)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(event.category.color.opacity(0.15)))
                                .foregroundStyle(event.category.color)

                            if let recLabel = event.recurrence.shortLabel {
                                HStack(spacing: 2) {
                                    Image(systemName: "repeat")
                                        .font(.system(size: 8))
                                    Text(recLabel)
                                        .font(.caption2.weight(.medium))
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer(minLength: 4)

                    if hoverState.value {
                        Menu {
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
                        Image(systemName: event.category.symbol)
                            .font(.caption)
                            .foregroundStyle(event.isCompleted ? Color.secondary.opacity(0.45) : event.category.color.opacity(0.85))
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
            }
            .padding(.leading, 8)
        }
        .frame(minHeight: 46)
        .onHover { isHovered in
            hoverState.value = isHovered
        }
    }
}
