import SwiftUI

struct OverlayView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            ZStack {
                // Background shape
                Capsule()
                    .fill(backgroundFill)
                    .overlay(
                        Capsule()
                            .strokeBorder(borderGradient, lineWidth: appState.status == .recording ? 2 : 0)
                    )
                    .shadow(color: shadowColor, radius: isMinimal ? 0 : 8)

                // Content
                HStack(spacing: 6) {
                    if !isMinimal {
                        // Status indicator
                        if appState.status == .settingUp {
                            // Spinning loader for setup
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else if appState.status == .recording {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .modifier(PulseAnimation())
                        } else if appState.status == .transcribing {
                            // Modern animated dots loader
                            HStack(spacing: 4) {
                                ForEach(0..<3) { index in
                                    Circle()
                                        .fill(everstageBlue)
                                        .frame(width: 6, height: 6)
                                        .modifier(BouncingDot(delay: Double(index) * 0.15))
                                }
                            }
                        } else {
                            // Mic icon for idle
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        }

                        // Text (not shown for idle)
                        if appState.status != .idle {
                            Text(displayText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary.opacity(0.9))
                        }
                    }
                }
                .padding(.horizontal, isMinimal ? 0 : 12)
                .padding(.vertical, isMinimal ? 0 : 6)
            }
            .frame(width: pillWidth, height: pillHeight)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appState.status)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }

    var isMinimal: Bool {
        appState.status == .idle && !isHovering && !appState.transcriptionEngine.isDownloading
    }

    var backgroundFill: some ShapeStyle {
        if isMinimal {
            return AnyShapeStyle(LinearGradient(
                colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            ))
        } else {
            return AnyShapeStyle(Material.ultraThinMaterial)
        }
    }

    var everstageBlue: Color {
        Color(red: 0.118, green: 0.333, blue: 0.976)
    }

    var borderGradient: LinearGradient {
        LinearGradient(
            colors: [everstageBlue, everstageBlue.opacity(0.7), everstageBlue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var shadowColor: Color {
        if appState.status == .recording {
            return everstageBlue.opacity(0.4)
        } else if isMinimal {
            return .clear
        } else {
            return .black.opacity(0.15)
        }
    }

    var displayText: String {
        switch appState.status {
        case .settingUp:
            return appState.transcriptionEngine.setupStatus
        case .idle:
            return "Evertalk"
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        }
    }

    var pillWidth: CGFloat {
        if appState.status == .settingUp {
            return 180  // Wider for setup text
        } else if appState.status == .recording {
            return 115
        } else if appState.status == .transcribing {
            return 120
        } else if isHovering {
            return 48  // Just mic icon
        } else {
            return 40  // Thin line
        }
    }

    var pillHeight: CGFloat {
        if appState.status == .settingUp || appState.status != .idle {
            return 28
        } else if isHovering {
            return 26
        } else {
            return 5  // Thin line
        }
    }
}

// Pulse animation modifier
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// Bouncing dot animation for loader
struct BouncingDot: ViewModifier {
    let delay: Double
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .offset(y: isAnimating ? -4 : 2)
            .animation(
                .easeInOut(duration: 0.4)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
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
