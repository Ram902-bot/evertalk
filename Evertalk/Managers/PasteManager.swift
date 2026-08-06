import AppKit
import ApplicationServices

class PasteManager {
    private var previousApp: NSRunningApplication?

    /// Save the frontmost app before recording starts
    func saveFrontmostApp() {
        previousApp = NSWorkspace.shared.frontmostApplication
    }

    /// Paste text at the cursor position in the previously active app
    func pasteText(_ text: String) {
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Activate previous app and paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.previousApp?.activate()

            // Wait for activation, then simulate Cmd+V
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.simulateCmdV()
            }
        }
    }

    private func simulateCmdV() {
        guard AXIsProcessTrusted() else { return }

        let vKeyCode: CGKeyCode = 9  // 'v' key

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)

        usleep(100000)

        keyUp.flags = []
        keyUp.post(tap: .cghidEventTap)
    }
}
