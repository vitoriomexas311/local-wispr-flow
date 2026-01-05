import Testing
@testable import DictationCore

struct ReadinessTests {
    @Test func eachPermissionAndCapabilityIsMandatory() {
        var readiness = Readiness(speechAuthorized: false, supportsOnDevice: false,
                                  recognizerAvailable: false, microphoneAuthorized: false,
                                  accessibilityTrusted: false, inputMonitoringGranted: false)
        #expect(readiness.blockingIssue == .speechPermission)
        readiness.speechAuthorized = true
        #expect(readiness.blockingIssue == .localAssets)
        readiness.supportsOnDevice = true
        #expect(readiness.blockingIssue == .recognizerUnavailable)
        readiness.recognizerAvailable = true
        #expect(readiness.blockingIssue == .microphonePermission)
        readiness.microphoneAuthorized = true
        #expect(readiness.blockingIssue == .accessibilityPermission)
        readiness.accessibilityTrusted = true
        #expect(readiness.blockingIssue == .inputMonitoringPermission)
        readiness.inputMonitoringGranted = true
        #expect(readiness.blockingIssue == nil)
        readiness.supportsOnDevice = false
        #expect(readiness.blockingIssue == .localAssets)
    }
}
