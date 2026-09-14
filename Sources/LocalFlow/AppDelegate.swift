import AppKit
import AVFoundation
import Speech
import DictationCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var setupWindow: NSWindow?
    private var readinessLabel: NSTextField?
    private var statusLabel: NSTextField?
    private var refreshTimer: Timer?
    private let controller = DictationController()
    private let indicator = RecordingIndicator()
    private var hotkeyPicker: NSPopUpButton?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "LF"
        statusItem.button?.toolTip = "LocalFlow — local dictation"
        let menu = NSMenu()
        let setup = NSMenuItem(title: "LocalFlow Setup…", action: #selector(showSetup), keyEquivalent: "")
        setup.target = self
        menu.addItem(setup)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit LocalFlow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        let mainMenu = NSMenu()
        let appMenu = NSMenuItem()
        appMenu.submenu = menu.copy() as? NSMenu
        mainMenu.addItem(appMenu)
        NSApp.mainMenu = mainMenu
        controller.onStatus = { [weak self] message, active in
            self?.statusItem.button?.title = active ? "● LF" : "LF"
            self?.statusItem.button?.toolTip = message
            self?.statusLabel?.stringValue = message
            self?.indicator.show(message, active: active)
        }
        controller.start()
        if Permissions.snapshot().blockingIssue != nil || !UserDefaults.standard.bool(forKey: "hasOpened") {
            showSetup()
            UserDefaults.standard.set(true, forKey: "hasOpened")
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshReadiness() }
        }
    }

    @objc private func showSetup() {
        if setupWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 540),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "LocalFlow Setup"
            window.isReleasedWhenClosed = false
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 16
            stack.translatesAutoresizingMaskIntoConstraints = false
            let title = NSTextField(labelWithString: "Your voice. This Mac.")
            title.font = .systemFont(ofSize: 25, weight: .semibold)
            stack.addArrangedSubview(title)
            let description = NSTextField(wrappingLabelWithString:
                "LocalFlow uses Apple's on-device speech engine. It refuses cloud recognition. " +
                "Prepare speech assets before offline use. This is an unnotarized development pilot.")
            stack.addArrangedSubview(description)
            let readiness = NSTextField(wrappingLabelWithString: "Checking readiness…")
            readiness.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            stack.addArrangedSubview(readiness)
            readinessLabel = readiness
            let status = NSTextField(wrappingLabelWithString: "Ready after all permissions are allowed")
            status.textColor = .secondaryLabelColor
            stack.addArrangedSubview(status)
            statusLabel = status
            let buttons: [(String, Selector)] = [
                ("1. Prepare Speech", #selector(prepareSpeech)),
                ("2. Allow Microphone", #selector(allowMicrophone)),
                ("3. Allow Accessibility", #selector(allowAccessibility)),
                ("4. Allow Input Monitoring", #selector(allowInputMonitoring))
            ]
            for (title, action) in buttons {
                stack.addArrangedSubview(NSButton(title: title, target: self, action: action))
            }
            let note = NSTextField(wrappingLabelWithString:
                "Focus a text field, hold the shortcut, speak, then release all shortcut keys. " +
                "Escape cancels. Up to 10 minutes per hold. Microphone: system default. " +
                "Inserted text follows the destination app's privacy policy.")
            note.textColor = .secondaryLabelColor
            stack.addArrangedSubview(note)
            let picker = NSPopUpButton()
            picker.addItems(withTitles: ["Control–Option–Space", "Control–Shift–Space", "Option–Shift–Space"])
            picker.selectItem(at: HotkeyChoice.allCases.firstIndex(of: controller.hotkey) ?? 0)
            picker.target = self
            picker.action = #selector(changeHotkey)
            picker.setAccessibilityLabel("Hold-to-dictate shortcut")
            stack.addArrangedSubview(picker)
            hotkeyPicker = picker
            window.contentView?.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
                stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
                stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 28)
            ])
            window.center()
            setupWindow = window
        }
        refreshReadiness()
        NSApp.activate(ignoringOtherApps: true)
        setupWindow?.makeKeyAndOrderFront(nil)
    }

    private func refreshReadiness() {
        let readiness = Permissions.snapshot()
        readinessLabel?.stringValue = "Speech: \(readiness.speechAuthorized ? "allowed" : "permission needed") · " +
            "Local English assets: \(readiness.supportsOnDevice ? "available" : "missing")\n" +
            "Microphone: \(readiness.microphoneAuthorized ? "allowed" : "permission needed") · " +
            "Accessibility: \(readiness.accessibilityTrusted ? "allowed" : "permission needed")\n" +
            "Input monitoring: \(readiness.inputMonitoringGranted ? "allowed" : "permission needed")"
        hotkeyPicker?.isEnabled = controller.machine.phase == .idle
    }

    @objc private func prepareSpeech() {
        SFSpeechRecognizer.requestAuthorization { [weak self] _ in
            DispatchQueue.main.async { self?.refreshReadiness() }
        }
    }

    @objc private func allowMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshReadiness() }
        }
    }

    @objc private func allowAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @objc private func allowInputMonitoring() {
        _ = CGRequestListenEventAccess()
    }

    @objc private func changeHotkey() {
        guard let index = hotkeyPicker?.indexOfSelectedItem, HotkeyChoice.allCases.indices.contains(index) else { return }
        controller.hotkey = HotkeyChoice.allCases[index]
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
        refreshTimer?.invalidate()
    }
}
