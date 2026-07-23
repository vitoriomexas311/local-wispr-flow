import AVFoundation
import Speech
import DictationCore

/// Serial recognition requests, with a short replay buffer and bounded rotation backlog.
/// No speech request can be constructed without a fresh on-device capability check.
@MainActor
final class SpeechPipeline {
    var onResult: ((UInt64, String) -> Void)?
    var onFailure: ((UInt64, FailureCode) -> Void)?
    var onWindowMetrics: ((Double, Double, Int, Int, Double) -> Void)?
    var onPartialMetrics: ((Double, Int, Bool, Double, Double) -> Void)?
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var generation: UInt64 = 0
    private var window: UInt64 = 0
    private var live = false
    private var closing = false
    private var finishing = false
    private var closedAt: Double = 0
    private var origin: Double = 0
    private var replayDuration: Double = 0
    private var windowEnd: Double = 0
    private var history: [AudioChunk] = []
    private var pending: [AudioChunk] = []
    private var pendingSeconds: Double = 0
    private var timeline = TranscriptTimeline()

    @discardableResult
    func start(generation: UInt64) -> Bool {
        cancel()
        self.generation = generation
        live = true
        return openWindow(replay: [], start: 0)
    }

    private func openWindow(replay: [AudioChunk], start: Double) -> Bool {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            fail(.notReady)
            return false
        }
        self.recognizer = recognizer
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        self.request = request
        origin = start
        windowEnd = start
        replayDuration = replay.reduce(0) { $0 + $1.duration }
        closing = false
        history = []
        window &+= 1
        let expectedWindow = window
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.live, self.window == expectedWindow else { return }
                if let result, !result.isFinal {
                    let segments = result.bestTranscription.segments
                    self.onPartialMetrics?(self.origin, segments.count, result.speechRecognitionMetadata != nil,
                        segments.first?.timestamp ?? 0,
                        segments.last.map { $0.timestamp + $0.duration } ?? 0)
                }
                if let result, result.isFinal {
                    self.completeWindow(result.bestTranscription)
                } else if error != nil {
                    // Never put NSError descriptions or recognition content into diagnostics.
                    self.fail(.recognitionFailed)
                }
            }
        }
        for chunk in replay { appendToWindow(chunk) }
        return true
    }

    func append(_ chunks: [AudioChunk]) {
        for chunk in chunks {
            guard live else { return }
            if closing {
                guard pendingSeconds + chunk.duration <= 15 else { fail(.recognitionTimeout); return }
                pending.append(chunk)
                pendingSeconds += chunk.duration
            } else {
                appendToWindow(chunk)
                if windowEnd - origin >= 45 { closeWindow() }
            }
        }
    }

    private func appendToWindow(_ chunk: AudioChunk) {
        request?.append(chunk.buffer)
        windowEnd = chunk.start + chunk.duration
        history.append(chunk)
        // Whole audio buffers retain at least one second, bounded by one extra tap buffer.
        while history.count > 1, let first = history.first,
              windowEnd - first.start - first.duration >= 1 {
            history.removeFirst()
        }
    }

    func finish() {
        guard live else { return }
        finishing = true
        if !closing { closeWindow() }
    }

    private func closeWindow() {
        closing = true
        closedAt = ProcessInfo.processInfo.systemUptime
        request?.endAudio()
    }

    func checkTimeout(now: Double) {
        if live && closing && now - closedAt >= 12 { fail(.recognitionTimeout) }
    }

    private func completeWindow(_ transcription: SFTranscription) {
        let text = transcription.formattedString as NSString
        let segments = transcription.segments
        var words: [TimedWord] = []
        for (index, segment) in segments.enumerated() {
            let end = index + 1 < segments.count ? segments[index + 1].substringRange.location : text.length
            let start = segment.substringRange.location
            guard start >= 0, end >= start, end <= text.length else { fail(.recognitionFailed); return }
            words.append(TimedWord(text: text.substring(with: NSRange(location: start, length: end - start)),
                                   start: origin + segment.timestamp, duration: segment.duration))
        }
        do { try timeline.append(words, windowStart: origin, replayDuration: replayDuration) }
        catch { fail(.recognitionFailed); return }
        onWindowMetrics?(origin, windowEnd, words.count, timeline.words.count,
                         words.last.map { $0.start + $0.duration } ?? origin)
        request = nil
        task = nil
        recognizer = nil
        if finishing && pending.isEmpty {
            let text = timeline.text
            let completedGeneration = generation
            cancel()
            onResult?(completedGeneration, text)
            return
        }
        let replay = history
        let backlog = pending
        pending = []
        pendingSeconds = 0
        guard openWindow(replay: replay, start: replay.first?.start ?? windowEnd) else { return }
        append(backlog)
        if finishing && !closing { closeWindow() }
    }

    private func fail(_ reason: FailureCode) {
        let failedGeneration = generation
        cancel()
        onFailure?(failedGeneration, reason)
    }

    func cancel() {
        live = false
        window &+= 1
        task?.cancel()
        task = nil
        request = nil
        recognizer = nil
        history = []
        pending = []
        pendingSeconds = 0
        finishing = false
        closing = false
        timeline.clear()
    }
}
