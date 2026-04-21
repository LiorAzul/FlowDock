import Cocoa
import SwiftUI

final class OnboardingWindowController {
    private var window: NSWindow?
    private let permissions: PermissionsManager
    private let signing: SigningManager
    var onAllGranted: (() -> Void)?

    init(permissions: PermissionsManager, signing: SigningManager) {
        self.permissions = permissions
        self.signing = signing
    }

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            w.title = "FlowDock Setup"
            w.isReleasedWhenClosed = false
            w.center()

            let view = OnboardingView(
                permissions: permissions,
                signing: signing,
                onAccessibility: { [weak self] in
                    self?.permissions.requestAccessibilityPrompt()
                    self?.permissions.openAccessibilitySettings()
                },
                onScreenRecording: { [weak self] in
                    self?.permissions.requestScreenRecordingPrompt()
                    self?.permissions.openScreenRecordingSettings()
                },
                onRelaunch: { PermissionsManager.relaunch() },
                onQuit: { NSApp.terminate(nil) }
            )
            w.contentView = NSHostingView(rootView: view)
            window = w
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        permissions.startPolling { [weak self] in
            guard let self, self.permissions.allGranted else { return }
            // Only finish once signing step is past (configured or skipped).
            if self.signing.status.isStable || self.signing.userSkipped {
                self.finish()
            }
        }
    }

    func finish() {
        permissions.stopPolling()
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        onAllGranted?()
    }
}

// MARK: - Steps

private enum OnboardingStep: Equatable {
    case signing
    case signingSaved(path: String)
    case permissions
}

private struct OnboardingView: View {
    @ObservedObject var permissions: PermissionsManager
    @ObservedObject var signing: SigningManager
    @State private var step: OnboardingStep
    @State private var selectedIdentity: SigningIdentity?
    @State private var signingError: String?

    let onAccessibility: () -> Void
    let onScreenRecording: () -> Void
    let onRelaunch: () -> Void
    let onQuit: () -> Void

    init(
        permissions: PermissionsManager,
        signing: SigningManager,
        onAccessibility: @escaping () -> Void,
        onScreenRecording: @escaping () -> Void,
        onRelaunch: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.permissions = permissions
        self.signing = signing
        self.onAccessibility = onAccessibility
        self.onScreenRecording = onScreenRecording
        self.onRelaunch = onRelaunch
        self.onQuit = onQuit

        let showSigning = !signing.status.isStable && !signing.userSkipped
        self._step = State(initialValue: showSigning ? .signing : .permissions)
        self._selectedIdentity = State(initialValue: signing.identities.first)
    }

    var body: some View {
        Group {
            switch step {
            case .signing:          signingStep
            case .signingSaved(let path): rebuildStep(path: path)
            case .permissions:      permissionsStep
            }
        }
        .frame(width: 520, height: 440)
    }

    // MARK: Signing step

    private var signingStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick a code-signing identity")
                .font(.title2).bold()
            Text("This build is ad-hoc signed. macOS will reset FlowDock's Accessibility and Screen Recording permissions after every rebuild. Pick a stable identity to avoid that.")
                .font(.subheadline).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if signing.identities.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No signing identities found on this Mac.")
                        .font(.headline)
                    Text("You can create a free \"Apple Development\" identity by signing into Xcode with an Apple ID (Xcode ▸ Settings ▸ Accounts). Then click Refresh below.")
                        .font(.caption).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Identity").font(.headline)
                    Picker("", selection: $selectedIdentity) {
                        ForEach(signing.identities) { id in
                            Text(id.name).tag(Optional(id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
            }

            if let err = signingError {
                Text(err).font(.caption).foregroundColor(.red)
            }

            Spacer(minLength: 0)

            HStack {
                Button("Refresh") { signing.refresh(); selectedIdentity = signing.identities.first }
                Button("Continue with ad-hoc") { skipSigning() }
                Spacer()
                Button("Configure signing", action: configureSigning)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedIdentity == nil)
            }
        }
        .padding(24)
    }

    private func configureSigning() {
        signingError = nil
        guard let identity = selectedIdentity else { return }
        let dir = signing.autodetectSourceDirectory() ?? signing.promptForSourceDirectory()
        guard let dir else {
            signingError = "Couldn't find the FlowDock source folder."
            return
        }
        do {
            let path = try signing.writeSignLocal(identity: identity, to: dir)
            step = .signingSaved(path: path.path)
        } catch {
            signingError = "Couldn't write sign.local: \(error.localizedDescription)"
        }
    }

    private func skipSigning() {
        signing.userSkipped = true
        step = .permissions
    }

    // MARK: Rebuild step

    private func rebuildStep(path: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Almost there — rebuild required")
                .font(.title2).bold()
            Text("Saved your signing identity to:")
                .font(.subheadline).foregroundColor(.secondary)
            Text(path)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.textBackgroundColor)))

            Text("To apply it, quit FlowDock and rebuild from Terminal:")
                .font(.subheadline).foregroundColor(.secondary)
            Text("./build.sh && open build/FlowDock.app")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.textBackgroundColor)))

            Text("After rebuilding once, your Accessibility and Screen Recording permissions will persist across all future rebuilds.")
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack {
                Button("Back") { step = .signing }
                Spacer()
                Button("Quit FlowDock", action: onQuit)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }

    // MARK: Permissions step

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FlowDock needs your permission")
                .font(.title2).bold()
            Text("Grant these permissions to continue. FlowDock detects grants automatically — you may need to relaunch after enabling a permission.")
                .font(.subheadline).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            PermissionRow(
                title: "Accessibility",
                description: "Needed to detect running applications.",
                granted: permissions.accessibility.isGranted,
                action: onAccessibility
            )
            PermissionRow(
                title: "Screen Recording",
                description: "Needed to capture live window previews.",
                granted: permissions.screenRecording.isGranted,
                action: onScreenRecording
            )

            Spacer(minLength: 0)

            HStack {
                Text("Already enabled? Relaunch to apply.")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("Relaunch", action: onRelaunch)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }
}

private struct PermissionRow: View {
    let title: String
    let description: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(granted ? .green : .orange)
                .font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if !granted {
                Button("Open Settings", action: action)
            } else {
                Text("Granted").font(.caption).foregroundColor(.green)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
