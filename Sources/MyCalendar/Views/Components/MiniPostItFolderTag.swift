import AppKit
import SwiftUI

enum FolderHelper {
    @MainActor
    static func chooseFolder() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "폴더 연결"
        panel.message = "이 일정/할 일에 연결할 프로젝트 폴더를 선택하세요."
        if panel.runModal() == .OK {
            return panel.url?.path
        }
        return nil
    }

    static func openFolder(at path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
}

/// 일정/할 일 카드 위에 붙는 하얗고 얇은 작은 포스트잇 스타일 폴더 바로가기 태그
struct MiniPostItFolderTag: View {
    let folderPath: String
    var folderName: String {
        (folderPath as NSString).lastPathComponent
    }

    @StateObject private var hoverState = StateBox(false)

    var body: some View {
        Button {
            FolderHelper.openFolder(at: folderPath)
        } label: {
            HStack(spacing: 3.5) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.22)) // 따뜻한 폴더 노란색

                Text(folderName)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.15, green: 0.18, blue: 0.22)) // 또렷한 다크 텍스트
                    .lineLimit(1)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.45))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                // 하얗고 얇은 미니 포스트잇 스티커 모양
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(Color.white)
                    .shadow(
                        color: Color.black.opacity(hoverState.value ? 0.25 : 0.14),
                        radius: hoverState.value ? 3.5 : 1.5,
                        x: 0,
                        y: hoverState.value ? 1.5 : 1.0
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.6)
            )
            .scaleEffect(hoverState.value ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: hoverState.value)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoverState.value = hovering
        }
        .help("클릭하면 '\(folderName)' 폴더가 맥북 Finder로 즉시 열립니다\n경로: \(folderPath)")
    }
}
