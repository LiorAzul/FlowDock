import Cocoa
import ScreenCaptureKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let tracker = RecentAppsTracker()
    private let capturer = WindowCapturer()
    private let panelManager = FlowDockPanelManager()
    private let menuBar = MenuBarManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestPermissions()

        panelManager.positionMode = menuBar.currentMode

        menuBar.setup()
        menuBar.onPositionChanged = { [weak self] mode in
            guard let self else { return }
            self.panelManager.positionMode = mode
            self.setContent()
        }

        capturer.start(tracker: tracker)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.setContent()
            self?.panelManager.show()
        }
    }

    private func requestPermissions() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)

        Task {
            let _ = try? await SCShareableContent
                .excludingDesktopWindows(true, onScreenWindowsOnly: true)
        }
    }

    private func setContent() {
        let content = DockContentView(
            tracker: tracker,
            capturer: capturer,
            mode: panelManager.positionMode
        )
        panelManager.updateContent(content)
    }
}
