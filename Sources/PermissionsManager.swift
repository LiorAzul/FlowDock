import Cocoa
import CoreGraphics
import ApplicationServices

enum PermissionStatus {
    case granted, denied
    var isGranted: Bool { self == .granted }
}

final class PermissionsManager: ObservableObject {
    @Published var accessibility: PermissionStatus = .denied
    @Published var screenRecording: PermissionStatus = .denied

    var allGranted: Bool { accessibility.isGranted && screenRecording.isGranted }

    private var pollTimer: Timer?
    private var onChange: (() -> Void)?

    init() { refresh() }

    func refresh() {
        accessibility = AXIsProcessTrusted() ? .granted : .denied
        screenRecording = CGPreflightScreenCaptureAccess() ? .granted : .denied
    }

    func startPolling(onChange: @escaping () -> Void) {
        stopPolling()
        self.onChange = onChange
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refresh()
            self.onChange?()
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        onChange = nil
    }

    // Triggers the system "Allow FlowDock to control this computer" dialog
    // and registers the app in the Accessibility list.
    func requestAccessibilityPrompt() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // Registers the app in Screen Recording and triggers the system prompt.
    func requestScreenRecordingPrompt() {
        _ = CGRequestScreenCaptureAccess()
    }

    func openAccessibilitySettings() {
        openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openScreenRecordingSettings() {
        openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private func openURL(_ url: String) {
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
    }

    static func relaunch() {
        let path = Bundle.main.bundleURL.path
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", path]
        try? task.run()
        NSApp.terminate(nil)
    }
}
