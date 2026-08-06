import SwiftUI

struct OverlayView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            ZStack {
                if isMinimal {
                    // Tiny dot when idle and not hovered
                    Circle()
                        .fill(Color(red: 0.118, green: 0.333, blue: 0.976).opacity(0.6))
                        .frame(width: 8, height: 8)
                } else if isExpanded {
                    // Pill when recording/transcribing or hovered
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 4)
                } else {
                    // Small circle with mic when hovered
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 4)
                }

                if !isMinimal {
                    HStack(spacing: 6) {
                        // Mic icon
                        ZStack {
                            Circle()
                                .fill(backgroundColor)
                                .frame(width: iconSize, height: iconSize)

                            Image(systemName: iconName)
                                .font(.system(size: iconSize * 0.45, weight: .medium))
                                .foregroundColor(.white)
                                .symbolEffect(.pulse, isActive: appState.status == .recording)
                        }

                        // Status text (show when recording/transcribing)
                        if appState.status != .idle {
                            Text(statusText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                    .padding(.horizontal, isExpanded ? 8 : 4)
                    .padding(.vertical, 4)
                }
            }
            .frame(width: pillWidth, height: pillHeight)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .animation(.easeInOut(duration: 0.2), value: appState.status)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }

    var isMinimal: Bool {
        appState.status == .idle && !isHovering
    }

    var isExpanded: Bool {
        appState.status != .idle
    }

    var iconSize: CGFloat {
        isExpanded ? 24 : 20
    }

    var pillWidth: CGFloat {
        if appState.status == .recording {
            return 110
        } else if appState.status == .transcribing {
            return 120
        } else if isHovering {
            return 28  // Small circle with mic
        } else {
            return 8   // Tiny dot
        }
    }

    var pillHeight: CGFloat {
        if appState.status != .idle {
            return 32
        } else if isHovering {
            return 28
        } else {
            return 8  // Tiny dot
        }
    }

    var backgroundColor: Color {
        switch appState.status {
        case .idle:
            return Color(red: 0.118, green: 0.333, blue: 0.976) // Everstage blue
        case .recording:
            return .red
        case .transcribing:
            return .orange
        }
    }

    var iconName: String {
        switch appState.status {
        case .idle:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .transcribing:
            return "ellipsis"
        }
    }

    var statusText: String {
        switch appState.status {
        case .idle:
            return "Speak"
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        }
    }
}

// Overlay window controller - positioned at bottom center
class OverlayWindowController: NSWindowController {
    private var appState: AppState?

    convenience init(appState: AppState) {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 130, height: 40),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver  // Stay above Dock and desktop icons
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = false  // Prevent accidental dragging
        window.hasShadow = false

        self.init(window: window)
        self.appState = appState

        let hostingView = NSHostingView(rootView:
            OverlayView(onTap: { [weak self] in
                self?.appState?.toggleRecording()
            })
            .environmentObject(appState)
        )
        window.contentView = hostingView

        positionAtBottomCenter()
    }

    func positionAtBottomCenter() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        guard let window = window else { return }

        // Calculate exact center of screen
        let windowWidth: CGFloat = 130
        let x = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
        let y = screenFrame.origin.y + 20  // 20px from bottom

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func show() {
        positionAtBottomCenter()
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
