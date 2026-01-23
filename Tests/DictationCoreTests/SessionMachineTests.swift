import Testing
@testable import DictationCore

struct SessionMachineTests {
    private func recording() -> SessionMachine {
        var machine = SessionMachine()
        #expect(machine.begin(now: 100, ready: true, targetAllowed: true) == [.start(1)])
        return machine
    }

    private func tick(_ machine: inout SessionMachine, now: Double = 101,
                      held: Bool = true, modifiers: Bool = false,
                      target: Bool = true, permissions: Bool = true) -> [SessionEffect] {
        machine.tick(now: now, hotkeyHeld: held, modifiersDown: modifiers,
                     targetValid: target, permissionsValid: permissions)
    }

    @Test func refusesUnsafeStartsAndRepeatedHotkeyPresses() {
        var machine = SessionMachine()
        #expect(machine.begin(now: 0, ready: false, targetAllowed: true) == [.failed(.notReady)])
        #expect(machine.begin(now: 0, ready: true, targetAllowed: false) == [.failed(.unsupportedTarget)])
        #expect(tick(&machine).isEmpty)
        #expect(machine.abort().isEmpty)
        #expect(machine.release(now: 0).isEmpty)
        #expect(machine.recognitionFailed(generation: 0, reason: .recognitionFailed).isEmpty)
        #expect(machine.recognized(generation: 0, text: "late", now: 0).isEmpty)
        #expect(machine.insertionFinished(generation: 0, succeeded: true).isEmpty)
        machine = recording()
        #expect(machine.begin(now: 1, ready: true, targetAllowed: true).isEmpty)
        #expect(tick(&machine).isEmpty)
        #expect(machine.phase == .recording)
    }

    @Test func insertsOnceAfterFinalResultAndModifierRelease() {
        var machine = recording()
        #expect(machine.recognized(generation: 1, text: "premature", now: 101).isEmpty)
        #expect(machine.release(now: 102) == [.finalize(1)])
        #expect(machine.release(now: 102).isEmpty)
        #expect(tick(&machine, now: 103).isEmpty)
        #expect(machine.recognized(generation: 8, text: "stale", now: 103).isEmpty)
        #expect(machine.recognized(generation: 1, text: " Hello\nworld! ", now: 103).isEmpty)
        #expect(tick(&machine, now: 104, modifiers: true).isEmpty)
        #expect(tick(&machine, now: 105) == [.insert(1, "Hello world!")])
        #expect(tick(&machine, now: 105).isEmpty)
        #expect(machine.insertionFinished(generation: 8, succeeded: true).isEmpty)
        #expect(machine.insertionFinished(generation: 1, succeeded: true) == [.completed])
        #expect(machine.phase == .idle)
        #expect(machine.insertionFinished(generation: 1, succeeded: true).isEmpty)
        #expect(machine.recognized(generation: 1, text: "duplicate", now: 106).isEmpty)
    }

    @Test func abortInvalidatesPendingTextAndOldCallbacks() {
        var machine = recording()
        _ = machine.release(now: 101)
        _ = machine.recognized(generation: 1, text: "private draft", now: 102)
        #expect(machine.abort() == [.cancel(1), .failed(.cancelled)])
        #expect(machine.begin(now: 110, ready: true, targetAllowed: true) == [.start(2)])
        #expect(machine.recognitionFailed(generation: 1, reason: .recognitionFailed).isEmpty)
        #expect(machine.recognized(generation: 1, text: "stale", now: 111).isEmpty)
        #expect(tick(&machine, now: 111).isEmpty)
    }

    @Test func lostReleaseAndTenMinuteLimitFinalize() {
        var machine = recording()
        #expect(tick(&machine, held: false) == [.finalize(1)])
        machine = recording()
        #expect(tick(&machine, now: 699).isEmpty)
        #expect(tick(&machine, now: 700) == [.finalize(1)])
    }

    @Test func safetyAndTimeoutsDiscardContent() {
        var machine = recording()
        #expect(tick(&machine, target: false) == [.cancel(1), .failed(.destinationChanged)])
        machine = recording()
        #expect(tick(&machine, permissions: false) == [.cancel(1), .failed(.notReady)])
        machine = recording()
        _ = machine.release(now: 102)
        #expect(tick(&machine, now: 117) == [.cancel(1), .failed(.recognitionTimeout)])
        machine = recording()
        _ = machine.release(now: 102)
        _ = machine.recognized(generation: 1, text: "text", now: 103)
        #expect(tick(&machine, now: 113, modifiers: true) == [.cancel(1), .failed(.modifierTimeout)])
        machine = recording()
        #expect(machine.recognitionFailed(generation: 1, reason: .microphoneFailed) == [.cancel(1), .failed(.microphoneFailed)])
    }

    @Test func rejectsEmptyOversizedAndFailedInsertions() {
        var machine = recording()
        _ = machine.release(now: 102)
        #expect(machine.recognized(generation: 1, text: "\n\t", now: 103) == [.cancel(1), .failed(.emptyTranscript)])
        machine = recording()
        _ = machine.release(now: 102)
        #expect(machine.recognized(generation: 1, text: String(repeating: "a", count: 100_001), now: 103)
                == [.cancel(1), .failed(.transcriptTooLarge)])
        machine = recording()
        _ = machine.release(now: 102)
        _ = machine.recognized(generation: 1, text: "test", now: 103)
        _ = tick(&machine, now: 104)
        #expect(machine.insertionFinished(generation: 1, succeeded: false) == [.failed(.insertionFailed)])
    }
}
