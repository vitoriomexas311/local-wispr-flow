import AppKit
import AVFoundation
import Carbon
import DictationCore

// Test-only process. Never linked into the distributed app. Only a field explicitly
// seeded with LOCALFLOW_TEST may be inspected. No field contents enter reports.
func report(_ value: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
       let text = String(data: data, encoding: .utf8) { print(text); fflush(stdout) }
}

func pump(_ seconds: Double) {
    let until = ProcessInfo.processInfo.systemUptime + seconds
    while ProcessInfo.processInfo.systemUptime < until {
        _ = RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
    }
}

func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
    return value
}

func element(_ value: CFTypeRef?) -> AXUIElement? {
    guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
}

func key(_ code: CGKeyCode, down: Bool, flags: CGEventFlags) {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return }
    event.flags = flags
    event.post(tap: .cghidEventTap)
}

func releaseKeys() {
    key(49, down: false, flags: [.maskControl, .maskAlternate])
    key(58, down: false, flags: [.maskControl])
    key(59, down: false, flags: [])
}

// Inspect only LocalFlow's fixed status labels. A no-op hotkey must never make a
// cancellation test pass merely because the destination happened to stay empty.
func localFlowHasStatus(_ expected: String, prefix: Bool = false) -> Bool {
    guard let application = NSRunningApplication.runningApplications(
        withBundleIdentifier: "io.github.vitoriomexas311.localflow").first else { return false }
    let app = AXUIElementCreateApplication(application.processIdentifier)
    AXUIElementSetMessagingTimeout(app, 0.2)
    var remaining = (attribute(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    var visited = 0
    while let item = remaining.popLast(), visited < 256 {
        visited += 1
        if attribute(item, kAXRoleAttribute) as? String == kAXStaticTextRole,
           let text = attribute(item, kAXValueAttribute) as? String,
           prefix ? text.hasPrefix(expected) : text == expected { return true }
        let children = (attribute(item, kAXChildrenAttribute) as? [AXUIElement]) ?? []
        remaining.append(contentsOf: children.prefix(max(0, 256 - visited - remaining.count)))
    }
    return false
}

@MainActor
func run() -> Int32 {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.prohibited)
    let args = CommandLine.arguments
    if args.contains("--authorize") {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = CGRequestPostEventAccess()
        for _ in 0..<100 {
            if AXIsProcessTrusted() && CGPreflightPostEventAccess() { break }
            pump(0.1)
        }
        let ready = AXIsProcessTrusted() && CGPreflightPostEventAccess()
        report(["status": ready ? "passed" : "blocked", "kind": "driver-permissions"])
        return ready ? 0 : 2
    }
    guard args.count == 6, args[1] == "--dictate", ["normal", "cancel", "selection"].contains(args[5]) else {
        report(["status": "failed", "reason": "usage: --dictate AUDIO REFERENCE TARGET_BUNDLE normal|cancel|selection"])
        return 1
    }
    guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else {
        report(["status": "blocked", "reason": "driver-permissions"])
        return 2
    }
    guard let application = NSRunningApplication.runningApplications(withBundleIdentifier: args[4]).first,
          ["com.apple.TextEdit", "com.apple.Terminal", "com.apple.Safari", "com.google.Chrome"].contains(args[4]) else {
        report(["status": "blocked", "reason": "target-not-frontmost"])
        return 2
    }
    guard let audio = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: args[2])), audio.duration <= 600 else {
        report(["status": "blocked", "reason": "audio-fixture-unavailable"])
        return 2
    }
    guard let expected = try? String(contentsOfFile: args[3], encoding: .utf8) else {
        report(["status": "blocked", "reason": "reference-fixture-unavailable"])
        return 2
    }
    let app = AXUIElementCreateApplication(application.processIdentifier)
    AXUIElementSetMessagingTimeout(app, 0.5)
    guard let target = element(attribute(app, kAXFocusedUIElementAttribute)),
          let original = attribute(target, kAXValueAttribute) as? String,
          original.contains("LOCALFLOW_TEST ") else {
        report(["status": "blocked", "reason": "focus-a-field-seeded-with-LOCALFLOW_TEST"])
        return 2
    }
    let terminal = args[4] == "com.apple.Terminal"
    guard terminal || original == "LOCALFLOW_TEST " || (args[5] == "selection" && original == "LOCALFLOW_TEST replace me") else {
        report(["status": "blocked", "reason": "field-is-not-a-clean-test-fixture"])
        return 2
    }
    application.activate(options: [])
    pump(0.5)
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier else {
        report(["status": "blocked", "reason": "test-target-activation-failed"])
        return 2
    }
    if args[5] == "selection" {
        var range = CFRange(location: 15, length: 10)
        guard let value = AXValueCreate(.cfRange, &range),
              AXUIElementSetAttributeValue(target, kAXSelectedTextRangeAttribute as CFString, value) == .success else {
            report(["status": "blocked", "reason": "selection-unavailable"])
            return 2
        }
    }
    let clipboard = NSPasteboard.general.changeCount
    audio.prepareToPlay()
    let start = ProcessInfo.processInfo.systemUptime
    key(59, down: true, flags: [.maskControl])
    key(58, down: true, flags: [.maskControl, .maskAlternate])
    key(49, down: true, flags: [.maskControl, .maskAlternate])
    defer { releaseKeys() }
    pump(0.8)
    report(["kind": "held-key-state", "hardwareSpace": CGEventSource.keyState(.hidSystemState, key: 49),
            "sessionSpace": CGEventSource.keyState(.combinedSessionState, key: 49)])
    for _ in 0..<20 {
        if localFlowHasStatus("Recording ", prefix: true) { break }
        pump(0.1)
    }
    guard localFlowHasStatus("Recording ", prefix: true) else {
        report(["status": "failed", "reason": "recording-not-observed", "microphoneStarted": false])
        return 1
    }
    report(["kind": "capture-start", "microphoneStarted": true])
    guard audio.play() else { report(["status": "failed", "reason": "audio-playback"]); return 1 }
    if args[5] == "cancel" {
        pump(min(1, audio.duration / 2))
        key(53, down: true, flags: [.maskControl, .maskAlternate])
        key(53, down: false, flags: [.maskControl, .maskAlternate])
    }
    while audio.isPlaying { pump(0.05) }
    pump(0.7)
    releaseKeys()
    let heldSeconds = ProcessInfo.processInfo.systemUptime - start
    var result = original
    for _ in 0..<200 {
        pump(0.1)
        if let value = attribute(target, kAXValueAttribute) as? String { result = value }
        if args[5] != "cancel" && result != original && localFlowHasStatus("Inserted") { break }
        if args[5] == "cancel" && ProcessInfo.processInfo.systemUptime - start > audio.duration + 4 { break }
    }
    if let value = attribute(target, kAXValueAttribute) as? String { result = value }
    let clipboardUnchanged = clipboard == NSPasteboard.general.changeCount
    if args[5] == "cancel" {
        let cancellationObserved = localFlowHasStatus("Cancelled")
        let passed = result == original && clipboardUnchanged && cancellationObserved
        report(["status": passed ? "passed" : "failed", "kind": "real-microphone-cancellation",
                "target": args[4], "fieldUnchanged": result == original, "clipboardUnchanged": clipboardUnchanged,
                "microphoneStarted": true, "cancellationObserved": cancellationObserved])
        return passed ? 0 : 1
    }
    guard let marker = result.range(of: "LOCALFLOW_TEST ", options: .backwards) else {
        report(["status": "failed", "reason": "test-marker-lost"])
        return 1
    }
    let suffix = String(result[marker.upperBound...])
    let recognized = terminal ? String(suffix.prefix(while: { $0 != "\n" && $0 != "\r" })) : suffix
    let score = SpeechScore(expected: expected, recognized: recognized)
    let insertionObserved = localFlowHasStatus("Inserted")
    let passed = result != original && score.wordErrorRate <= 0.15 && clipboardUnchanged &&
        !recognized.contains("\n") && insertionObserved
    report(["status": passed ? "passed" : "failed", "kind": "speakers-to-real-microphone-to-field",
            "target": args[4], "case": args[5], "expectedWords": score.expectedWords,
            "recognizedWords": score.recognizedWords, "wordErrors": score.errors,
            "wordErrorRate": score.wordErrorRate, "clipboardUnchanged": clipboardUnchanged,
            "microphoneStarted": true, "insertionObserved": insertionObserved,
            "heldSeconds": heldSeconds,
            "elapsedSeconds": ProcessInfo.processInfo.systemUptime - start])
    return passed ? 0 : 1
}

exit(MainActor.assumeIsolated { run() })
