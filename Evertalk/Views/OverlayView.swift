import SwiftUI

struct OverlayView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            // Mic icon with animation
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 80, height: 80)

                Image(systemName: iconName)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
                    .symbolEffect(.pulse, isActive: appState.status == .recording)
            }

            // Status text
            Text(statusText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            // Transcription preview (if available)
            if !appState.transcription.isEmpty && appState.status == .idle {
                Text(appState.transcription)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: 200)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 20)
    }

    var backgroundColor: Color {
        switch appState.status {
        case .idle:
            return .gray
        case .recording:
            return .red
        case .transcribing:
            return .orange
        }
    }

    var iconName: String {
        switch appState.status {
        case .idle:
            return "checkmark"
        case .recording:
            return "mic.fill"
        case .transcribing:
            return "ellipsis"
        }
    }

    var statusText: String {
        switch appState.status {
        case .idle:
            return "Done"
        case .recording:
            return "Listening... Press Cmd+Shift+Space to stop"
        case .transcribing:
            return "Transcribing..."
        }
    }
}

// Overlay window controller
class OverlayWindowController: NSWindowController {
    convenience init(appState: AppState) {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = false
        window.hasShadow = false

        let hostingView = NSHostingView(rootView:
            OverlayView()
                .environmentObject(appState)
        )
        window.contentView = hostingView

        self.init(window: window)

        centerWindow()
    }

    func centerWindow() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        guard let windowFrame = window?.frame else { return }

        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2

        window?.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func show() {
        centerWindow()
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
