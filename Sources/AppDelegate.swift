import Cocoa
import ScreenCaptureKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let tracker = RecentAppsTracker()
    private let capturer = WindowCapturer()
    private let panelManager = FlowDockPanelManager()
    private let menuBar = MenuBarManager()
    private let permissions = PermissionsManager()
    private let signing = SigningManager()
    private lazy var onboarding = OnboardingWindowController(
        permissions: permissions, signing: signing
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar.setup()
        menuBar.onPositionChanged = { [weak self] mode in
            guard let self else { return }
            self.panelManager.positionMode = mode
            self.setContent()
        }

        permissions.refresh()
        signing.refresh()

        let signingOK = signing.status.isStable || signing.userSkipped
        if permissions.allGranted && signingOK {
            startDock()
        } else {
            onboarding.onAllGranted = { [weak self] in self?.startDock() }
            onboarding.show()
        }
    }

    private func startDock() {
        panelManager.positionMode = menuBar.currentMode
        capturer.start(tracker: tracker)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.setContent()
            self?.panelManager.show()
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
