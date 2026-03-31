import AppKit
import ApplicationServices

// Step 7: Injection tries AX kAXValueAttribute / kAXSelectedTextAttribute on the focused element,
// then falls back to Unicode CGEvent typing. VS Code and Chrome often work via AX for native/web fields;
// some controls expose no writable value—user must grant Accessibility and focus a text field first.

enum TextInjector {
    /// Insert at focused AX element; falls back to typing Unicode via CGEvent.
    static func insertAtFocusedElement(_ text: String) -> Bool {
        guard !text.isEmpty else { return true }

        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
        guard copyResult == .success, let focused else {
            return typeString(text)
        }

        let element = focused as! AXUIElement

        if insertViaAXValue(element, text) { return true }
        if insertViaSelectedText(element, text) { return true }
        return typeString(text)
    }

    private static func insertViaAXValue(_ element: AXUIElement, _ text: String) -> Bool {
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success, settable.boolValue else {
            return false
        }

        var current: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &current) == .success,
           let s = current as? String
        {
            let next = s + text
            return AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, next as CFTypeRef) == .success
        }

        return AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef) == .success
    }

    private static func insertViaSelectedText(_ element: AXUIElement, _ text: String) -> Bool {
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable) == .success, settable.boolValue else {
            return false
        }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
    }

    /// Fallback: synthesize keystrokes (slower; works for many editors).
    private static func typeString(_ text: String) -> Bool {
        let src = CGEventSource(stateID: .hidSystemState)
        for scalar in text.unicodeScalars {
            let ev = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
            var u = [UniChar](arrayLiteral: UniChar(scalar.value))
            ev?.keyboardSetUnicodeString(stringLength: u.count, unicodeString: &u)
            ev?.post(tap: .cghidEventTap)
            let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            up?.post(tap: .cghidEventTap)
        }
        return true
    }
}
