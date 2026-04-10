import Cocoa
import SwiftUI

// MARK: - Position Mode

enum PositionMode: String, CaseIterable {
    case left, right, bottom

    var isVertical: Bool { self != .bottom }
}

// MARK: - Draggable Panel (no title bar, no traffic lights)

final class DraggablePanel: NSPanel {
    private var dragOrigin: NSPoint?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        dragOrigin = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }
        let screen = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: screen.x - origin.x,
            y: screen.y - origin.y
        )
        setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        dragOrigin = nil
    }
}

// MARK: - Flow Dock Panel Manager

final class FlowDockPanelManager {
    let panel: DraggablePanel
    var positionMode: PositionMode = .right {
        didSet { snapToEdge() }
    }

    init() {
        panel = DraggablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 115, height: 400),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
            backing: .buffered, defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = false

        let ve = NSVisualEffectView(frame: panel.contentView!.bounds)
        ve.autoresizingMask = [.width, .height]
        ve.material = .hudWindow
        ve.blendingMode = .behindWindow
        ve.state = .active
        ve.wantsLayer = true
        ve.layer?.cornerRadius = 12
        ve.layer?.masksToBounds = true
        panel.contentView = ve
    }

    func updateContent<V: View>(_ view: V) {
        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let ve = panel.contentView!
        ve.subviews.forEach { $0.removeFromSuperview() }
        ve.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: ve.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: ve.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: ve.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: ve.trailingAnchor),
        ])

        let size = hosting.fittingSize
        let capped = cappedSize(size)
        panel.setContentSize(capped)
    }

    func show() {
        snapToEdge()
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    func snapToEdge() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let ps = panel.frame.size

        var o: NSPoint
        switch positionMode {
        case .right:
            o = NSPoint(x: vf.maxX - ps.width - 8, y: vf.midY - ps.height / 2)
        case .left:
            o = NSPoint(x: vf.minX + 8, y: vf.midY - ps.height / 2)
        case .bottom:
            o = NSPoint(x: vf.midX - ps.width / 2, y: vf.minY + 8)
        }

        o.x = max(vf.minX, min(o.x, vf.maxX - ps.width))
        o.y = max(vf.minY, min(o.y, vf.maxY - ps.height))
        panel.setFrameOrigin(o)
    }

    private func cappedSize(_ size: NSSize) -> NSSize {
        guard let screen = NSScreen.main else { return size }
        let vf = screen.visibleFrame
        return NSSize(
            width: min(size.width, vf.width - 20),
            height: min(size.height, vf.height - 40)
        )
    }
}
