import AppKit
import Carbon
import DictationCore

struct Destination {
    enum Method { case accessibility, keyboard }
    let pid: pid_t
    let window: AXUIElement
    let element: AXUIElement
    let selection: CFRange?
    let method: Method
}

@MainActor
enum DestinationAccess {
    private static let keyboardApplications: Set<String> = ["com.apple.Terminal", "com.apple.TextEdit", "com.apple.Safari", "com.google.Chrome"]

    private static func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success else { return nil }
        return result
    }

    private static func uiElement(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func selection(_ element: AXUIElement) -> CFRange? {
        guard let value = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return range
    }

    static func capture() -> Destination? {
        guard !IsSecureEventInputEnabled(), AXIsProcessTrusted(),
              let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != getpid() else { return nil }
        let app = AXUIElementCreateApplication(front.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.2)
        guard let window = uiElement(attribute(app, kAXFocusedWindowAttribute)),
              let element = uiElement(attribute(app, kAXFocusedUIElementAttribute)) else { return nil }
        AXUIElementSetMessagingTimeout(element, 0.2)
        let role = attribute(element, kAXRoleAttribute) as? String
        let subrole = attribute(element, kAXSubroleAttribute) as? String
        guard subrole != kAXSecureTextFieldSubrole, role == kAXTextFieldRole || role == kAXTextAreaRole || role == kAXComboBoxRole else { return nil }
        if let enabled = attribute(element, kAXEnabledAttribute) as? Bool, !enabled { return nil }
        var settable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        let method: Destination.Method
        if settable.boolValue && front.bundleIdentifier != "com.apple.Terminal" {
            method = .accessibility
        } else if keyboardApplications.contains(front.bundleIdentifier ?? "") {
            method = .keyboard
        } else { return nil }
        return Destination(pid: front.processIdentifier, window: window, element: element,
                           selection: selection(element), method: method)
    }

    static func isCurrent(_ destination: Destination, checkSelection: Bool = true) -> Bool {
        guard !IsSecureEventInputEnabled(), NSWorkspace.shared.frontmostApplication?.processIdentifier == destination.pid else { return false }
        let app = AXUIElementCreateApplication(destination.pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        guard let window = uiElement(attribute(app, kAXFocusedWindowAttribute)), CFEqual(window, destination.window),
              let element = uiElement(attribute(app, kAXFocusedUIElementAttribute)), CFEqual(element, destination.element),
              attribute(element, kAXSubroleAttribute) as? String != kAXSecureTextFieldSubrole else { return false }
        if checkSelection, let original = destination.selection, let current = selection(element) {
            return original.location == current.location && original.length == current.length
        }
        return true
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
