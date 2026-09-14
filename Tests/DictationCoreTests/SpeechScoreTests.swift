import Testing
@testable import DictationCore

struct SpeechScoreTests {
    @Test func reportsErrorsWithoutReturningContent() {
        let exact = SpeechScore(expected: "Hello, WORLD!", recognized: "hello world .")
        #expect(exact.errors == 0)
        #expect(exact.expectedWords == 2)
        #expect(exact.recognizedWords == 2)
        #expect(exact.wordErrorRate == 0)
        #expect(SpeechScore(expected: "one two three", recognized: "one too three four").errors == 2)
        #expect(SpeechScore(expected: "one two", recognized: "one").wordErrorRate == 0.5)
        #expect(SpeechScore(expected: "", recognized: "").wordErrorRate == 0)
        #expect(SpeechScore(expected: "", recognized: "extra").errors == 1)
        #expect(SpeechScore(expected: "one", recognized: "").errors == 1)
    }
}
