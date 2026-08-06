import AppKit
import ApplicationServices

class PasteManager {
    /// Attempts to paste text at the current cursor position.
    /// Returns true if successful, false if fallback to clipboard is needed.
    func pasteText(_ text: String) -> Bool {
        // First, copy to clipboard as backup
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Try to paste using Accessibility API
        if insertTextViaAccessibility(text) {
            return true
        }

        // Fallback: simulate Cmd+V
        return simulatePaste()
    }

    private func insertTextViaAccessibility(_ text: String) -> Bool {
        // Get the focused element
        guard let focusedElement = getFocusedElement() else {
            return false
        }

        // Try to set the value directly
        let textValue = text as CFString
        let result = AXUIElementSetAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            textValue
        )

        if result == .success {
            return true
        }

        // Try inserting at selection
        return insertAtSelection(element: focusedElement, text: text)
    }

    private func getFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        ) == .success else {
            return nil
        }

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedApp as! AXUIElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success else {
            return nil
        }

        return (focusedElement as! AXUIElement)
    }

    private func insertAtSelection(element: AXUIElement, text: String) -> Bool {
        // Get current selection range
        var selectedRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRange
        ) == .success else {
            return false
        }

        // Set selected text
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )

        return result == .success
    }

    private func simulatePaste() -> Bool {
        // Simulate Cmd+V keypress
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else {
            return false
        }
        keyDown.flags = .maskCommand

        // Key up
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return false
        }
        keyUp.flags = .maskCommand

        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }
}
