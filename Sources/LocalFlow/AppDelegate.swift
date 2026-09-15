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
    private var enginePicker: NSPopUpButton?
    private var modelButtons: [NSButton] = []
    private var provisioning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "LF"
        if let iconURL = Bundle.main.url(forResource: "LocalFlow", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            icon.size = NSSize(width: 20, height: 20)
            icon.isTemplate = false
            statusItem.button?.image = icon
        }
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
        if !controller.isReady || !UserDefaults.standard.bool(forKey: "hasOpened") {
            showSetup()
            UserDefaults.standard.set(true, forKey: "hasOpened")
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshReadiness() }
        }
    }

    @objc private func showSetup() {
        if setupWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 690),
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
                "Choose Apple on-device recognition or download Whisper Tiny English once. " +
                "Both transcribe on this Mac. No cloud recognition. This is an unsigned pilot.")
            stack.addArrangedSubview(description)
            let engines = NSPopUpButton()
            engines.addItems(withTitles: RecognitionEngine.allCases.map(\.title))
            engines.selectItem(at: RecognitionEngine.allCases.firstIndex(of: controller.engine) ?? 0)
            engines.target = self
            engines.action = #selector(changeEngine)
            engines.setAccessibilityLabel("Speech engine")
            stack.addArrangedSubview(engines)
            enginePicker = engines
            let download = NSButton(title: "Download Whisper Tiny · 32 MB", target: self, action: #selector(downloadModel))
            let importButton = NSButton(title: "Import model file offline…", target: self, action: #selector(importModel))
            modelButtons = [download, importButton]
            let modelRow = NSStackView(views: modelButtons)
            modelRow.spacing = 12
            stack.addArrangedSubview(modelRow)
            let readiness = NSTextField(wrappingLabelWithString: "Checking readiness…")
            readiness.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            stack.addArrangedSubview(readiness)
            readinessLabel = readiness
            let status = NSTextField(wrappingLabelWithString: "Ready after all permissions are allowed")
            status.textColor = .secondaryLabelColor
            stack.addArrangedSubview(status)
            statusLabel = status
            let buttons: [(String, Selector)] = [
                ("Prepare Apple Speech (Apple engine only)", #selector(prepareSpeech)),
                ("Allow Microphone", #selector(allowMicrophone)),
                ("Allow Accessibility", #selector(allowAccessibility)),
                ("Allow Input Monitoring", #selector(allowInputMonitoring))
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
            picker.addItems(withTitles: ["Control–Option–Space", "Control–Shift–Space", "Option–Shift–Space", "Shift–Tab"])
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSetup()
        return true
    }

    private func refreshReadiness() {
        let readiness = Permissions.snapshot()
        let engineStatus: String
        if controller.engine == .apple {
            engineStatus = "Apple Speech: \(readiness.speechAuthorized ? "allowed" : "permission needed") · " +
                "Local English assets: \(readiness.supportsOnDevice ? "available" : "missing")"
        } else {
            engineStatus = "Whisper model: \(TinyModel.installed ? "verified and ready offline" : "download or import needed") · " +
                "Runtime: \(TinyModel.helperAvailable ? "available" : "missing")"
        }
        readinessLabel?.stringValue = engineStatus + "\n" +
            "Microphone: \(readiness.microphoneAuthorized ? "allowed" : "permission needed") · " +
            "Accessibility: \(readiness.accessibilityTrusted ? "allowed" : "permission needed")\n" +
            "Input monitoring: \(readiness.inputMonitoringGranted ? "allowed" : "permission needed")"
        hotkeyPicker?.isEnabled = controller.machine.phase == .idle
        enginePicker?.isEnabled = controller.machine.phase == .idle && !provisioning
        for button in modelButtons { button.isEnabled = controller.machine.phase == .idle && !provisioning }
    }

    @objc private func changeEngine() {
        guard let index = enginePicker?.indexOfSelectedItem,
              RecognitionEngine.allCases.indices.contains(index) else { return }
        controller.engine = RecognitionEngine.allCases[index]
        refreshReadiness()
    }

    @objc private func downloadModel() { provisionModel(nil) }

    @objc private func importModel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose ggml-tiny.en-q5_1.bin. Its checksum will be verified before installation."
        if panel.runModal() == .OK, let url = panel.url { provisionModel(url) }
    }

    private func provisionModel(_ source: URL?) {
        guard !provisioning, controller.machine.phase == .idle else { return }
        provisioning = true
        statusLabel?.stringValue = source == nil ? "Downloading 32 MB model…" : "Verifying model…"
        refreshReadiness()
        TinyModel.provision(importing: source) { [weak self] succeeded in
            guard let self else { return }
            self.provisioning = false
            self.statusLabel?.stringValue = succeeded ? "Whisper Tiny ready. Select it above to use it." :
                "Model installation failed. Retry the download or import the verified model file."
            self.refreshReadiness()
        }
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
