public enum RecognitionEngine: String, CaseIterable, Sendable {
    case apple, whisperTiny

    public var title: String {
        switch self {
        case .apple: return "Apple on-device"
        case .whisperTiny: return "Whisper Tiny English · 32 MB"
        }
    }

    public func isReady(_ permissions: Readiness, modelInstalled: Bool, helperAvailable: Bool) -> Bool {
        switch self {
        case .apple: return permissions.blockingIssue == nil
        case .whisperTiny:
            return modelInstalled && helperAvailable && permissions.microphoneAuthorized &&
                permissions.accessibilityTrusted && permissions.inputMonitoringGranted
        }
    }
}

public struct WhisperWindow: Sendable {
    public let samples: [Float]
    public let start: Double
    public let replayDuration: Double
}

public enum WhisperAudioError: Error { case invalidSamples, durationExceeded }

/// Mono 16 kHz windows, at most 25 seconds each, with one second replay.
/// An extra second tolerates the controller's polling delay at its 600-second cap.
public struct WhisperWindows: Sendable {
    private var buffered: [Float] = []
    private var cursor = 0
    private var total = 0
    public init() {}

    public mutating func append(_ samples: [Float]) throws -> [WhisperWindow] {
        guard samples.count <= 400_000, samples.allSatisfy({ $0.isFinite && abs($0) <= 1 }) else {
            throw WhisperAudioError.invalidSamples
        }
        guard total + samples.count <= 601 * 16_000 else { throw WhisperAudioError.durationExceeded }
        total += samples.count
        buffered.append(contentsOf: samples)
        var result: [WhisperWindow] = []
        while buffered.count >= 400_000 {
            result.append(window(Array(buffered.prefix(400_000))))
            buffered.removeFirst(384_000)
            cursor += 384_000
        }
        return result
    }

    public mutating func finish() -> WhisperWindow? {
        defer { buffered = [] }
        guard buffered.count > (cursor == 0 ? 0 : 16_000) else { return nil }
        return window(buffered)
    }

    private func window(_ samples: [Float]) -> WhisperWindow {
        WhisperWindow(samples: samples, start: Double(cursor) / 16_000,
                      replayDuration: cursor == 0 ? 0 : 1)
    }
}
