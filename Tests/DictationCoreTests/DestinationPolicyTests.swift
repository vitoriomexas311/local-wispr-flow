import Testing
@testable import DictationCore

struct DestinationPolicyTests {
    @Test func choosesOnlySupportedSafeInsertionMethods() {
        func method(_ bundle: String = "test.editor", _ role: String = "AXTextField", subrole: String? = nil,
                    enabled: Bool? = true, settable: Bool = true, secure: Bool = false,
                    trusted: Bool = true, own: Bool = false) -> InsertionMethod? {
            DestinationPolicy.method(bundleID: bundle, role: role, subrole: subrole, enabled: enabled,
                                     selectionSettable: settable, secureInput: secure, trusted: trusted, ownApplication: own)
        }
        #expect(method() == .accessibility)
        #expect(method("test.editor", "AXTextArea", enabled: nil) == .accessibility)
        #expect(method("test.editor", "AXComboBox") == .accessibility)
        #expect(method("com.apple.Terminal") == .keyboard)
        for app in ["com.apple.TextEdit", "com.apple.Safari", "com.google.Chrome"] {
            #expect(method(app, settable: false) == .keyboard)
        }
        #expect(method(settable: false) == nil)
        #expect(method("test.editor", "AXButton") == nil)
        #expect(method(subrole: "AXSecureTextField") == nil)
        #expect(method(enabled: false) == nil)
        #expect(method(secure: true) == nil)
        #expect(method(trusted: false) == nil)
        #expect(method(own: true) == nil)
    }

    @Test func selectionAndFocusMustRemainVerifiable() {
        let selected = TextSelection(location: 15, length: 10)
        func valid(app: Bool = true, window: Bool = true, element: Bool = true, secure: Bool = false,
                   password: Bool = false, original: TextSelection? = selected,
                   current: TextSelection? = selected, check: Bool = true) -> Bool {
            DestinationPolicy.remainsValid(applicationMatches: app, windowMatches: window, elementMatches: element,
                                            secureInput: secure, secureField: password, original: original,
                                            current: current, checkSelection: check)
        }
        #expect(valid())
        #expect(valid(original: nil, current: nil))
        #expect(!valid(current: nil))
        #expect(!valid(original: nil))
        #expect(!valid(current: TextSelection(location: 16, length: 10)))
        #expect(!valid(current: TextSelection(location: 15, length: 0)))
        #expect(valid(current: nil, check: false))
        #expect(!valid(app: false))
        #expect(!valid(window: false))
        #expect(!valid(element: false))
        #expect(!valid(secure: true))
        #expect(!valid(password: true))
    }
}
