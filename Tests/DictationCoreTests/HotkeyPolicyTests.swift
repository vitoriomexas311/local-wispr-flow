import Testing
@testable import DictationCore

struct HotkeyPolicyTests {
    @Test func choicesAndPressReleaseWorkWithoutLeakingSpace() {
        for choice in HotkeyChoice.allCases {
            var policy = HotkeyPolicy(choice: choice)
            #expect(policy.process(.keyDown, keyCode: 49, modifiers: choice.modifiers) == HotkeyDecision(consume: true, action: .begin))
            #expect(policy.isHeld)
            #expect(policy.process(.keyDown, keyCode: 49, repeated: true) == HotkeyDecision(consume: true))
            #expect(policy.process(.keyUp, keyCode: 49) == HotkeyDecision(consume: true, action: .release))
            #expect(!policy.isHeld)
            #expect(policy.process(.keyUp, keyCode: 49) == HotkeyDecision())
        }
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
