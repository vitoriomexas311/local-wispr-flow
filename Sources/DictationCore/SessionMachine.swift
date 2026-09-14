public enum SessionPhase: Equatable, Sendable {
    case idle, recording, finalizing, waitingForModifiers, inserting
}

public enum FailureCode: String, Sendable {
    case notReady, unsupportedTarget, destinationChanged, cancelled
    case recognitionFailed, recognitionTimeout, modifierTimeout, insertionFailed
    case microphoneFailed, listenerInterrupted, emptyTranscript, transcriptTooLarge
}

public enum SessionEffect: Equatable, Sendable {
    case start(UInt64), finalize(UInt64), cancel(UInt64)
    case insert(UInt64, String), failed(FailureCode), completed
}

/// All timestamps are monotonic seconds supplied by the caller, never wall time.
/// Every asynchronous callback carries the generation that created it.
public struct SessionMachine: Sendable {
    public private(set) var phase: SessionPhase = .idle
    public private(set) var generation: UInt64 = 0
    public private(set) var startedAt: Double = 0
    private var deadline: Double = 0
    private var pendingText = ""

    public init() {}

    public mutating func begin(now: Double, ready: Bool, targetAllowed: Bool) -> [SessionEffect] {
        guard phase == .idle else { return [] }
        guard ready else { return [.failed(.notReady)] }
        guard targetAllowed else { return [.failed(.unsupportedTarget)] }
        generation &+= 1
        startedAt = now
        pendingText = ""
        phase = .recording
        return [.start(generation)]
    }

    public mutating func release(now: Double) -> [SessionEffect] {
        guard phase == .recording else { return [] }
        phase = .finalizing
        deadline = now + 15
        return [.finalize(generation)]
    }

    public mutating func recognized(generation: UInt64, text: String, now: Double) -> [SessionEffect] {
        guard generation == self.generation, phase == .finalizing else { return [] }
        guard text.utf8.count <= 100_000 else { return abort(.transcriptTooLarge) }
        pendingText = TextPolicy.insertionText(text)
        guard !pendingText.isEmpty else { return abort(.emptyTranscript) }
        phase = .waitingForModifiers
        deadline = now + 10
        return []
    }

    public mutating func recognitionFailed(generation: UInt64, reason: FailureCode) -> [SessionEffect] {
        guard generation == self.generation, phase != .idle else { return [] }
        return abort(reason)
    }

    public mutating func tick(now: Double, hotkeyHeld: Bool, modifiersDown: Bool,
                              targetValid: Bool, permissionsValid: Bool) -> [SessionEffect] {
        guard phase != .idle else { return [] }
        guard permissionsValid else { return abort(.notReady) }
        guard targetValid else { return abort(.destinationChanged) }
        switch phase {
        case .recording:
            if !hotkeyHeld || now - startedAt >= 600 { return release(now: now) }
        case .finalizing:
            if now >= deadline { return abort(.recognitionTimeout) }
        case .waitingForModifiers:
            if now >= deadline { return abort(.modifierTimeout) }
            if !modifiersDown {
                phase = .inserting
                let text = pendingText
                pendingText = ""
                return [.insert(generation, text)]
            }
        case .inserting, .idle:
            break
        }
        return []
    }

    public mutating func insertionFinished(generation: UInt64, succeeded: Bool) -> [SessionEffect] {
        guard generation == self.generation, phase == .inserting else { return [] }
        phase = .idle
        return succeeded ? [.completed] : [.failed(.insertionFailed)]
    }

    public mutating func abort(_ reason: FailureCode = .cancelled) -> [SessionEffect] {
        guard phase != .idle else { return [] }
        phase = .idle
        pendingText = ""
        return [.cancel(generation), .failed(reason)]
    }
}
