# FlowDock

A floating recent-apps dock for macOS, inspired by iOS/Android recent apps.

![FlowDock](Resources/AppIcon.png)

## Features

- **Floating window previews** — shows live screenshots of your recent apps, stacked like cards
- **App icon badges** — small app icon overlay on each window preview
- **Swipe to close** — two-finger swipe on a card to terminate the app
- **Click to switch** — click any preview to activate that app
- **Draggable** — drag the dock anywhere on screen
- **Position modes** — left side, right side, or bottom (via menu bar)
- **All spaces** — appears on every desktop/space
- **No title bar** — clean, minimal design with frosted glass background
- **Auto-updates** — window previews refresh every few seconds
- **Smart filtering** — only shows apps with visible windows

## Requirements

- macOS 14.0+
- **Accessibility** permission (for app tracking)
- **Screen Recording** permission (for window captures)

## Build

```bash
chmod +x build.sh
./build.sh
open build/FlowDock.app
```

## First run

On first launch, FlowDock opens a Setup window that walks you through:

1. **Code-signing identity** (only shown if the build is ad-hoc signed) — picks a stable identity so macOS keeps your Accessibility / Screen Recording permissions across rebuilds. See [Signing](#signing) below.
2. **Accessibility** — needed to detect running applications.
3. **Screen Recording** — needed to capture live window previews.

FlowDock polls for granted permissions automatically; after enabling one in System Settings you may need to click **Relaunch** so the running process picks it up.

## Signing

macOS keyes Privacy permissions (TCC) by the app's code signature. If the app is ad-hoc signed, the signature's `cdhash` changes on every rebuild, which invalidates your granted permissions — the Setup window will keep reappearing even though the toggles in System Settings look enabled.

The Setup window's first step solves this: pick one of your existing signing identities (from `security find-identity -v -p codesigning`) and FlowDock writes a gitignored `sign.local` next to `build.sh`:

```
export FLOWDOCK_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)"
```

`build.sh` picks it up on the next build. Your identity is **never committed** — `sign.local` is in `.gitignore`.

You can also set it manually:

```bash
export FLOWDOCK_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)"
./build.sh
```

A free Apple Development identity can be created by signing into Xcode with an Apple ID (Xcode ▸ Settings ▸ Accounts). If you'd rather skip signing, click **Continue with ad-hoc** — you'll just need to re-grant permissions after each rebuild.

## Usage

1. Launch FlowDock — it appears as a floating panel on the right side of your screen
2. Use the menu bar icon to change position (Left / Right / Bottom)
3. **Click** a window preview to switch to that app
4. **Swipe** (two-finger drag) on a preview to close the app
5. **Drag** the panel background to reposition

## Architecture

```
Sources/
  main.swift              — App entry point
  AppDelegate.swift       — Lifecycle, gates startup on signing + permissions
  RecentAppsTracker.swift — Tracks app activation order via NSWorkspace notifications
  WindowCapturer.swift    — Background window screenshots via ScreenCaptureKit
  FlowDockPanel.swift     — Draggable borderless NSPanel
  DockContentView.swift   — Main SwiftUI layout (vertical/horizontal)
  AppTile.swift           — Individual app card with badge + swipe gesture
  MenuBarManager.swift    — Status bar menu for position control
  PermissionsManager.swift— Checks TCC status without prompting; polls for grants
  SigningManager.swift    — Detects ad-hoc, lists identities, writes sign.local
  OnboardingWindow.swift  — Setup flow: signing → rebuild → permissions
```

## Troubleshooting

**Setup window reappears even though permissions look enabled in System Settings.** Your build is ad-hoc signed and the `cdhash` changed on the last rebuild. Configure a signing identity in Setup (or via `FLOWDOCK_SIGN_IDENTITY`) and rebuild once. To clear stale TCC entries:

```bash
tccutil reset All com.flowdock.app
```

**`codesign -dvvv build/FlowDock.app` shows `Signature=adhoc`.** `sign.local` is missing or empty, or `FLOWDOCK_SIGN_IDENTITY` is unset in your shell.

## License

MIT
