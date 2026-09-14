public struct BufferBudget: Sendable {
    public let capacity: Int
    public private(set) var used = 0
    public init(capacity: Int) { self.capacity = max(0, capacity) }

    public mutating func reserve(_ count: Int) -> Bool {
        guard count > 0, count <= capacity - used else { return false }
        used += count
        return true
    }

    public mutating func release(_ count: Int) {
        used = max(0, used - max(0, count))
    }

    public mutating func reset() { used = 0 }
}

public struct TimedWord: Equatable, Sendable {
    public let text: String
    public let start: Double
    public let duration: Double
    public var midpoint: Double { start + duration / 2 }
    public init(text: String, start: Double, duration: Double) {
        self.text = text
        self.start = start
        self.duration = duration
    }
}

public enum TimelineError: Error { case invalidTiming, tooLarge }

/// The midpoint of the replay window assigns ownership across recognition sessions.
/// Duplicate words are removed only at that boundary, with overlapping audio times.
public struct TranscriptTimeline: Sendable {
    public private(set) var words: [TimedWord] = []
    public init() {}

    public mutating func append(_ incoming: [TimedWord], windowStart: Double, replayDuration: Double) throws {
        guard windowStart.isFinite, replayDuration.isFinite, windowStart >= 0, replayDuration >= 0 else {
            throw TimelineError.invalidTiming
        }
        var previousStart = -Double.infinity
        for word in incoming {
            guard word.start.isFinite, word.duration.isFinite, word.start >= previousStart,
                  word.start >= windowStart, word.duration >= 0 else { throw TimelineError.invalidTiming }
            previousStart = word.start
        }
        var kept = words
        var tail = incoming
        if replayDuration > 0 && !kept.isEmpty && !tail.isEmpty {
            let boundary = windowStart + replayDuration / 2
            kept.removeAll { $0.midpoint >= boundary }
            tail.removeAll { $0.midpoint < boundary }
            if let last = kept.last, let first = tail.first,
               normalized(last.text) == normalized(first.text),
               abs(last.start - first.start) < 0.3,
               min(last.start + last.duration, first.start + first.duration) > max(last.start, first.start) {
                tail.removeFirst()
            }
        }
        let result = kept + tail
        guard result.count <= 20_000, result.reduce(0, { $0 + $1.text.utf8.count }) <= 100_000 else {
            throw TimelineError.tooLarge
        }
        words = result
    }

    public var text: String { words.map(\.text).joined(separator: " ") }
    public mutating func clear() { words.removeAll(keepingCapacity: false) }
    private func normalized(_ text: String) -> String { text.lowercased().filter { $0.isLetter || $0.isNumber } }
}
