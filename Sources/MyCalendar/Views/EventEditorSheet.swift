import Combine
import SwiftUI

struct EventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CalendarStore

    let existingEvent: ScheduleEvent?
    let onSave: (ScheduleEvent) -> Void
    var onDelete: (() -> Void)? = nil

    @StateObject private var form: FormState

    @MainActor
    private final class FormState: ObservableObject {
        @Published var title: String
        @Published var notes: String
        @Published var startDate: Date
        @Published var endDate: Date
        @Published var category: EventCategory
        @Published var periodType: EventPeriodType
        @Published var selectedOffsets: Set<ReminderOffset>
        @Published var isCompleted: Bool
        @Published var recurrence: RecurrenceRule
        @Published var hasRecurrenceEndDate: Bool
        @Published var recurrenceEndDate: Date
        @Published var linkedFolderPath: String?

        init(event: ScheduleEvent?, initialStartDate: Date) {
            if let event {
                self.title = event.title
                self.notes = event.notes
                self.startDate = event.startDate
                self.endDate = event.endDate
                self.category = event.category
                self.periodType = event.periodType
                self.selectedOffsets = Set(event.reminderOffsets)
                self.isCompleted = event.isCompleted
                self.recurrence = event.recurrence
                self.hasRecurrenceEndDate = (event.recurrenceEndDate != nil)
                self.recurrenceEndDate = event.recurrenceEndDate ?? event.startDate.addingTimeInterval(86400 * 90)
                self.linkedFolderPath = event.linkedFolderPath
            } else {
                self.title = ""
                self.notes = ""
                self.startDate = initialStartDate
                self.endDate = initialStartDate.addingTimeInterval(3600)
                self.category = .work
                self.periodType = .timed
                self.selectedOffsets = [.fifteenMin, .tenMin, .fiveMin]
                self.isCompleted = false
                self.recurrence = .none
                self.hasRecurrenceEndDate = false
                self.recurrenceEndDate = initialStartDate.addingTimeInterval(86400 * 90)
                self.linkedFolderPath = nil
            }
        }
    }

    init(
        event: ScheduleEvent?,
        initialStartDate: Date = Date(),
        onSave: @escaping (ScheduleEvent) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.existingEvent = event
        self.onSave = onSave
        self.onDelete = onDelete
        _form = StateObject(wrappedValue: FormState(event: event, initialStartDate: initialStartDate))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existingEvent == nil ? "새 일정" : "일정 수정")
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
                    TextField("일정 제목", text: $form.title)
                        .font(.body)

                    Picker("카테고리", selection: $form.category) {
                        ForEach(EventCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.symbol)
                                .tag(cat)
                        }
                    }

                    if existingEvent != nil {
                        Toggle("완료됨", isOn: $form.isCompleted)
                    }
                }

                Section("일정 기간 및 시간") {
                    Picker("유형", selection: $form.periodType) {
                        ForEach(EventPeriodType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: form.periodType) { _, newType in
                        let cal = Calendar.current
                        let now = form.startDate
                        if newType != .timed {
                            form.selectedOffsets.removeAll()
                        } else if form.selectedOffsets.isEmpty {
                            form.selectedOffsets = [.fifteenMin, .tenMin, .fiveMin]
                        }
                        switch newType {
                        case .timed:
                            break
                        case .allDay:
                            form.startDate = cal.startOfDay(for: now)
                            form.endDate = cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
                        case .thisWeek:
                            let startOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)
                            let endOfWeek = cal.date(byAdding: .day, value: 6, to: startOfWeek) ?? now
                            form.startDate = startOfWeek
                            form.endDate = cal.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek) ?? endOfWeek
                        case .thisMonth:
                            let startOfMonth = cal.dateInterval(of: .month, for: now)?.start ?? cal.startOfDay(for: now)
                            let endOfMonth = (cal.dateInterval(of: .month, for: now)?.end ?? now).addingTimeInterval(-1)
                            form.startDate = startOfMonth
                            form.endDate = endOfMonth
                        case .customRange:
                            form.startDate = cal.startOfDay(for: now)
                            form.endDate = cal.date(bySettingHour: 23, minute: 59, second: 59, of: form.endDate) ?? form.endDate
                        }
                    }

                    if form.periodType == .timed {
                        DatePicker("시작 날짜", selection: $form.startDate, displayedComponents: .date)
                            .onChange(of: form.startDate) { oldVal, newVal in
                                let duration = max(900, form.endDate.timeIntervalSince(oldVal))
                                form.endDate = newVal.addingTimeInterval(duration)
                            }
                        DatePicker("시작 시간", selection: $form.startDate, displayedComponents: .hourAndMinute)
                            .onChange(of: form.startDate) { oldVal, newVal in
                                let duration = max(900, form.endDate.timeIntervalSince(oldVal))
                                form.endDate = newVal.addingTimeInterval(duration)
                            }

                        DatePicker("종료 날짜", selection: $form.endDate, in: form.startDate..., displayedComponents: .date)
                        DatePicker("종료 시간", selection: $form.endDate, in: form.startDate.addingTimeInterval(900)..., displayedComponents: .hourAndMinute)
                    } else if form.periodType == .allDay {
                        DatePicker("날짜", selection: $form.startDate, displayedComponents: .date)
                            .onChange(of: form.startDate) { _, newVal in
                                let cal = Calendar.current
                                form.startDate = cal.startOfDay(for: newVal)
                                form.endDate = cal.date(bySettingHour: 23, minute: 59, second: 59, of: newVal) ?? newVal
                            }
                    } else if form.periodType == .thisWeek {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(Color.accentColor)
                            Text("이번 주 전체: \(Self.dateOnlyFormatter.string(from: form.startDate)) ~ \(Self.dateOnlyFormatter.string(from: form.endDate))")
                                .font(.callout)
                        }
                        .padding(.vertical, 4)
                    } else if form.periodType == .thisMonth {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(Color.accentColor)
                            Text("이번 달 전체: \(Self.monthOnlyFormatter.string(from: form.startDate)) (\(Self.dateOnlyFormatter.string(from: form.startDate)) ~ \(Self.dateOnlyFormatter.string(from: form.endDate)))")
                                .font(.callout)
                        }
                        .padding(.vertical, 4)
                    } else if form.periodType == .customRange {
                        DatePicker("시작일", selection: $form.startDate, displayedComponents: .date)
                            .onChange(of: form.startDate) { _, newVal in
                                form.startDate = Calendar.current.startOfDay(for: newVal)
                            }
                        DatePicker("종료일", selection: $form.endDate, in: form.startDate..., displayedComponents: .date)
                            .onChange(of: form.endDate) { _, newVal in
                                form.endDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: newVal) ?? newVal
                            }
                    }
                }

                Section("반복 설정") {
                    Picker("반복", selection: $form.recurrence) {
                        ForEach(RecurrenceRule.allCases) { rule in
                            Text(rule.rawValue).tag(rule)
                        }
                    }
                    if form.recurrence != .none {
                        Toggle("반복 종료일 지정", isOn: $form.hasRecurrenceEndDate)
                        if form.hasRecurrenceEndDate {
                            DatePicker(
                                "반복 종료일",
                                selection: $form.recurrenceEndDate,
                                in: form.startDate...,
                                displayedComponents: .date
                            )
                        }
                    }
                }

                if form.periodType == .timed {
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
                                    .map { $0.label }
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
                        .font(.callout)
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
                    var updated = existingEvent ?? ScheduleEvent(title: trimmed, startDate: form.startDate, endDate: form.endDate)
                    updated.title = trimmed
                    updated.notes = form.notes
                    updated.startDate = form.startDate
                    updated.periodType = form.periodType
                    updated.isAllDay = (form.periodType != .timed)
                    if form.periodType != .timed {
                        updated.endDate = max(form.endDate, form.startDate)
                    } else {
                        updated.endDate = max(form.endDate, form.startDate.addingTimeInterval(900))
                    }
                    updated.category = form.category
                    updated.reminderOffsets = (form.periodType == .timed) ? form.selectedOffsets.sorted { $0.rawValue > $1.rawValue } : []
                    updated.isCompleted = form.isCompleted
                    updated.recurrence = form.recurrence
                    updated.recurrenceEndDate = (form.recurrence != .none && form.hasRecurrenceEndDate) ? form.recurrenceEndDate : nil
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
        .frame(width: 440, height: 570)
        .preferredColorScheme(store.settings.theme.colorScheme)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f
    }()

    private static let monthOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        return f
    }()
}
