import Testing
@testable import DictationCore

struct UtteranceAccumulatorTests {
    private func word(_ text: String, _ start: Double, _ duration: Double = 0.2) -> TimedWord {
        TimedWord(text: text, start: start, duration: duration)
    }

    @Test func retainsCompletedUtterancesWhenFinalContainsOnlyTheTail() throws {
        var value = UtteranceAccumulator()
        try value.update([word("First.", 0, 14.64)])
        try value.update([word("Second.", 14.64, 7.11)])
        try value.update([word("Third.", 23.52, 17.52)])
        let last = [word("Last.", 41.04, 2.94)]
        try value.update(last)
        try value.update(last)
        #expect(value.words.map(\.text) == ["First.", "Second.", "Third.", "Last."])
        try value.update([]) // Some engines emit an empty final callback.
        #expect(value.words.count == 4)
        value.clear()
        #expect(value.words.isEmpty)
        try value.update([])
        #expect(value.words.isEmpty)
    }

    @Test func cumulativeAndShorterRevisionsReplaceWithoutDuplicatingSpeech() throws {
        var value = UtteranceAccumulator()
        try value.update([word("Very", 0), word("very", 0.3), word("good.", 0.6)])
        try value.update([word("Next.", 1.2)])
        try value.update([word("Very", 0), word("very", 0.3), word("well!", 0.6), word("Next.", 1.2)])
        #expect(value.words.map(\.text) == ["Very", "very", "well!", "Next."])
        try value.update([word("Revised.", 0)])
        #expect(value.words.map(\.text) == ["Revised."])
        try value.update([word("again", 3)])
        try value.update([word("again", 2)]) // Delayed non-overlapping completed utterance.
        #expect(value.words.map(\.start) == [0, 2, 3])
        #expect(value.words.map(\.text) == ["Revised.", "again", "again"])
    }

    @Test func invalidAmbiguousAndOversizedUpdatesPreservePreviousSpeech() throws {
        var value = UtteranceAccumulator()
        let original = [word("kept", 1, 1)]
        try value.update(original)
        #expect(throws: TimelineError.invalidTiming) { try value.update([word("bad", .nan)]) }
        #expect(throws: TimelineError.invalidTiming) { try value.update([word("bad", 1.5, 1)]) }
        #expect(throws: TimelineError.invalidTiming) {
            try value.update([word("bad", Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude)])
        }
        #expect(throws: TimelineError.tooLarge) { try value.update([word(String(repeating: "x", count: 100_001), 3)]) }
        #expect(value.words == original)
        var bounded = UtteranceAccumulator()
        try bounded.update([word(String(repeating: "x", count: 60_000), 0)])
        #expect(throws: TimelineError.tooLarge) {
            try bounded.update([word(String(repeating: "x", count: 60_000), 2)])
        }
        #expect(bounded.words.count == 1)
    }

    @Test func adjacentUtterancesSurviveFloatingPointRounding() throws {
        var value = UtteranceAccumulator()
        // The adapter adds a window origin before durations. Adjacent boundaries
        // can differ by an ULP because (origin + start) + duration != origin + end.
        try value.update([word("first", 0.1, 0.2)])
        try value.update([word("second", 0.3, 0.2)])
        #expect(value.words.map(\.text) == ["first", "second"])
        #expect(throws: TimelineError.invalidTiming) {
            try value.update([word("real overlap", 0.49, 0.3)])
        }
    }
}
