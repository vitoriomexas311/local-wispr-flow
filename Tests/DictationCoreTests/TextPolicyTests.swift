import Testing
@testable import DictationCore

struct TextPolicyTests {
    @Test func stripsControlEventsAndCollapsesWhitespace() {
        #expect(TextPolicy.insertionText(" \tHello\r\nworld\u{1B}\u{0}\u{7F}!\u{202E}\u{2066} ") == "Hello world!")
        #expect(TextPolicy.insertionText("👩‍💻 café 日本語") == "👩‍💻 café 日本語")
        #expect(TextPolicy.insertionText("").isEmpty)
    }
    @Test func unicodePayloadsPreserveGraphemes() {
        #expect(TextPolicy.unicodeBatches("a👩‍💻b", limit: 5) == ["a", "👩‍💻", "b"])
        #expect(TextPolicy.unicodeBatches("abcd", limit: 2) == ["ab", "cd"])
        #expect(TextPolicy.unicodeBatches("") == [])
        #expect(TextPolicy.unicodeBatches("a", limit: 0) == nil)
        #expect(TextPolicy.unicodeBatches("👩‍💻", limit: 1) == nil)
    }
}
