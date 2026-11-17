import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject, ObservableObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private weak var store: CalendarStore?
    private var cancellables = Set<AnyCancellable>()

    func setup(store: CalendarStore) {
        guard statusItem == nil else { return }
        self.store = store

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = Self.createWhiteCalendarIcon()
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = "나만의 캘린더"
            button.target = self
            button.action = #selector(statusBarButtonClicked)
        }
        self.statusItem = item

        let pop = NSPopover()
        pop.behavior = .transient
        pop.contentSize = NSSize(width: 320, height: 420)
        pop.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView()
                .environmentObject(store)
        )
        self.popover = pop

        store.$menuBarTitleText
            .receive(on: RunLoop.main)
            .sink { [weak self] newTitle in
                self?.statusItem?.button?.toolTip = newTitle.isEmpty ? "나만의 캘린더" : "나만의 캘린더 · " + newTitle
            }
            .store(in: &cancellables)
    }

    @objc private func statusBarButtonClicked() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private static func createWhiteCalendarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let base = NSImage(systemSymbolName: "calendar", accessibilityDescription: "나만의 캘린더") else {
                return false
            }
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            let symbol = base.withSymbolConfiguration(config) ?? base

            let symbolSize = symbol.size
            let drawRect = NSRect(
                x: round((rect.width - min(symbolSize.width, 16)) / 2),
                y: round((rect.height - min(symbolSize.height, 16)) / 2),
                width: min(symbolSize.width, 16),
                height: min(symbolSize.height, 16)
            )

            symbol.draw(in: drawRect)

            NSColor.white.set()
            rect.fill(using: .sourceIn)
            return true
        }
        image.isTemplate = false
        return image
    }
}
