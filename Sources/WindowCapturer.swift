import Cocoa
import ScreenCaptureKit
import Combine

final class WindowCapturer: ObservableObject {
    @Published var thumbnails: [String: NSImage] = [:]  // keyed by bundleID
    private var lastCapture: [String: Date] = [:]
    private var captureTimer: Timer?

    func start(tracker: RecentAppsTracker) {
        captureTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self, weak tracker] _ in
            guard let self, let tracker else { return }
            self.captureAll(apps: tracker.recentApps)
        }
        // Initial capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self, weak tracker] in
            guard let self, let tracker else { return }
            self.captureAll(apps: tracker.recentApps)
        }
    }

    func stop() {
        captureTimer?.invalidate()
    }

    private func captureAll(apps: [RecentApp]) {
        Task.detached(priority: .utility) { [weak self] in
            guard let content = try? await SCShareableContent
                .excludingDesktopWindows(true, onScreenWindowsOnly: false) else { return }

            for app in apps.prefix(15) {
                // Skip if captured recently and not re-activated
                if let last = await self?.lastCapture[app.id],
                   app.activatedAt <= last { continue }

                guard let window = content.windows.first(where: {
                    $0.owningApplication?.processID == app.pid
                    && $0.frame.width >= 100 && $0.frame.height >= 50
                }) else { continue }

                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                let aspect = window.frame.width / max(window.frame.height, 1)
                config.width = 240
                config.height = max(1, Int(240.0 / aspect))
                config.showsCursor = false

                guard let cg = try? await SCScreenshotManager.captureImage(
                    contentFilter: filter, configuration: config
                ) else { continue }

                let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                let appID = app.id

                await MainActor.run { [weak self] in
                    self?.thumbnails[appID] = img
                    self?.lastCapture[appID] = Date()
                }
            }
        }
    }
}
