import AppKit
import Foundation

@MainActor
enum AppThemeHelper {
    static func applyTheme(_ theme: AppTheme) {
        let appearance: NSAppearance?
        switch theme {
        case .system:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        }
        NSApp.appearance = appearance
        for window in NSApp.windows {
            window.appearance = appearance
        }
    }

    static func applyMainWindowOpacity(_ opacity: Double) {
        let alpha = CGFloat(min(1.0, max(0.35, opacity)))
        for window in NSApp.windows where window.title == "나만의 캘린더" {
            window.alphaValue = alpha
        }
    }

    static func applyMiniBoardOpacity(_ opacity: Double) {
        let alpha = CGFloat(min(1.0, max(0.35, opacity)))
        for window in NSApp.windows where window.title == "미니 보드" || window.identifier?.rawValue == "sticky-widget" {
            window.alphaValue = alpha
        }
    }

    static func applyMiniBoardPin(_ isPinned: Bool) {
        for window in NSApp.windows where window.title == "미니 보드" || window.identifier?.rawValue == "sticky-widget" {
            if isPinned {
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            } else {
                window.level = .normal
                window.collectionBehavior = []
            }
        }
    }

    static func switchToMiniBoard(store: CalendarStore? = nil, opacity: Double? = nil, isPinned: Bool = true, openWindow: ((String) -> Void)? = nil) {
        NSApp.activate(ignoringOtherApps: true)
        if let store {
            store.settings.lastWindowMode = .miniBoard
            store.save()
        }

        // 1. Show mini board first
        let miniBoard = NSApp.windows.first { $0.title == "미니 보드" || $0.identifier?.rawValue == "sticky-widget" }
        if let miniBoard {
            if let opacity {
                miniBoard.alphaValue = CGFloat(min(1.0, max(0.35, opacity)))
            }
            if isPinned {
                miniBoard.level = .floating
                miniBoard.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            } else {
                miniBoard.level = .normal
                miniBoard.collectionBehavior = []
            }
            miniBoard.makeKeyAndOrderFront(nil)
        } else {
            openWindow?("sticky-widget")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                applyMiniBoardPin(isPinned)
            }
        }

        // 2. Hide main window gracefully
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            for window in NSApp.windows where window.title == "나만의 캘린더" || window.identifier?.rawValue == "main-calendar" {
                window.orderOut(nil)
            }
        }
    }

    static func switchToMainWindow(store: CalendarStore? = nil, opacity: Double? = nil, openWindow: ((String) -> Void)? = nil) {
        NSApp.activate(ignoringOtherApps: true)
        if let store {
            store.settings.lastWindowMode = .mainCalendar
            store.save()
        }

        // 1. Show main window first
        let mainWin = NSApp.windows.first { $0.title == "나만의 캘린더" || $0.identifier?.rawValue == "main-calendar" }
        if let mainWin {
            if let opacity {
                mainWin.alphaValue = CGFloat(min(1.0, max(0.35, opacity)))
            }
            mainWin.makeKeyAndOrderFront(nil)
        } else {
            openWindow?("main-calendar")
        }

        // 2. Hide mini board gracefully
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            for window in NSApp.windows where window.title == "미니 보드" || window.identifier?.rawValue == "sticky-widget" {
                window.orderOut(nil)
            }
        }
    }
}
