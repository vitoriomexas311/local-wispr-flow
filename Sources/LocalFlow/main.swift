import Foundation
import AppKit

if CommandLine.arguments.contains("--doctor") {
    Permissions.printDiagnostic()
} else if CommandLine.arguments.count == 4 && CommandLine.arguments[1] == "--verify-speech" {
    let result = MainActor.assumeIsolated {
        SpeechProbe.run(audioURL: URL(fileURLWithPath: CommandLine.arguments[2]),
                        expectedURL: URL(fileURLWithPath: CommandLine.arguments[3]))
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
