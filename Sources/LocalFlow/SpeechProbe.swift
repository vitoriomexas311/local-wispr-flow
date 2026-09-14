import AVFoundation
import Speech
import DictationCore

/// Explicit developer diagnostic. Reads only the supplied fixture and reference;
/// reports numeric accuracy/timing, never recognized or expected content.
@MainActor
enum SpeechProbe {
    static func run(audioURL: URL, expectedURL: URL) -> Int32 {
        let started = ProcessInfo.processInfo.systemUptime
        let readiness = Permissions.snapshot()
        guard readiness.speechAuthorized, readiness.supportsOnDevice, readiness.recognizerAvailable else {
            report(["status": "blocked", "reason": "local-speech-not-ready"])
            return 2
        }
        guard let file = try? AVAudioFile(forReading: audioURL), file.processingFormat.sampleRate > 0,
              Double(file.length) / file.processingFormat.sampleRate <= 600,
              let expected = try? String(contentsOf: expectedURL, encoding: .utf8), expected.utf8.count <= 100_000 else {
            report(["status": "failed", "reason": "invalid-fixture"])
            return 1
        }
        let pipeline = SpeechPipeline()
        pipeline.onDiagnosticFailure = { stage in
            report(["kind": "recognition-failure-stage", "stage": stage.rawValue])
        }
        pipeline.onWindowMetrics = { start, end, segments, accumulated, lastWordEnd in
            report(["kind": "recognition-window", "audioStart": start, "audioEnd": end,
                    "segments": segments, "accumulatedSegments": accumulated, "lastWordEnd": lastWordEnd])
        }
        pipeline.onPartialMetrics = { start, count, metadata, first, last in
            report(["kind": "partial-metrics", "windowStart": start, "segments": count,
                    "hasSpeechMetadata": metadata, "firstTimestamp": first, "lastTimestamp": last])
        }
        var finished = false
        var passed = false
        pipeline.onResult = { _, text in
            let score = SpeechScore(expected: expected, recognized: TextPolicy.insertionText(text))
            passed = score.expectedWords > 0 && score.wordErrorRate <= 0.15
            report(["status": passed ? "passed" : "failed", "kind": "injected-audio-real-apple-recognizer",
                    "expectedWords": score.expectedWords, "recognizedWords": score.recognizedWords,
                    "wordErrors": score.errors, "wordErrorRate": score.wordErrorRate,
                    "elapsedSeconds": ProcessInfo.processInfo.systemUptime - started])
            finished = true
        }
        pipeline.onFailure = { _, reason in
            report(["status": "failed", "reason": reason.rawValue])
            finished = true
        }
        guard pipeline.start(generation: 1) else { return 1 }
        let duration = Double(file.length) / file.processingFormat.sampleRate
        let deadline = started + duration + 20
        var ended = false
        while !finished && ProcessInfo.processInfo.systemUptime < deadline {
            let now = ProcessInfo.processInfo.systemUptime
            let position = file.framePosition
            if !ended && now - started >= Double(position) / file.processingFormat.sampleRate {
                if position >= file.length {
                    pipeline.finish()
                    ended = true
                } else if let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 1024) {
                    do {
                        try file.read(into: buffer, frameCount: 1024)
                        pipeline.append([AudioChunk(buffer: buffer, start: Double(position) / file.processingFormat.sampleRate)])
                    } catch {
                        pipeline.cancel()
                        report(["status": "failed", "reason": "fixture-read-failed"])
                        return 1
                    }
                } else { break }
            }
            pipeline.checkTimeout(now: now)
            _ = RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        pipeline.cancel()
        if !finished { report(["status": "failed", "reason": "probe-timeout"]) }
        return passed ? 0 : 1
    }

    private static func report(_ value: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) { print(text); fflush(stdout) }
    }
}
