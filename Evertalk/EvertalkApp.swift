import SwiftUI
import AVFoundation
import Combine

@main
struct EvertalkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appDelegate.appState)
        } label: {
            Image(systemName: appDelegate.appState.status == .recording ? "mic.fill" : "mic")
        }

        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let hotkeyManager = HotkeyManager()
    var overlayWindow: OverlayWindowController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                print("Microphone permission denied")
            }
        }

        // Connect hotkey to app state
        hotkeyManager.onHotkeyPressed = { [weak self] in
            Task { @MainActor in
                self?.appState.toggleRecording()
            }
        }

        // Setup overlay window
        overlayWindow = OverlayWindowController(appState: appState)

        // Observe recording state to show/hide overlay
        appState.$showOverlay
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                if show {
                    self?.overlayWindow?.show()
                } else {
                    self?.overlayWindow?.hide()
                }
            }
            .store(in: &cancellables)
    }
}
