import AVFoundation
import DictationCore

struct AudioChunk {
    let buffer: AVAudioPCMBuffer
    let start: Double
    var duration: Double { Double(buffer.frameLength) / buffer.format.sampleRate }
}

enum AudioCaptureError: Error { case unavailable }

/// The audio tap only copies into a bounded queue. Recognition and UI run outside it.
final class AudioCapture {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var chunks: [AudioChunk] = []
    private var budget = BufferBudget(capacity: 0)
    private var sampleCursor: Int64 = 0
    private var failed = false
    private var active = false
    private var tapInstalled = false
    private var format: AVAudioFormat?
    var isRunning: Bool { engine.isRunning }

    func start() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw AudioCaptureError.unavailable }
        lock.withLock {
            self.format = format
            chunks = []
            budget = BufferBudget(capacity: Int(format.sampleRate * 5))
            sampleCursor = 0
            failed = false
            active = true
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.receive(buffer)
        }
        tapInstalled = true
        engine.prepare()
        do { try engine.start() } catch { stop(); throw AudioCaptureError.unavailable }
    }

    private func receive(_ buffer: AVAudioPCMBuffer) {
        lock.withLock {
            guard active, !failed else { return }
            guard buffer.format == format, budget.reserve(Int(buffer.frameLength)),
                  let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
                failed = true
                return
            }
            copy.frameLength = buffer.frameLength
            let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buffer.audioBufferList))
            let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
            guard source.count == destination.count else { failed = true; return }
            for index in source.indices {
                guard let from = source[index].mData, let to = destination[index].mData else { failed = true; return }
                memcpy(to, from, Int(source[index].mDataByteSize))
            }
            chunks.append(AudioChunk(buffer: copy, start: Double(sampleCursor) / buffer.format.sampleRate))
            sampleCursor += Int64(buffer.frameLength)
        }
    }

    func drain() -> (chunks: [AudioChunk], failed: Bool) {
        lock.withLock {
            let result = chunks
            chunks = []
            budget.reset()
            return (result, failed)
        }
    }

    func stop() {
        lock.withLock { active = false }
        engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
    }

    func discard() {
        stop()
        lock.withLock { chunks = []; budget.reset(); format = nil }
    }
}
