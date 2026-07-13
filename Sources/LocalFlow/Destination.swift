import AppKit
import Carbon
import DictationCore

struct Destination {
    let pid: pid_t
    let window: AXUIElement
    let element: AXUIElement
    let selection: TextSelection?
    let method: InsertionMethod
}

@MainActor
enum DestinationAccess {

    private static func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success else { return nil }
        return result
    }

    private static func uiElement(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func selection(_ element: AXUIElement) -> TextSelection? {
        guard let value = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return TextSelection(location: range.location, length: range.length)
    }

    static func capture() -> Destination? {
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let app = AXUIElementCreateApplication(front.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.2)
        guard let window = uiElement(attribute(app, kAXFocusedWindowAttribute)),
              let element = uiElement(attribute(app, kAXFocusedUIElementAttribute)) else { return nil }
        AXUIElementSetMessagingTimeout(element, 0.2)
        let role = attribute(element, kAXRoleAttribute) as? String
        let subrole = attribute(element, kAXSubroleAttribute) as? String
        var settable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        guard let method = DestinationPolicy.method(bundleID: front.bundleIdentifier ?? "", role: role ?? "",
            subrole: subrole, enabled: attribute(element, kAXEnabledAttribute) as? Bool,
            selectionSettable: settable.boolValue, secureInput: IsSecureEventInputEnabled(),
            trusted: AXIsProcessTrusted(), ownApplication: front.processIdentifier == getpid()) else { return nil }
        return Destination(pid: front.processIdentifier, window: window, element: element,
                           selection: selection(element), method: method)
    }

    static func isCurrent(_ destination: Destination, checkSelection: Bool = true) -> Bool {
        let app = AXUIElementCreateApplication(destination.pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        guard let window = uiElement(attribute(app, kAXFocusedWindowAttribute)),
              let element = uiElement(attribute(app, kAXFocusedUIElementAttribute)) else { return false }
        return DestinationPolicy.remainsValid(
            applicationMatches: NSWorkspace.shared.frontmostApplication?.processIdentifier == destination.pid,
            windowMatches: CFEqual(window, destination.window), elementMatches: CFEqual(element, destination.element),
            secureInput: IsSecureEventInputEnabled(),
            secureField: attribute(element, kAXSubroleAttribute) as? String == kAXSecureTextFieldSubrole,
            original: destination.selection, current: selection(element), checkSelection: checkSelection)
    }

    static func insert(_ text: String, into destination: Destination, stillValid: @MainActor () -> Bool) async -> Bool {
        guard stillValid(), isCurrent(destination), TextPolicy.insertionText(text) == text, !text.isEmpty else { return false }
        switch destination.method {
        case .accessibility:
            // An uncertain AX result is never retried with keyboard injection.
            return AXUIElementSetAttributeValue(destination.element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
        case .keyboard:
            guard let batches = TextPolicy.unicodeBatches(text), let source = CGEventSource(stateID: .privateState) else { return false }
            for batch in batches {
                guard !Task.isCancelled, stillValid(), isCurrent(destination, checkSelection: false),
                      LocalEvent.modifiers(CGEventSource.flagsState(.combinedSessionState)).isEmpty,
                      let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                      let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return false }
                let characters = Array(batch.utf16)
                for event in [down, up] {
                    event.flags = []
                    event.setIntegerValueField(.eventSourceUserData, value: LocalEvent.tag)
                    event.keyboardSetUnicodeString(stringLength: characters.count, unicodeString: characters)
                    event.postToPid(destination.pid)
                }
                do { try await Task.sleep(for: .milliseconds(4)) } catch { return false }
            }
            return true
        }
    }
}
