import SwiftUI

struct AppTile: View {
    let app: RecentApp
    let thumbnail: NSImage?
    let isVertical: Bool
    let index: Int
    let onClose: () -> Void

    @State private var hovering = false
    @State private var swipeOffset: CGFloat = 0
    @State private var dismissed = false

    private var scale: CGFloat { max(0.78, 1.0 - CGFloat(index) * 0.025) }
    private var tileW: CGFloat { 93 * scale }
    private var tileH: CGFloat { 57 * scale }
    private var badgeSize: CGFloat { 16 * scale }

    var body: some View {
        // Window preview
        Group {
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: tileW, height: tileH)
                    .clipped()
            } else {
                Rectangle().fill(.ultraThinMaterial)
                    .frame(width: tileW, height: tileH)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(hovering ? 0.35 : 0.1), lineWidth: 0.5)
        )
        // Badge bottom-left, sticking out
        .overlay(
            appBadge.offset(x: -5, y: 5),
            alignment: .bottomLeading
        )
        // Strong shadow underneath
        .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
        .scaleEffect(hovering ? 1.03 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: hovering)
        .offset(x: isVertical ? swipeOffset : 0, y: isVertical ? 0 : swipeOffset)
        .opacity(dismissed ? 0 : 1.0 - Double(abs(swipeOffset)) / 80.0)
        .gesture(swipeGesture)
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
        .onTapGesture { activateApp() }
    }

    private var appBadge: some View {
        Group {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: badgeSize, height: badgeSize)
                    .clipShape(RoundedRectangle(cornerRadius: badgeSize * 0.22, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { swipeOffset = isVertical ? $0.translation.width : $0.translation.height }
            .onEnded { value in
                let d = isVertical ? value.translation.width : value.translation.height
                if abs(d) > 40 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        swipeOffset = d > 0 ? 150 : -150; dismissed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onClose() }
                } else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { swipeOffset = 0 }
                }
            }
    }

    private func activateApp() {
        if let url = app.bundleURL {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }
}
