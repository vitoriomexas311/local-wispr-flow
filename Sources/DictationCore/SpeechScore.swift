public struct SpeechScore: Equatable, Sendable {
    public let expectedWords: Int
    public let recognizedWords: Int
    public let errors: Int
    public var wordErrorRate: Double { Double(errors) / Double(max(1, expectedWords)) }

    public init(expected: String, recognized: String) {
        func words(_ text: String) -> [String] {
            text.lowercased().split(whereSeparator: { $0.isWhitespace })
                .map { $0.filter { $0.isLetter || $0.isNumber } }.filter { !$0.isEmpty }
        }
        let reference = words(expected)
        let actual = words(recognized)
        expectedWords = reference.count
        recognizedWords = actual.count
        var previous = Array(0...actual.count)
        for (index, word) in reference.enumerated() {
            var row = [index + 1]
            for (other, candidate) in actual.enumerated() {
                row.append(min(row[other] + 1, previous[other + 1] + 1,
                               previous[other] + (word == candidate ? 0 : 1)))
            }
            previous = row
        }
        errors = previous[actual.count]
    }
}
