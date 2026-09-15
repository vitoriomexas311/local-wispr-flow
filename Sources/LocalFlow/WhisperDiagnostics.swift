import AVFoundation
import DictationCore

/// Opt-in platform test using generated, non-sensitive PCM. Never opens the mic.
@MainActor
enum WhisperDiagnostics {
    static func cancellation() -> Int32 {
        guard TinyModel.installed, TinyModel.helperAvailable,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                         channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 400_000),
              let channel = buffer.floatChannelData?[0] else { return 2 }
        buffer.frameLength = 400_000
        for i in 0..<400_000 { channel[i] = Float(sin(Double(i) * 0.08) * 0.2) }
        let pipeline = WhisperPipeline()
        var unexpectedCallback = false
        var failure = false
        var completed = false
        pipeline.onResult = { generation, text in
            if generation != 2 || !text.isEmpty { unexpectedCallback = true }
            completed = true
        }
        pipeline.onFailure = { _, _ in failure = true }
        guard pipeline.start(generation: 1) else { return 2 }
        pipeline.append([AudioChunk(buffer: buffer, start: 0)])
        // Let the background worker enter the actual decoding request, then cancel.
        let until = Date(timeIntervalSinceNow: 0.1)
        while Date() < until { _ = RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.005)) }
        pipeline.cancel()
        guard pipeline.start(generation: 2) else { return 2 }
        // A fresh empty session must complete independently of the killed worker.
        pipeline.finish()
        let deadline = Date(timeIntervalSinceNow: 2)
        while Date() < deadline { _ = RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01)) }
        pipeline.cancel()
        let passed = completed && !unexpectedCallback && !failure
        print("{\"kind\":\"whisper-platform-cancellation-and-stale-results\",\"status\":\"\(passed ? "passed" : "failed")\"}")
        return passed ? 0 : 1
    }
}
