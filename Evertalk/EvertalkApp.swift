import SwiftUI
import AVFoundation
import Combine
import ApplicationServices

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
        // Request Accessibility permission - THIS IS REQUIRED FOR INLINE PASTE
        requestAccessibilityPermission()

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

        // Only show overlay if enabled in settings
        if appState.showOverlayEnabled {
            overlayWindow?.show()
        }

        // Listen for overlay visibility changes from Settings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOverlayVisibilityChanged(_:)),
            name: .overlayVisibilityChanged,
            object: nil
        )

        // Listen for reset position request
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResetOverlayPosition),
            name: .resetOverlayPosition,
            object: nil
        )
    }

    @objc private func handleOverlayVisibilityChanged(_ notification: Notification) {
        guard let enabled = notification.userInfo?["enabled"] as? Bool else { return }
        if enabled {
            overlayWindow?.show()
        } else {
            overlayWindow?.hide()
        }
    }

    @objc private func handleResetOverlayPosition() {
        overlayWindow?.resetPosition()
    }

    private func requestAccessibilityPermission() {
        // First check WITHOUT prompting
        let trusted = AXIsProcessTrusted()

        // Only show our custom dialog if not trusted
        if !trusted {
            // This will trigger the system prompt to add to Accessibility
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }
}
