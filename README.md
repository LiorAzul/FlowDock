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

## Usage

1. Launch FlowDock — it appears as a floating panel on the right side of your screen
2. Grant Accessibility and Screen Recording permissions when prompted
3. Use the menu bar icon to change position (Left / Right / Bottom)
4. **Click** a window preview to switch to that app
5. **Swipe** (two-finger drag) on a preview to close the app
6. **Drag** the panel background to reposition

## Architecture

```
Sources/
  main.swift              — App entry point
  AppDelegate.swift       — Lifecycle, permissions, wiring
  RecentAppsTracker.swift — Tracks app activation order via NSWorkspace notifications
  WindowCapturer.swift    — Background window screenshots via ScreenCaptureKit
  FlowDockPanel.swift     — Draggable borderless NSPanel
  DockContentView.swift   — Main SwiftUI layout (vertical/horizontal)
  AppTile.swift           — Individual app card with badge + swipe gesture
  MenuBarManager.swift    — Status bar menu for position control
```

## License

MIT
