import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var launchAtLogin = false
    @State private var playSounds = true

    var body: some View {
        Form {
            Section {
                LabeledContent("Hotkey") {
                    Text("Cmd + Shift + Space")
                        .foregroundColor(.secondary)
                }

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                Toggle("Play Sounds", isOn: $playSounds)
                    .onChange(of: playSounds) { _, newValue in
                        appState.playSounds = newValue
                    }
            } header: {
                Text("General")
            }

            Section {
                LabeledContent("Model") {
                    Text("Whisper Base (English)")
                        .foregroundColor(.secondary)
                }

                LabeledContent("Model Size") {
                    Text("~140 MB")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Transcription")
            }

            Section {
                Text("All audio is processed locally on your Mac. Nothing is sent to the cloud.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Privacy")
            }

            Section {
                LabeledContent("Version") {
                    Text("2.0.0")
                        .foregroundColor(.secondary)
                }

                Link("View on GitHub", destination: URL(string: "https://github.com/everstage/evertalk")!)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 350)
        .onAppear {
            launchAtLogin = appState.launchAtLogin
            playSounds = appState.playSounds
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            appState.launchAtLogin = enabled
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}
