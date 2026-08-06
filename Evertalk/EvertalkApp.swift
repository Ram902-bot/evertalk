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

        // Setup overlay window and show it always
        overlayWindow = OverlayWindowController(appState: appState)
        overlayWindow?.show()
    }

    private func requestAccessibilityPermission() {
        // Check if we have accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            // Show alert explaining why we need this
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "Evertalk needs Accessibility permission to paste transcribed text directly into your apps.\n\n1. Click 'Open Settings' below\n2. Find 'Evertalk' in the list\n3. Toggle it ON\n4. Restart Evertalk"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Later")

                if alert.runModal() == .alertFirstButtonReturn {
                    // Open System Settings to Accessibility
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
