import Foundation
import AppKit
import DictationCore

if CommandLine.arguments.contains("--doctor") {
    Permissions.printDiagnostic()
} else if CommandLine.arguments == [CommandLine.arguments[0], "--verify-whisper-cancellation"] {
    exit(MainActor.assumeIsolated { WhisperDiagnostics.cancellation() })
} else if CommandLine.arguments.count == 4 && ["--verify-speech", "--verify-whisper"].contains(CommandLine.arguments[1]) {
    let result = MainActor.assumeIsolated {
        SpeechProbe.run(audioURL: URL(fileURLWithPath: CommandLine.arguments[2]),
                        expectedURL: URL(fileURLWithPath: CommandLine.arguments[3]),
                        engine: CommandLine.arguments[1] == "--verify-whisper" ? .whisperTiny : .apple)
    }
    exit(result)
} else {
    MainActor.assumeIsolated {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
