public struct KeyModifiers: OptionSet, Equatable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let control = KeyModifiers(rawValue: 1)
    public static let option = KeyModifiers(rawValue: 2)
    public static let shift = KeyModifiers(rawValue: 4)
    public static let command = KeyModifiers(rawValue: 8)
}

public enum HotkeyChoice: String, CaseIterable, Sendable {
    case controlOptionSpace, controlShiftSpace, optionShiftSpace
    public var modifiers: KeyModifiers {
        switch self {
        case .controlOptionSpace: return [.control, .option]
        case .controlShiftSpace: return [.control, .shift]
        case .optionShiftSpace: return [.option, .shift]
        }
    }
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
            if keyCode == 49 && isHeld { return HotkeyDecision(consume: true) }
            if keyCode == 49 && modifiers == choice.modifiers && !repeated {
                isHeld = true
                return HotkeyDecision(consume: true, action: .begin)
            }
            if keyCode == 53 && sessionActive { return HotkeyDecision(consume: true, action: .cancel) }
            if sessionActive { return HotkeyDecision(action: .activity) }
        case .keyUp:
            if keyCode == 49 && isHeld {
                isHeld = false
                return HotkeyDecision(consume: true, action: .release)
            }
        case .pointer:
            if sessionActive { return HotkeyDecision(action: .activity) }
        case .modifiers:
            break
        }
        return HotkeyDecision()
    }
}
