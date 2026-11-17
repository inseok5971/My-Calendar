import AppKit
import SwiftUI

@main
struct MyCalendarApp: App {
    @StateObject private var store = CalendarStore()
    @StateObject private var notificationManager = NotificationManager()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("나만의 캘린더", id: "main-calendar") {
            MainView()
                .environmentObject(store)
                .environmentObject(notificationManager)
                .frame(minWidth: 960, minHeight: 640)
                .preferredColorScheme(store.settings.theme.colorScheme)
                .onAppear {
                    guard !store.hasInitializedWindows else { return }
                    store.hasInitializedWindows = true
                    notificationManager.startMonitoring(store: store)
                    AppThemeHelper.applyTheme(store.settings.theme)
                    StatusBarController.shared.setup(store: store)
                    if store.settings.startMinimizedToMenuBar {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            for window in NSApp.windows {
                                window.orderOut(nil)
                            }
                        }
                    } else if store.settings.lastWindowMode == .miniBoard {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            AppThemeHelper.switchToMiniBoard(store: store, opacity: store.settings.stickyWindowOpacity) { id in openWindow(id: id) }
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            AppThemeHelper.switchToMainWindow(store: store, opacity: store.settings.mainWindowOpacity) { id in openWindow(id: id) }
                        }
                    }
                }
        }
        .defaultSize(width: 1180, height: 760)

        Window("미니 보드", id: "sticky-widget") {
            StickyNoteWidgetView()
                .environmentObject(store)
                .preferredColorScheme(store.settings.theme.colorScheme)
                .frame(minWidth: 290, minHeight: 380)
        }
        .defaultSize(width: 330, height: 480)
    }
}
