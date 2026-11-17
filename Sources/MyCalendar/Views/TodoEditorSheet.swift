import Combine
import SwiftUI

struct TodoEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CalendarStore

    let existingTodo: TodoItem?
    let onSave: (TodoItem) -> Void
    var onDelete: (() -> Void)? = nil

    @StateObject private var form: FormState

    @MainActor
    private final class FormState: ObservableObject {
        @Published var title: String
        @Published var notes: String
        @Published var hasDueDate: Bool
        @Published var dueDate: Date
        @Published var estimatedMinutes: Int
        @Published var priority: TodoPriority
        @Published var category: EventCategory
        @Published var scope: TodoScope
        @Published var selectedOffsets: Set<ReminderOffset>
        @Published var linkedFolderPath: String?

        init(todo: TodoItem?, initialScope: TodoScope = .today) {
            if let todo {
                self.title = todo.title
                self.notes = todo.notes
                self.hasDueDate = todo.dueDate != nil
                self.dueDate = todo.dueDate ?? Date()
                self.estimatedMinutes = todo.estimatedMinutes
                self.priority = todo.priority
                self.category = todo.category
                self.scope = todo.scope
                self.selectedOffsets = Set(todo.reminderOffsets)
                self.linkedFolderPath = todo.linkedFolderPath
            } else {
                self.title = ""
                self.notes = ""
                self.hasDueDate = true
                let cal = Calendar.current
                let now = Date()
                self.scope = initialScope
                if initialScope == .thisWeek {
                    let startOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                    let endOfWeek = cal.date(byAdding: .day, value: 6, to: startOfWeek) ?? now
                    self.dueDate = cal.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek) ?? endOfWeek
                } else if initialScope == .thisMonth {
                    let endOfMonth = (cal.dateInterval(of: .month, for: now)?.end ?? now).addingTimeInterval(-1)
                    self.dueDate = endOfMonth
                } else {
                    let nextHour = (cal.component(.hour, from: now) + 1) % 24
                    self.dueDate = cal.date(bySettingHour: nextHour, minute: 0, second: 0, of: now) ?? now
                }
                self.estimatedMinutes = 60
                self.priority = .medium
                self.category = .work
                self.selectedOffsets = [.fifteenMin, .tenMin, .fiveMin]
                self.linkedFolderPath = nil
            }
        }
    }

    init(
        todo: TodoItem?,
        initialScope: TodoScope = .today,
        onSave: @escaping (TodoItem) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.existingTodo = todo
        self.onSave = onSave
        self.onDelete = onDelete
        _form = StateObject(wrappedValue: FormState(todo: todo, initialScope: initialScope))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existingTodo == nil ? "새 할 일" : "할 일 수정")
                    .font(.headline)
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            Form {
                Section {
                    TextField("할 일 제목", text: $form.title)

                    Picker("카테고리", selection: $form.category) {
                        ForEach(EventCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.symbol).tag(cat)
                        }
                    }

                    Picker("구분", selection: $form.scope) {
                        ForEach(TodoScope.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: form.scope) { _, newScope in
                        guard existingTodo == nil else { return }
                        let cal = Calendar.current
                        let now = Date()
                        switch newScope {
                        case .today:
                            let nextHour = (cal.component(.hour, from: now) + 1) % 24
                            form.dueDate = cal.date(bySettingHour: nextHour, minute: 0, second: 0, of: now) ?? now
                        case .thisWeek:
                            let startOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                            let endOfWeek = cal.date(byAdding: .day, value: 6, to: startOfWeek) ?? now
                            form.dueDate = cal.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek) ?? endOfWeek
                        case .thisMonth:
                            form.dueDate = (cal.dateInterval(of: .month, for: now)?.end ?? now).addingTimeInterval(-1)
                        }
                    }

                    Picker("우선순위", selection: $form.priority) {
                        ForEach(TodoPriority.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("마감 일시") {
                    Toggle("마감 일시 설정", isOn: $form.hasDueDate)
                    if form.hasDueDate {
                        DatePicker("마감 날짜", selection: $form.dueDate, displayedComponents: .date)
                        DatePicker("마감 시간", selection: $form.dueDate, displayedComponents: .hourAndMinute)
                    }
                }

                if form.hasDueDate {
                    Section {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                            let isNone = form.selectedOffsets.isEmpty
                            Button {
                                form.selectedOffsets.removeAll()
                            } label: {
                                Text("알림 끄기")
                                    .font(.caption.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(isNone ? Color.accentColor : Color.primary.opacity(0.06))
                                    )
                                    .foregroundStyle(isNone ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)

                            ForEach(ReminderOffset.allCases) { offset in
                                let isSelected = form.selectedOffsets.contains(offset)
                                Button {
                                    if isSelected {
                                        form.selectedOffsets.remove(offset)
                                    } else {
                                        form.selectedOffsets.insert(offset)
                                    }
                                } label: {
                                    Text(offset.label)
                                        .font(.caption.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                                        )
                                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)

                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(.secondary)
                            if form.selectedOffsets.isEmpty {
                                Text("설정된 알림: 없음")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                let labels = form.selectedOffsets
                                    .sorted { $0.rawValue > $1.rawValue }
                                    .map { "마감 \($0.label)" }
                                    .joined(separator: ", ")
                                Text("설정된 알림: \(labels) (모두 울림)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("알림 설정 (다중 선택 가능)")
                    }
                }

                Section("프로젝트 폴더 연결 (Finder 바로가기)") {
                    if let path = form.linkedFolderPath, !path.isEmpty {
                        HStack(spacing: 8) {
                            MiniPostItFolderTag(folderPath: path)

                            Spacer()

                            Button("폴더 열기") {
                                FolderHelper.openFolder(at: path)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("변경") {
                                if let chosen = FolderHelper.chooseFolder() {
                                    form.linkedFolderPath = chosen
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button {
                                form.linkedFolderPath = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("폴더 연결 해제")
                        }
                    } else {
                        Button {
                            if let chosen = FolderHelper.chooseFolder() {
                                form.linkedFolderPath = chosen
                            }
                        } label: {
                            Label("작업 폴더 선택하기...", systemImage: "folder.badge.plus")
                                .font(.callout)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("메모") {
                    TextEditor(text: $form.notes)
                        .frame(minHeight: 70)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if let onDelete {
                    Button("삭제", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }

                Spacer()

                Button("저장") {
                    let trimmed = form.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    var updated = existingTodo ?? TodoItem(title: trimmed)
                    updated.title = trimmed
                    updated.notes = form.notes
                    updated.dueDate = form.hasDueDate ? form.dueDate : nil
                    updated.estimatedMinutes = form.estimatedMinutes
                    updated.priority = form.priority
                    updated.category = form.category
                    updated.scope = form.scope
                    updated.reminderOffsets = form.hasDueDate ? form.selectedOffsets.sorted { $0.rawValue > $1.rawValue } : []
                    updated.linkedFolderPath = form.linkedFolderPath
                    onSave(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(form.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 440, height: 550)
        .preferredColorScheme(store.settings.theme.colorScheme)
    }
}
