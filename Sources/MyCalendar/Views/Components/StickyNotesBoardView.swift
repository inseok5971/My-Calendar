import SwiftUI

struct StickyNotesBoardView: View {
    @EnvironmentObject private var store: CalendarStore

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("메모 (\(store.stickyNotes.count))", systemImage: "note.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    let colors = StickyNoteColor.allCases
                    let nextColor = colors[store.stickyNotes.count % colors.count]
                    store.addStickyNote(title: "", content: "", color: nextColor)
                } label: {
                    Label("새 메모", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if store.stickyNotes.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "note.text.badge.plus")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("메모가 없습니다")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("첫 메모 추가하기") {
                                store.addStickyNote(title: "", content: "", color: .yellow)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    } else {
                        ForEach($store.stickyNotes) { $note in
                            StickyNoteCard(
                                note: $note,
                                onSave: { store.save() },
                                onDelete: { store.deleteStickyNote(note.id) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .padding(.top, 4)
    }
}

private struct StickyNoteCard: View {
    @Binding var note: StickyNote
    let onSave: () -> Void
    let onDelete: () -> Void

    @StateObject private var hoverState = StateBox(false)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Button {
                    note.color = note.color.next()
                    onSave()
                } label: {
                    Circle()
                        .fill(note.color.dotColor)
                        .frame(width: 9, height: 9)
                }
                .buttonStyle(.plain)
                .help("메모 색상 변경")

                TextField("제목 (선택)", text: $note.title)
                    .textFieldStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .onChange(of: note.title) { _, _ in
                        onSave()
                    }

                Spacer(minLength: 4)

                if hoverState.value {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("메모 삭제")
                }
            }

            TextEditor(text: $note.content)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 68, maxHeight: 160)
                .onChange(of: note.content) { _, _ in
                    onSave()
                }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(note.color.fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(note.color.borderColor, lineWidth: 1)
        )
        .onHover { hovering in
            hoverState.value = hovering
        }
    }
}
