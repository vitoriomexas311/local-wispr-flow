import DictationCore

@MainActor
protocol RecognitionBackend: AnyObject {
    var onResult: ((UInt64, String) -> Void)? { get set }
    var onFailure: ((UInt64, FailureCode) -> Void)? { get set }
    func start(generation: UInt64) -> Bool
    func append(_ chunks: [AudioChunk])
    func finish()
    func cancel()
    func checkTimeout(now: Double)
}

extension SpeechPipeline: RecognitionBackend {}
