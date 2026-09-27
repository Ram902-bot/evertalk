import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

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

            if appState.status == .setupFailed {
                if let error = appState.transcriptionEngine.setupError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                }

                Button("Retry Setup") {
                    appState.retrySetup()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

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
            .disabled(appState.status == .transcribing || appState.status == .settingUp || appState.status == .setupFailed)

            Divider()

            // Update
            switch appState.updateChecker.state {
            case .available(let version):
                Button("Update to \(version)...") {
                    appState.updateChecker.installUpdate()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider()
            case .updating:
                Text("Updating Evertalk...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                Divider()
            case .failed(let reason):
                Button("Update failed - retry") {
                    appState.updateChecker.installUpdate()
                }
                .buttonStyle(.plain)
                .help(reason)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider()
            case .idle:
                EmptyView()
            }

            // Settings
            Button("Settings...") {
                openSettings()
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
        case .setupFailed:
            return .orange
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
        case .setupFailed:
            return "Setup failed"
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        }
    }
}
