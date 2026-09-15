import Testing
@testable import DictationCore

@Test func engineReadiness() {
    let ready = Readiness(speechAuthorized: true, supportsOnDevice: true, recognizerAvailable: true,
                          microphoneAuthorized: true, accessibilityTrusted: true, inputMonitoringGranted: true)
    #expect(RecognitionEngine.apple.title == "Apple on-device")
    #expect(RecognitionEngine.whisperTiny.title.contains("32 MB"))
    #expect(RecognitionEngine.apple.isReady(ready, modelInstalled: false, helperAvailable: false))
    var missingApple = ready
    missingApple.speechAuthorized = false
    missingApple.supportsOnDevice = false
    #expect(!RecognitionEngine.apple.isReady(missingApple, modelInstalled: true, helperAvailable: true))
    #expect(RecognitionEngine.whisperTiny.isReady(missingApple, modelInstalled: true, helperAvailable: true))
    #expect(!RecognitionEngine.whisperTiny.isReady(ready, modelInstalled: false, helperAvailable: true))
    #expect(!RecognitionEngine.whisperTiny.isReady(ready, modelInstalled: true, helperAvailable: false))
    for key in [\Readiness.microphoneAuthorized, \.accessibilityTrusted, \.inputMonitoringGranted] {
        var denied = ready
        denied[keyPath: key] = false
        #expect(!RecognitionEngine.whisperTiny.isReady(denied, modelInstalled: true, helperAvailable: true))
    }
}

@Test func whisperWindowsPreserveOverlapAndTail() throws {
    var windows = WhisperWindows()
    #expect(windows.finish() == nil)
    #expect(try windows.append([]).isEmpty)
    let first = try windows.append(Array(repeating: 0.25, count: 400_000))
    #expect(first.count == 1 && first[0].start == 0 && first[0].replayDuration == 0)
    #expect(first[0].samples.count == 400_000)
    let second = try windows.append(Array(repeating: 0.5, count: 384_000))
    #expect(second[0].start == 24 && second[0].replayDuration == 1)
    #expect(second[0].samples.prefix(16_000).allSatisfy { $0 == 0.25 })
    #expect(windows.finish() == nil) // replay alone cannot duplicate final text
    var short = WhisperWindows()
    _ = try short.append([0.1, 0.2])
    #expect(short.finish()?.samples == [0.1, 0.2])
    var tail = WhisperWindows()
    _ = try tail.append(Array(repeating: 0, count: 400_000))
    _ = try tail.append([0.75])
    #expect(tail.finish()?.samples.count == 16_001)
}

@Test func whisperRejectsInvalidOrUnboundedAudio() throws {
    for invalid: [Float] in [[.nan], [.infinity], [1.01], Array(repeating: 0, count: 400_001)] {
        var windows = WhisperWindows()
        #expect(throws: WhisperAudioError.self) { try windows.append(invalid) }
    }
    var windows = WhisperWindows()
    for _ in 0..<24 { _ = try windows.append(Array(repeating: 0, count: 400_000)) }
    _ = try windows.append(Array(repeating: 0, count: 16_000))
    #expect(throws: WhisperAudioError.self) { try windows.append([0]) }
}
