/// Completed utterances within one Apple recognition request. Some on-device
/// engines reset the result after a pause without setting isFinal. Transient
/// hypotheses must not enter this accumulator: their timestamps may be placeholders.
public struct UtteranceAccumulator: Sendable {
    private struct Utterance: Sendable {
        let words: [TimedWord]
        let start: Double
        let end: Double
    }
    private var utterances: [Utterance] = []
    public init() {}
    public var words: [TimedWord] { utterances.flatMap(\.words) }

    public mutating func update(_ incoming: [TimedWord]) throws {
        var validated = TranscriptTimeline()
        try validated.append(incoming, windowStart: 0, replayDuration: 0)
        guard let first = incoming.first else { return }
        let end = incoming.reduce(first.start) { max($0, $1.start + $1.duration) }
        guard end.isFinite else { throw TimelineError.invalidTiming }
        let replacement = Utterance(words: incoming, start: first.start, end: end)
        var retained: [Utterance] = []
        for old in utterances {
            // Revisions of the same utterance replace it, including shorter text.
            if abs(old.start - replacement.start) < 0.000_001 { continue }
            // A cumulative result supersedes every earlier utterance it covers.
            if replacement.start <= old.start && replacement.end >= old.end { continue }
            guard old.end <= replacement.start || old.start >= replacement.end else {
                // Ambiguous partial overlap is a failure, never silent text loss.
                throw TimelineError.invalidTiming
            }
            retained.append(old)
        }
        retained.append(replacement)
        retained.sort { $0.start < $1.start }
        var bounded = TranscriptTimeline()
        try bounded.append(retained.flatMap(\.words), windowStart: 0, replayDuration: 0)
        utterances = retained
    }

    public mutating func clear() { utterances.removeAll(keepingCapacity: false) }
}
