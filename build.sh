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
    Sources/MenuBarManager.swift

cp Info.plist "${BUNDLE}/Contents/"
cp Resources/AppIcon.icns "${BUNDLE}/Contents/Resources/"
codesign --force --sign - "${BUNDLE}"

echo "==> Done: ${BUNDLE}"
echo "    Run:  open ${BUNDLE}"
