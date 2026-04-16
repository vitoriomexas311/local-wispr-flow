import AppKit
import DictationCore

enum LocalEvent {
    static let tag: Int64 = 0x4C_46_4C_4F_57
    static func modifiers(_ flags: CGEventFlags) -> KeyModifiers {
        var result: KeyModifiers = []
        if flags.contains(.maskControl) { result.insert(.control) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        if flags.contains(.maskCommand) { result.insert(.command) }
        return result
    }
}

@MainActor
final class HotkeyMonitor {
    var onAction: ((HotkeyAction) -> Void)?
    var sessionActive = false
    var policy = HotkeyPolicy()
    private(set) var activityRevision: UInt64 = 0
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    var isInstalled: Bool { tap != nil }
    var isHeld: Bool { policy.isHeld && CGEventSource.keyState(.combinedSessionState, key: 49) }
    var modifiersDown: Bool { !LocalEvent.modifiers(CGEventSource.flagsState(.combinedSessionState)).isEmpty }

    @discardableResult
    func install() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                         options: .defaultTap, eventsOfInterest: mask,
                                         callback: { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            return MainActor.assumeIsolated {
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(info).takeUnretainedValue()
                return monitor.receive(type, event)
            }
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func receive(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let kind: InputKind
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput: kind = .interrupted
        case .keyDown: kind = .keyDown
        case .keyUp: kind = .keyUp
        case .flagsChanged: kind = .modifiers
        default: kind = .pointer
        }
        let own = event.getIntegerValueField(.eventSourceUserData) == LocalEvent.tag &&
            event.getIntegerValueField(.eventSourceUnixProcessID) == Int64(getpid())
        let decision = policy.process(kind, keyCode: UInt16(clamping: event.getIntegerValueField(.keyboardEventKeycode)),
                                      modifiers: LocalEvent.modifiers(event.flags),
                                      repeated: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                                      ownEvent: own, sessionActive: sessionActive)
        if !own && (kind == .pointer || (kind == .keyDown && !decision.consume)) { activityRevision &+= 1 }
        // Do not retain the CGEvent or inspect its Unicode payload.
        if decision.action != .none { onAction?(decision.action) }
        if kind == .interrupted, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return decision.consume ? nil : Unmanaged.passUnretained(event)
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
    }
}
