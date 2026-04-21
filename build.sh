#!/bin/bash
set -euo pipefail

APP="FlowDock"
BUILD="build"
BUNDLE="${BUILD}/${APP}.app"
ARCH=$(uname -m)

echo "==> Building ${APP} (${ARCH})…"

rm -rf "${BUILD}"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"

swiftc \
    -target "${ARCH}-apple-macos14.0" \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework SwiftUI \
    -framework ScreenCaptureKit \
    -O \
    -o "${BUNDLE}/Contents/MacOS/${APP}" \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/RecentAppsTracker.swift \
    Sources/WindowCapturer.swift \
    Sources/FlowDockPanel.swift \
    Sources/DockContentView.swift \
    Sources/AppTile.swift \
    Sources/MenuBarManager.swift \
    Sources/PermissionsManager.swift \
    Sources/OnboardingWindow.swift \
    Sources/SigningManager.swift

cp Info.plist "${BUNDLE}/Contents/"
cp Resources/AppIcon.icns "${BUNDLE}/Contents/Resources/"

# Signing identity. For stable TCC (Accessibility / Screen Recording)
# permissions across rebuilds, use a persistent Developer ID or Apple
# Development identity. Otherwise falls back to ad-hoc — permissions
# will need to be re-granted on every rebuild.
#
# Set via:
#   - FLOWDOCK_SIGN_IDENTITY env var, or
#   - a local (gitignored) sign.local file that exports it
if [[ -f sign.local ]]; then
    # shellcheck disable=SC1091
    source sign.local
fi
SIGN_IDENTITY="${FLOWDOCK_SIGN_IDENTITY:--}"
codesign --force --deep --options runtime --sign "${SIGN_IDENTITY}" "${BUNDLE}"

echo "==> Done: ${BUNDLE}"
echo "    Run:  open ${BUNDLE}"
