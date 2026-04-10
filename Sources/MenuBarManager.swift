import Cocoa

final class MenuBarManager {
    private var statusItem: NSStatusItem!
    var onPositionChanged: ((PositionMode) -> Void)?
    private(set) var currentMode: PositionMode

    init() {
        currentMode = PositionMode(rawValue:
            UserDefaults.standard.string(forKey: "FlowDock.position") ?? "right"
        ) ?? .right
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "dock.rectangle",
                                accessibilityDescription: "FlowDock")
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "FlowDock", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let posMenu = NSMenu()
        for mode in PositionMode.allCases {
            let item = NSMenuItem(title: mode.rawValue.capitalized,
                                  action: #selector(positionSelected(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == currentMode ? .on : .off
            posMenu.addItem(item)
        }

        let posItem = NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
        posItem.submenu = posMenu
        menu.addItem(posItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")

        statusItem.menu = menu
    }

    @objc private func positionSelected(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = PositionMode(rawValue: raw) else { return }
        currentMode = mode
        UserDefaults.standard.set(raw, forKey: "FlowDock.position")
        onPositionChanged?(mode)
        rebuildMenu()
    }
}
