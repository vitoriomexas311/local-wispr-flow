public enum InsertionMethod: Equatable, Sendable { case accessibility, keyboard }

public struct TextSelection: Equatable, Sendable {
    public let location: Int
    public let length: Int
    public init(location: Int, length: Int) { self.location = location; self.length = length }
}

/// Accessibility names are stable OS metadata, never document contents.
public enum DestinationPolicy {
    private static let keyboardApplications: Set<String> = [
        "com.apple.Terminal", "com.apple.TextEdit", "com.apple.Safari", "com.google.Chrome"
    ]

    public static func method(bundleID: String, role: String, subrole: String?, enabled: Bool?,
                              selectionSettable: Bool, secureInput: Bool, trusted: Bool,
                              ownApplication: Bool) -> InsertionMethod? {
        guard !secureInput, trusted, !ownApplication, subrole != "AXSecureTextField",
              enabled != false, ["AXTextField", "AXTextArea", "AXComboBox"].contains(role) else { return nil }
        if selectionSettable && bundleID != "com.apple.Terminal" { return .accessibility }
        if keyboardApplications.contains(bundleID) { return .keyboard }
        return nil
    }

    public static func remainsValid(applicationMatches: Bool, windowMatches: Bool, elementMatches: Bool,
                                    secureInput: Bool, secureField: Bool, original: TextSelection?,
                                    current: TextSelection?, checkSelection: Bool) -> Bool {
        guard applicationMatches, windowMatches, elementMatches, !secureInput, !secureField else { return false }
        guard checkSelection else { return true }
        return original == current
    }
}
