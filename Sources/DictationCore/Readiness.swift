public enum ReadinessIssue: String, CaseIterable, Sendable {
    case speechPermission, localAssets, recognizerUnavailable
    case microphonePermission, accessibilityPermission, inputMonitoringPermission
}

public struct Readiness: Equatable, Sendable {
    public var speechAuthorized: Bool
    public var supportsOnDevice: Bool
    public var recognizerAvailable: Bool
    public var microphoneAuthorized: Bool
    public var accessibilityTrusted: Bool
    public var inputMonitoringGranted: Bool

    public init(speechAuthorized: Bool, supportsOnDevice: Bool, recognizerAvailable: Bool,
                microphoneAuthorized: Bool, accessibilityTrusted: Bool, inputMonitoringGranted: Bool) {
        self.speechAuthorized = speechAuthorized
        self.supportsOnDevice = supportsOnDevice
        self.recognizerAvailable = recognizerAvailable
        self.microphoneAuthorized = microphoneAuthorized
        self.accessibilityTrusted = accessibilityTrusted
        self.inputMonitoringGranted = inputMonitoringGranted
    }

    /// Availability alone is not evidence that recognition will stay on-device.
    public var blockingIssue: ReadinessIssue? {
        guard speechAuthorized else { return .speechPermission }
        guard supportsOnDevice else { return .localAssets }
        guard recognizerAvailable else { return .recognizerUnavailable }
        guard microphoneAuthorized else { return .microphonePermission }
        guard accessibilityTrusted else { return .accessibilityPermission }
        guard inputMonitoringGranted else { return .inputMonitoringPermission }
        return nil
    }
}
