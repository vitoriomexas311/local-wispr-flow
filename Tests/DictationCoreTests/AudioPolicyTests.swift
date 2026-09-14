import Testing
@testable import DictationCore

struct AudioPolicyTests {
    @Test func budgetBoundsQueueAndRecoversAfterDrain() {
        var budget = BufferBudget(capacity: 5)
        #expect(budget.reserve(0) == false)
        #expect(budget.reserve(-1) == false)
        #expect(budget.reserve(3) == true)
        #expect(budget.reserve(3) == false)
        #expect(budget.reserve(2) == true)
        budget.release(-4)
        #expect(budget.used == 5)
        budget.release(4)
        #expect(budget.reserve(4) == true)
        budget.release(100)
        #expect(budget.used == 0)
        #expect(budget.reserve(5) == true)
        budget.reset()
        #expect(budget.used == 0)
        #expect(BufferBudget(capacity: -1).capacity == 0)
    }

    @Test func ownershipPreservesRepeatedWordsAndPunctuation() throws {
        var timeline = TranscriptTimeline()
        try timeline.append([TimedWord(text: "Very", start: 0, duration: 0.2),
                             TimedWord(text: "very", start: 0.3, duration: 0.2),
                             TimedWord(text: "good.", start: 0.6, duration: 0.2)], windowStart: 0, replayDuration: 0)
        try timeline.append([TimedWord(text: "very", start: 0.3, duration: 0.2),
                             TimedWord(text: "good.", start: 0.6, duration: 0.2),
                             TimedWord(text: "Next!", start: 1.1, duration: 0.2)], windowStart: 0.3, replayDuration: 0.5)
        #expect(timeline.text == "Very very good. Next!")
        timeline.clear()
        #expect(timeline.text.isEmpty)
    }

    @Test func boundaryDeduplicationRequiresMatchingOverlappingWords() throws {
        var timeline = TranscriptTimeline()
        try timeline.append([TimedWord(text: "word", start: 0.5, duration: 0.4)], windowStart: 0, replayDuration: 0)
        try timeline.append([TimedWord(text: "Word!", start: 0.55, duration: 0.4),
                             TimedWord(text: "after", start: 1.2, duration: 0.2)], windowStart: 0.3, replayDuration: 0.9)
        #expect(timeline.text == "word after")
        var distinct = TranscriptTimeline()
        try distinct.append([TimedWord(text: "yes", start: 0, duration: 0.1)], windowStart: 0, replayDuration: 0)
        try distinct.append([TimedWord(text: "yes", start: 0.2, duration: 0.1)], windowStart: 0, replayDuration: 0.3)
        #expect(distinct.text == "yes yes")
        try distinct.append([], windowStart: 0, replayDuration: 0.3)
        #expect(distinct.text == "yes yes")
        var empty = TranscriptTimeline()
        try empty.append([TimedWord(text: "start", start: 1, duration: 0.2)], windowStart: 0, replayDuration: 2)
        #expect(empty.text == "start")
    }

    @Test func rejectsInvalidOrUnboundedResultsWithoutMutation() throws {
        var timeline = TranscriptTimeline()
        for (start, replay) in [(Double.nan, 0.0), (0, Double.infinity), (-1, 0), (0, -1)] {
            #expect(throws: TimelineError.invalidTiming) { try timeline.append([], windowStart: start, replayDuration: replay) }
        }
        for word in [TimedWord(text: "a", start: .nan, duration: 1), TimedWord(text: "a", start: 0, duration: .nan),
                     TimedWord(text: "a", start: -1, duration: 1), TimedWord(text: "a", start: 0, duration: -1)] {
            #expect(throws: TimelineError.invalidTiming) { try timeline.append([word], windowStart: 0, replayDuration: 0) }
        }
        #expect(throws: TimelineError.invalidTiming) {
            try timeline.append([TimedWord(text: "a", start: 1, duration: 0), TimedWord(text: "b", start: 0, duration: 0)],
                                windowStart: 0, replayDuration: 0)
        }
        #expect(throws: TimelineError.tooLarge) {
            try timeline.append([TimedWord(text: String(repeating: "a", count: 100_001), start: 0, duration: 1)],
                                windowStart: 0, replayDuration: 0)
        }
        #expect(throws: TimelineError.tooLarge) {
            try timeline.append(Array(repeating: TimedWord(text: "a", start: 0, duration: 0), count: 20_001),
                                windowStart: 0, replayDuration: 0)
        }
        #expect(timeline.words.isEmpty)
    }
}
