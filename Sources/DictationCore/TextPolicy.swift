public enum TextPolicy {
    /// Never permit control characters to become terminal commands or submit keys.
    public static func insertionText(_ text: String) -> String {
        let scalars = text.unicodeScalars.filter {
            $0.properties.isWhitespace || ($0.properties.generalCategory != .control &&
                !(0x202A...0x202E).contains($0.value) && !(0x2066...0x2069).contains($0.value))
        }
        return String(String.UnicodeScalarView(scalars)).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Quartz keyboard events have a small Unicode payload; never split a grapheme.
    /// A single oversized grapheme is rejected rather than truncated.
    public static func unicodeBatches(_ text: String, limit: Int = 20) -> [String]? {
        guard limit > 0 else { return nil }
        var batches: [String] = []
        var batch = ""
        for character in text {
            let next = String(character)
            guard next.utf16.count <= limit else { return nil }
            if batch.utf16.count + next.utf16.count > limit {
                batches.append(batch)
                batch = ""
            }
            batch.append(character)
        }
        if !batch.isEmpty { batches.append(batch) }
        return batches
    }
}
