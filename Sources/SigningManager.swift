import Cocoa

struct SigningIdentity: Hashable, Identifiable {
    let hash: String
    let name: String
    var id: String { hash }
}

enum SigningStatus: Equatable {
    case stable(teamID: String)
    case adhoc
    case unknown
    var isStable: Bool { if case .stable = self { return true } else { return false } }
}

final class SigningManager: ObservableObject {
    @Published var status: SigningStatus = .unknown
    @Published var identities: [SigningIdentity] = []

    private let skippedKey = "FlowDock.signingSetupSkipped"

    var userSkipped: Bool {
        get { UserDefaults.standard.bool(forKey: skippedKey) }
        set { UserDefaults.standard.set(newValue, forKey: skippedKey) }
    }

    init() { refresh() }

    func refresh() {
        status = detectStatus()
        identities = listIdentities()
    }

    // Auto-detect source directory from current bundle location.
    // For a build at <root>/build/FlowDock.app, returns <root>.
    func autodetectSourceDirectory() -> URL? {
        let app = Bundle.main.bundleURL
        let candidate = app.deletingLastPathComponent().deletingLastPathComponent()
        let fm = FileManager.default
        let looksRight =
            fm.fileExists(atPath: candidate.appendingPathComponent("build.sh").path) &&
            fm.fileExists(atPath: candidate.appendingPathComponent("Sources").path)
        return looksRight ? candidate : nil
    }

    // Prompts the user to pick the source folder. Returns nil if cancelled or invalid.
    func promptForSourceDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the FlowDock source folder (it must contain build.sh and Sources/)."
        panel.prompt = "Select"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let buildScript = url.appendingPathComponent("build.sh")
        guard FileManager.default.fileExists(atPath: buildScript.path) else { return nil }
        return url
    }

    func writeSignLocal(identity: SigningIdentity, to directory: URL) throws -> URL {
        let escaped = identity.name.replacingOccurrences(of: "\"", with: "\\\"")
        let content = """
        # Written by FlowDock onboarding. Gitignored.
        export FLOWDOCK_SIGN_IDENTITY=\"\(escaped)\"
        """
        let url = directory.appendingPathComponent("sign.local")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Private

    private func detectStatus() -> SigningStatus {
        let bundlePath = Bundle.main.bundlePath
        let out = runShell("/usr/bin/codesign", ["-dvvv", bundlePath])
        // codesign writes signature info to stderr
        let text = out.stderr + out.stdout
        if text.contains("Signature=adhoc") { return .adhoc }
        for line in text.split(separator: "\n") {
            if line.hasPrefix("TeamIdentifier=") {
                let id = line.dropFirst("TeamIdentifier=".count)
                let idStr = id.trimmingCharacters(in: .whitespaces)
                if idStr != "not set" && !idStr.isEmpty {
                    return .stable(teamID: idStr)
                }
            }
        }
        return .unknown
    }

    private func listIdentities() -> [SigningIdentity] {
        let out = runShell("/usr/bin/security", ["find-identity", "-v", "-p", "codesigning"])
        var ids: [SigningIdentity] = []
        for raw in out.stdout.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            // Format: "1) ABCDEF... \"Name (TEAM)\""
            guard let firstQuote = line.firstIndex(of: "\""),
                  let lastQuote = line.lastIndex(of: "\""),
                  firstQuote < lastQuote else { continue }
            let name = String(line[line.index(after: firstQuote)..<lastQuote])
            let prefix = line[..<firstQuote].trimmingCharacters(in: .whitespaces)
            let hash = prefix.components(separatedBy: " ").last ?? ""
            guard !hash.isEmpty, !name.isEmpty else { continue }
            ids.append(SigningIdentity(hash: hash, name: name))
        }
        return ids
    }

    private func runShell(_ path: String, _ args: [String]) -> (stdout: String, stderr: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        do { try task.run() } catch { return ("", "") }
        task.waitUntilExit()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        return (
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
