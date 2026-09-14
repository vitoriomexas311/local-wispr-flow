import AppKit
import AVFoundation
import Speech
import DictationCore

enum Permissions {
    static func snapshot() -> Readiness {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        return Readiness(
            speechAuthorized: SFSpeechRecognizer.authorizationStatus() == .authorized,
            supportsOnDevice: recognizer?.supportsOnDeviceRecognition == true,
            recognizerAvailable: recognizer?.isAvailable == true,
            microphoneAuthorized: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
            accessibilityTrusted: AXIsProcessTrusted(),
            inputMonitoringGranted: CGPreflightListenEventAccess()
        )
    }

    static func printDiagnostic() {
        let value = snapshot()
        let report: [String: Any] = [
            "schema": 1, "locale": "en-US", "speechAuthorized": value.speechAuthorized,
            "supportsOnDevice": value.supportsOnDevice, "recognizerAvailable": value.recognizerAvailable,
            "microphoneAuthorized": value.microphoneAuthorized,
            "accessibilityTrusted": value.accessibilityTrusted,
            "inputMonitoringGranted": value.inputMonitoringGranted,
            "blockingIssue": value.blockingIssue?.rawValue ?? "none"
        ]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
