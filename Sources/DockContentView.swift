import SwiftUI

struct DockContentView: View {
    @ObservedObject var tracker: RecentAppsTracker
    @ObservedObject var capturer: WindowCapturer
    let mode: PositionMode

    private var visibleApps: [RecentApp] {
        tracker.recentApps.filter { capturer.thumbnails[$0.id] != nil }
    }

    var body: some View {
        if mode.isVertical {
            verticalLayout
        } else {
            horizontalLayout
        }
    }

    private var verticalLayout: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: -12) {
                ForEach(Array(visibleApps.enumerated()), id: \.element.id) { idx, app in
                    AppTile(app: app,
                            thumbnail: capturer.thumbnails[app.id],
                            isVertical: true,
                            index: idx,
                            onClose: { closeApp(app) })
                        .zIndex(Double(visibleApps.count - idx))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
        }
        .frame(width: 110)
    }

    private var horizontalLayout: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -9) {
                ForEach(Array(visibleApps.enumerated()), id: \.element.id) { idx, app in
                    AppTile(app: app,
                            thumbnail: capturer.thumbnails[app.id],
                            isVertical: false,
                            index: idx,
                            onClose: { closeApp(app) })
                        .zIndex(Double(visibleApps.count - idx))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(height: 75)
    }

    private func closeApp(_ app: RecentApp) {
        NSRunningApplication(processIdentifier: app.pid)?.terminate()
        tracker.recentApps.removeAll { $0.id == app.id }
        capturer.thumbnails.removeValue(forKey: app.id)
    }
}
