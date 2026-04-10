import Cocoa
import Combine

struct RecentApp: Identifiable, Equatable {
    let id: String          // bundleIdentifier
    let name: String
    let bundleURL: URL?
    let pid: pid_t
    let icon: NSImage?
    let activatedAt: Date

    static func == (lhs: RecentApp, rhs: RecentApp) -> Bool { lhs.id == rhs.id }
}

final class RecentAppsTracker: ObservableObject {
    @Published var recentApps: [RecentApp] = []
    private let maxApps = 20
    private let ignoredBIDs: Set<String> = [
        "com.flowdock.app", "com.dockfolder.app",
        "com.apple.loginwindow", "com.apple.SystemUIServer",
        "com.apple.controlcenter", "com.apple.dock",
        "com.apple.WindowManager", "com.apple.notificationcenterui"
    ]

    init() {
        seedFromRunning()
        observe()
    }

    private func seedFromRunning() {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !ignoredBIDs.contains($0.bundleIdentifier ?? "") }
            .compactMap { makeRecentApp(from: $0, at: Date.distantPast) }
        recentApps = apps
    }

    private func observe() {
        let nc = NSWorkspace.shared.notificationCenter

        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let self else { return }
            self.activated(app)
        }

        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bid = app.bundleIdentifier else { return }
            self?.recentApps.removeAll { $0.id == bid }
        }
    }

    private func activated(_ app: NSRunningApplication) {
        guard let bid = app.bundleIdentifier, !ignoredBIDs.contains(bid) else { return }

        // Move to front or insert
        recentApps.removeAll { $0.id == bid }
        if let entry = makeRecentApp(from: app, at: Date()) {
            recentApps.insert(entry, at: 0)
        }
        if recentApps.count > maxApps {
            recentApps = Array(recentApps.prefix(maxApps))
        }
    }

    private func makeRecentApp(from app: NSRunningApplication, at date: Date) -> RecentApp? {
        guard let bid = app.bundleIdentifier, app.activationPolicy == .regular else { return nil }
        return RecentApp(
            id: bid, name: app.localizedName ?? "Unknown",
            bundleURL: app.bundleURL, pid: app.processIdentifier,
            icon: app.icon, activatedAt: date
        )
    }
}
