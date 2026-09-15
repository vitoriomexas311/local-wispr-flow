import AVFoundation
import DictationCore
import Darwin

struct WhisperSegment: Decodable {
    let text: String
    let start: Double
    let end: Double
}

/// Serial worker owner. Cancellation can terminate a decoding process immediately.
final class WhisperWorker: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    let executable: URL
    let model: URL
    init(executable: URL, model: URL) { self.executable = executable; self.model = model }

    func cancel() {
        lock.withLock {
            cancelled = true
            if let process, process.isRunning { process.terminate() }
        }
    }

    func run(_ samples: [Float]) -> [WhisperSegment]? {
        let child = Process()
        let input = Pipe(), output = Pipe()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
        child.arguments = ["-p", "(version 1)(allow default)(deny network*)(deny file-write*)", executable.path, model.path]
        child.environment = ["PATH": "/usr/bin:/bin", "LC_ALL": "C"]
        child.standardInput = input
        child.standardOutput = output
        child.standardError = FileHandle.nullDevice
        _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        let started: Bool = lock.withLock {
            guard !cancelled else { return false }
            do { try child.run(); process = child; return true } catch { return false }
        }
        guard started else { return nil }
        defer {
            try? input.fileHandleForWriting.close()
            try? output.fileHandleForReading.close()
            if child.isRunning { child.terminate() }
            child.waitUntilExit()
            lock.withLock { process = nil }
        }
        do {
            var count = UInt32(samples.count).littleEndian
            try withUnsafeBytes(of: &count) { try input.fileHandleForWriting.write(contentsOf: Data($0)) }
            try samples.withUnsafeBytes { try input.fileHandleForWriting.write(contentsOf: Data($0)) }
            try input.fileHandleForWriting.close()
            var result = Data()
            while let part = try output.fileHandleForReading.read(upToCount: 16_384), !part.isEmpty {
                guard result.count + part.count <= 1_000_000 else { return nil }
                result.append(part)
            }
            child.waitUntilExit()
            guard child.terminationStatus == 0, !lock.withLock({ cancelled }) else { return nil }
            return try JSONDecoder().decode([WhisperSegment].self, from: result)
        } catch { return nil }
    }
}

@MainActor
final class WhisperPipeline: RecognitionBackend {
    var onResult: ((UInt64, String) -> Void)?
    var onDiagnosticFailure: ((String) -> Void)?
    var onFailure: ((UInt64, FailureCode) -> Void)?
    private let queue = DispatchQueue(label: "LocalFlow.Whisper", qos: .userInitiated)
    private var worker: WhisperWorker?
    private var converter: AVAudioConverter?
    private var windows = WhisperWindows()
    private var pending: [WhisperWindow] = []
    private var timeline = TranscriptTimeline()
    private var generation: UInt64 = 0
    private var epoch = UUID()
    private var live = false
    private var processing = false
    private var processingStarted: Double = 0
    private var finishing = false

    func start(generation: UInt64) -> Bool {
        cancel()
        self.generation = generation
        guard TinyModel.installed, TinyModel.helperAvailable else { fail(.notReady); return false }
        worker = WhisperWorker(executable: TinyModel.helper, model: TinyModel.url)
        live = true
        return true
    }

    func append(_ chunks: [AudioChunk]) {
        guard live, !finishing else { return }
        do {
            for chunk in chunks {
                if converter == nil {
                    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                                     channels: 1, interleaved: false) else { throw AudioCaptureError.unavailable }
                    converter = AVAudioConverter(from: chunk.buffer.format, to: format)
                }
                guard let converter, converter.inputFormat == chunk.buffer.format,
                      let converted = AVAudioPCMBuffer(pcmFormat: converter.outputFormat,
                        frameCapacity: AVAudioFrameCount(ceil(Double(chunk.buffer.frameLength) * 16_000 / chunk.buffer.format.sampleRate)) + 64) else {
                    throw AudioCaptureError.unavailable
                }
                var provided = false
                var error: NSError?
                let status = converter.convert(to: converted, error: &error) { _, state in
                    if provided { state.pointee = .noDataNow; return nil }
                    provided = true
                    state.pointee = .haveData
                    return chunk.buffer
                }
                guard status != .error, error == nil, let channel = converted.floatChannelData?[0] else {
                    throw AudioCaptureError.unavailable
                }
                let samples = Array(UnsafeBufferPointer(start: channel, count: Int(converted.frameLength)))
                pending.append(contentsOf: try windows.append(samples))
                guard pending.count <= 3 else { throw AudioCaptureError.unavailable }
            }
            pump()
        } catch { onDiagnosticFailure?("audio-conversion"); fail(.recognitionFailed) }
    }

    func finish() {
        guard live else { return }
        do {
            if let converter {
                var ended = false
                for _ in 0..<8 {
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: 1024) else {
                        throw AudioCaptureError.unavailable
                    }
                    var error: NSError?
                    let status = converter.convert(to: buffer, error: &error) { _, state in
                        state.pointee = .endOfStream
                        return nil
                    }
                    guard status != .error, error == nil, let channel = buffer.floatChannelData?[0] else {
                        throw AudioCaptureError.unavailable
                    }
                    pending.append(contentsOf: try windows.append(Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))))
                    if status == .endOfStream { ended = true; break }
                }
                guard ended else { throw AudioCaptureError.unavailable }
            }
            finishing = true
            if let tail = windows.finish() { pending.append(tail) }
            guard pending.count <= 3 else { throw AudioCaptureError.unavailable }
            pump()
        } catch { onDiagnosticFailure?("converter-finalization"); fail(.recognitionFailed) }
    }

    private func pump() {
        guard live, !processing else { return }
        guard !pending.isEmpty else {
            if finishing {
                let text = timeline.text, id = generation
                cancel()
                onResult?(id, text)
            }
            return
        }
        guard let worker else { fail(.recognitionFailed); return }
        let window = pending.removeFirst(), ticket = epoch
        processing = true
        processingStarted = ProcessInfo.processInfo.systemUptime
        queue.async { [weak self] in
            let result = worker.run(window.samples)
            DispatchQueue.main.async {
                guard let self, self.live, self.epoch == ticket else { return }
                self.processing = false
                guard let result else { self.onDiagnosticFailure?("worker"); self.fail(.recognitionFailed); return }
                do {
                    let duration = Double(window.samples.count) / 16_000
                    guard result.allSatisfy({ $0.start >= 0 && $0.end.isFinite && $0.end <= duration + 0.1 && $0.end >= $0.start }) else {
                        throw TimelineError.invalidTiming
                    }
                    let words = result.map { TimedWord(text: $0.text, start: window.start + $0.start, duration: $0.end - $0.start) }
                    try self.timeline.append(words, windowStart: window.start, replayDuration: window.replayDuration)
                    self.pump()
                } catch { self.onDiagnosticFailure?("timeline"); self.fail(.recognitionFailed) }
            }
        }
    }

    func checkTimeout(now: Double) {
        if processing && now - processingStarted >= 12 { fail(.recognitionTimeout) }
    }

    func cancel() {
        epoch = UUID()
        live = false
        worker?.cancel()
        worker = nil
        converter = nil
        windows = WhisperWindows()
        pending = []
        timeline.clear()
        processing = false
        finishing = false
    }

    private func fail(_ reason: FailureCode) {
        let id = generation
        cancel()
        onFailure?(id, reason)
    }
}
