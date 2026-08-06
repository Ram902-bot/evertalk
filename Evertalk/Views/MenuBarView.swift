import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status indicator
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Start/Stop Recording
            Button(action: { appState.toggleRecording() }) {
                HStack {
                    Text(appState.status == .recording ? "Stop Recording" : "Start Recording")
                    Spacer()
                    Text("Cmd+Shift+Space")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .disabled(appState.status == .transcribing || appState.status == .settingUp)

            Divider()

            // Settings
            SettingsLink {
                Text("Settings...")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Quit
            Button("Quit Evertalk") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 220)
    }

    var statusColor: Color {
        switch appState.status {
        case .settingUp:
            return .blue
        case .idle:
            return .gray
        case .recording:
            return .red
        case .transcribing:
            return .orange
        }
    }

    var statusText: String {
        switch appState.status {
        case .settingUp:
            return "Setting up..."
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        }
    }
}
