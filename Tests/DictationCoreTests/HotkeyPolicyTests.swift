import Testing
@testable import DictationCore

struct HotkeyPolicyTests {
    @Test func choicesAndPressReleaseWorkWithoutLeakingTriggerKeys() {
        for choice in HotkeyChoice.allCases {
            var policy = HotkeyPolicy(choice: choice)
            #expect(policy.process(.keyDown, keyCode: choice.keyCode, modifiers: choice.modifiers) == HotkeyDecision(consume: true, action: .begin))
            #expect(policy.isHeld)
            #expect(policy.process(.keyDown, keyCode: choice.keyCode, repeated: true) == HotkeyDecision(consume: true))
            #expect(policy.process(.keyUp, keyCode: choice.keyCode) == HotkeyDecision(consume: true, action: .release))
            #expect(!policy.isHeld)
            #expect(policy.process(.keyUp, keyCode: choice.keyCode) == HotkeyDecision())
        }
    }
    @Test func shiftTabRequiresShiftAndLeavesPlainTabAndSpaceAlone() {
        var policy = HotkeyPolicy(choice: .shiftTab)
        #expect(HotkeyChoice(rawValue: "shiftTab") == .shiftTab)
        #expect(policy.choice.keyCode == 48)
        #expect(policy.process(.keyDown, keyCode: 48) == HotkeyDecision())
        #expect(policy.process(.keyUp, keyCode: 48) == HotkeyDecision())
        #expect(policy.process(.keyDown, keyCode: 49, modifiers: [.shift]) == HotkeyDecision())
        #expect(policy.process(.keyDown, keyCode: 48, modifiers: [.shift, .command]) == HotkeyDecision())
        #expect(policy.process(.keyDown, keyCode: 48, modifiers: [.shift], repeated: true) == HotkeyDecision())
        #expect(policy.process(.keyDown, keyCode: 48, modifiers: [.shift]) == HotkeyDecision(consume: true, action: .begin))
        #expect(policy.process(.modifiers) == HotkeyDecision())
        #expect(policy.process(.keyUp, keyCode: 48) == HotkeyDecision(consume: true, action: .release))
    }
    @Test func unrelatedKeysAndOwnInjectionDoNotTriggerDictation() {
        var policy = HotkeyPolicy()
        #expect(policy.process(.keyDown, keyCode: 49, modifiers: [.control, .option, .command]) == HotkeyDecision())
        #expect(policy.process(.keyDown, keyCode: 49, modifiers: [.control, .option], repeated: true) == HotkeyDecision())
        #expect(policy.process(.keyDown, keyCode: 0) == HotkeyDecision())
        #expect(policy.process(.keyUp, keyCode: 0) == HotkeyDecision())
        #expect(policy.process(.pointer) == HotkeyDecision())
        #expect(policy.process(.modifiers) == HotkeyDecision())
        #expect(policy.process(.keyDown, keyCode: 49, modifiers: [.control, .option], ownEvent: true) == HotkeyDecision())
        #expect(policy.process(.keyDown, keyCode: 53) == HotkeyDecision())
        #expect(policy.process(.keyDown, keyCode: 53, sessionActive: true) == HotkeyDecision(consume: true, action: .cancel))
        #expect(policy.process(.keyDown, keyCode: 0, sessionActive: true) == HotkeyDecision(action: .activity))
        #expect(policy.process(.pointer, sessionActive: true) == HotkeyDecision(action: .activity))
        _ = policy.process(.keyDown, keyCode: 49, modifiers: [.control, .option])
        #expect(policy.process(.interrupted) == HotkeyDecision(action: .interrupted))
        #expect(!policy.isHeld)
    }
    @Test func customBindingsRoundTripAndRejectCorruptSettings() {
        for code: UInt16 in [0, 36, 48, 49, 53, 96, 123, 127] {
            for flags: UInt8 in [0, 1, 2, 4, 8, 15, 16, 31] {
                let choice = HotkeyChoice(keyCode: code, modifiers: KeyModifiers(rawValue: flags))!
                #expect(HotkeyChoice(rawValue: choice.rawValue) == choice)
                var policy = HotkeyPolicy(choice: choice)
                #expect(policy.process(.keyDown, keyCode: code, modifiers: choice.modifiers).action == .begin)
                #expect(policy.process(.keyUp, keyCode: code).action == .release)
            }
        }
        for raw in ["", "1", "x:2", "1:x", "1:256", "128:0", "57:0", "49:32", "255:0", "1:2:3"] {
            #expect(HotkeyChoice(rawValue: raw) == nil)
        }
        for code: UInt16 in [54,55,56,57,58,59,60,61,62,63,128,256] {
            #expect(HotkeyChoice(keyCode: code, modifiers: []) == nil)
        }
        for name in ["controlOptionSpace", "controlShiftSpace", "optionShiftSpace", "shiftTab"] {
            #expect(HotkeyChoice(rawValue: name) != nil)
        }
    }
    @Test func modifierOnlyChordsReleaseWhenAnyRequiredModifierChanges() {
        let choice = HotkeyChoice(keyCode: 255, modifiers: [.control, .function])!
        #expect(choice.isModifierOnly)
        var policy = HotkeyPolicy(choice: choice)
        #expect(policy.process(.modifiers, modifiers: [.control]).action == .none)
        #expect(policy.process(.modifiers, modifiers: [.control, .function]).action == .begin)
        #expect(policy.process(.modifiers, modifiers: [.control, .function]).action == .none)
        #expect(policy.process(.modifiers, modifiers: [.control]).action == .release)
        #expect(!policy.isHeld)
        #expect(policy.process(.modifiers, modifiers: []).action == .none)
        #expect(policy.process(.modifiers, modifiers: choice.modifiers, ownEvent: true).action == .none)
        #expect(policy.process(.modifiers, modifiers: choice.modifiers).action == .begin)
        #expect(policy.process(.interrupted).action == .interrupted)
        #expect(!policy.isHeld)
    }
}
