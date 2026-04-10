import Cocoa
import Combine

struct FolderApp: Identifiable, Codable {
    let id: UUID
    let name: String
    let path: String
    let bundleIdentifier: String?
    var icon: NSImage { NSWorkspace.shared.icon(forFile: path) }
    var url: URL { URL(fileURLWithPath: path) }
    var exists: Bool { FileManager.default.fileExists(atPath: path) }
}

final class FolderStore: ObservableObject {
    @Published var apps: [FolderApp] = []
    private var refreshTimer: Timer?

    init() {
        load()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.load()
        }
    }

    private func load() {
        guard let data = UserDefaults(suiteName: "com.dockfolder.app")?
                .data(forKey: "DockFolder.savedApps"),
              let decoded = try? JSONDecoder().decode([FolderApp].self, from: data)
        else { return }
        let filtered = decoded.filter(\.exists)
        if filtered.map(\.id) != apps.map(\.id) {
            apps = filtered
        }
    }
}
