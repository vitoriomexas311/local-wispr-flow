public struct KeyModifiers: OptionSet, Equatable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let control = KeyModifiers(rawValue: 1)
    public static let option = KeyModifiers(rawValue: 2)
    public static let shift = KeyModifiers(rawValue: 4)
    public static let command = KeyModifiers(rawValue: 8)
    public static let function = KeyModifiers(rawValue: 16)
}

/// A physical key plus any combination of the four standard modifiers.
/// Raw values retain the original presets so existing installations migrate unchanged.
public struct HotkeyChoice: Equatable, Sendable, RawRepresentable, CaseIterable {
    public let keyCode: UInt16
    public let modifiers: KeyModifiers
    public init?(keyCode: UInt16, modifiers: KeyModifiers) {
        guard (keyCode < 128 || (keyCode == 255 && !modifiers.isEmpty)), modifiers.rawValue < 32,
              ![54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode) else { return nil }
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    private init(_ keyCode: UInt16, _ modifiers: KeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    public static let controlOptionSpace = Self(49, [.control, .option])
    public static let controlShiftSpace = Self(49, [.control, .shift])
    public static let optionShiftSpace = Self(49, [.option, .shift])
    public static let shiftTab = Self(48, [.shift])
    public static let allCases: [Self] = [.controlOptionSpace, .controlShiftSpace, .optionShiftSpace, .shiftTab]
    public init?(rawValue: String) {
        let legacy = ["controlOptionSpace", "controlShiftSpace", "optionShiftSpace", "shiftTab"]
        if let index = legacy.firstIndex(of: rawValue) { self = Self.allCases[index]; return }
        let parts = rawValue.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let code = UInt16(parts[0]), let flags = UInt8(parts[1]),
              let binding = Self(keyCode: code, modifiers: KeyModifiers(rawValue: flags)) else { return nil }
        self = binding
    }
    public var isModifierOnly: Bool { keyCode == 255 }
    public var rawValue: String { "\(keyCode):\(modifiers.rawValue)" }
}

public enum InputKind: Sendable { case keyDown, keyUp, modifiers, pointer, interrupted }
public enum HotkeyAction: Equatable, Sendable { case none, begin, release, cancel, activity, interrupted }
public struct HotkeyDecision: Equatable, Sendable {
    public let consume: Bool
    public let action: HotkeyAction
    public init(consume: Bool = false, action: HotkeyAction = .none) {
        self.consume = consume
        self.action = action
    }
}

public struct HotkeyPolicy: Sendable {
    public var choice: HotkeyChoice
    public private(set) var isHeld = false
    public init(choice: HotkeyChoice = .controlOptionSpace) { self.choice = choice }

    public mutating func process(_ kind: InputKind, keyCode: UInt16 = 0, modifiers: KeyModifiers = [],
                                  repeated: Bool = false, ownEvent: Bool = false,
                                  sessionActive: Bool = false) -> HotkeyDecision {
        if ownEvent { return HotkeyDecision() }
        switch kind {
        case .interrupted:
            isHeld = false
            return HotkeyDecision(action: .interrupted)
        case .keyDown:
            if keyCode == choice.keyCode && isHeld { return HotkeyDecision(consume: true) }
            if keyCode == choice.keyCode && modifiers == choice.modifiers && !repeated {
                isHeld = true
                return HotkeyDecision(consume: true, action: .begin)
            }
            if keyCode == 53 && sessionActive { return HotkeyDecision(consume: true, action: .cancel) }
            if sessionActive { return HotkeyDecision(action: .activity) }
        case .keyUp:
            if keyCode == choice.keyCode && isHeld {
                isHeld = false
                return HotkeyDecision(consume: true, action: .release)
            }
        case .pointer:
            if sessionActive { return HotkeyDecision(action: .activity) }
        case .modifiers:
            if choice.isModifierOnly {
                if isHeld && modifiers != choice.modifiers {
                    isHeld = false
                    return HotkeyDecision(action: .release)
                }
                if !isHeld && modifiers == choice.modifiers {
                    isHeld = true
                    return HotkeyDecision(action: .begin)
                }
            }
        }
        return HotkeyDecision()
    }
}
