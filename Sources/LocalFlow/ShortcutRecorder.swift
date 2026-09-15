import AppKit
import Carbon
import DictationCore

@MainActor
final class ShortcutRecorder {
    var onFinish: ((HotkeyChoice?) -> Void)?
    var onHint: ((String) -> Void)?
    private var monitor: Any?
    private var timeout: Timer?
    private var pending: KeyModifiers = []

    func start() {
        stop()
        pending = []
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return event }
                let flags = LocalEvent.modifiers(CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
                if event.type == .flagsChanged {
                    if event.keyCode == 57 { self.onHint?("Caps Lock toggles on macOS. Choose a key or modifier you can hold."); return nil }
                    self.pending.formUnion(flags)
                    if flags.isEmpty, !self.pending.isEmpty {
                        self.finish(HotkeyChoice(keyCode: 255, modifiers: self.pending))
                    } else { self.onHint?("Release modifiers to save, or press another key.") }
                } else if !event.isARepeat {
                    self.finish(HotkeyChoice(keyCode: event.keyCode, modifiers: flags))
                }
                return nil
            }
        }
        timeout = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish(nil) }
        }
    }
    func finish(_ choice: HotkeyChoice?) {
        stop()
        onFinish?(choice)
    }
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        timeout?.invalidate()
        timeout = nil
    }
}

extension HotkeyChoice {
    @MainActor var displayName: String { displayKeys.joined() }

    @MainActor var displayKeys: [String] {
        var symbols: [String] = []
        for (flag, label): (KeyModifiers, String) in [(.control,"⌃"),(.option,"⌥"),(.shift,"⇧"),(.command,"⌘"),(.function,"fn")] {
            if modifiers.contains(flag) { symbols.append(label) }
        }
        if isModifierOnly { return symbols }
        let special: [UInt16: String] = [36:"Return",48:"Tab",49:"Space",51:"Delete",53:"Esc",71:"Clear",76:"Enter",114:"Help",115:"Home",116:"Page Up",117:"Forward Delete",119:"End",121:"Page Down",123:"←",124:"→",125:"↓",126:"↑"]
        if let name = special[keyCode] { return symbols + [name] }
        let functionKeys: [UInt16] = [122,120,99,118,96,97,98,100,101,109,103,111,105,107,113,106,64,79,80,90]
        if let index = functionKeys.firstIndex(of: keyCode) { return symbols + ["F\(index + 1)"] }
        // Translate the physical shortcut key using the active layout, without reading typed text.
        let input = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        if let pointer = TISGetInputSourceProperty(input, kTISPropertyUnicodeKeyLayoutData) {
            let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue()
            if let bytes = CFDataGetBytePtr(data) {
                let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
                var dead: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 8)
                let status = UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDisplay), 0,
                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, 8, &length, &characters)
                if status == noErr, length > 0 {
                    return symbols + [String(utf16CodeUnits: characters, count: length).uppercased()]
                }
            }
        }
        return symbols + ["Key \(keyCode)"]
    }
}
