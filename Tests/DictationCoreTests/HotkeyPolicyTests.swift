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
}
