import AppKit
import AVFoundation
import Speech
import SwiftUI
import DictationCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var setupWindow: NSWindow?
    private var refreshTimer: Timer?
    private let controller = DictationController()
    private let indicator = RecordingIndicator()
    private let model = SetupModel()
    private let recorder = ShortcutRecorder()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        updateIcon(active: false)
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
            self?.updateIcon(active: active)
            self?.statusItem.button?.toolTip = message
            self?.model.message = message
            self?.indicator.show(message, active: active)
        }
        model.selectEngine = { [weak self] engine in self?.controller.engine = engine; self?.refreshReadiness() }
        model.download = { [weak self] in self?.provisionModel(nil) }
        model.importModel = { [weak self] in self?.importModel() }
        model.prepareApple = { [weak self] in self?.prepareSpeech() }
        model.recordShortcut = { [weak self] in self?.recordShortcut() }
        model.cancelShortcut = { [weak self] in self?.recorder.finish(nil) }
        model.permissions = [
            ("Microphone", { [weak self] in self?.allowMicrophone() }),
            ("Accessibility", { [weak self] in self?.allowAccessibility() }),
            ("Input Monitoring", { [weak self] in self?.allowInputMonitoring() })
        ]
        recorder.onFinish = { [weak self] choice in
            guard let self else { return }
            if let choice { self.controller.hotkey = choice }
            self.controller.configuringShortcut = false
            self.model.recordingShortcut = false
            self.model.shortcutHint = choice == nil ? "Shortcut unchanged." : "Saved. Hold this shortcut in a text field to dictate."
            self.refreshReadiness()
        }
        recorder.onHint = { [weak self] hint in self?.model.shortcutHint = hint }
        controller.start()
        if !controller.isReady || !UserDefaults.standard.bool(forKey: "hasOpened") {
            showSetup()
            UserDefaults.standard.set(true, forKey: "hasOpened")
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshReadiness() }
        }
    }

    private func updateIcon(active: Bool) {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { _ in
            NSColor.black.setFill()
            for (index, height) in [6.0, 12.0, 18.0, 10.0, 5.0].enumerated() {
                NSBezierPath(roundedRect: NSRect(x: Double(index) * 4, y: (20 - height) / 2, width: 2.5, height: height),
                             xRadius: 1.25, yRadius: 1.25).fill()
            }
            return true
        }
        image.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.contentTintColor = active ? .systemRed : nil
        statusItem.button?.setAccessibilityLabel(active ? "LocalFlow recording or processing" : "LocalFlow")
    }

    @objc private func showSetup() {
        if setupWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 550),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "LocalFlow"
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .white
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: SetupView(model: model))
            window.minSize = NSSize(width: 560, height: 540)
            window.center()
            setupWindow = window
        }
        refreshReadiness()
        NSApp.activate(ignoringOtherApps: true)
        setupWindow?.makeKeyAndOrderFront(nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSetup(); return true
    }
    func windowDidResignKey(_ notification: Notification) {
        if model.recordingShortcut { recorder.finish(nil) }
    }
    private func refreshReadiness() {
        let readiness = Permissions.snapshot()
        model.engine = controller.engine
        model.shortcut = controller.hotkey.displayName
        model.shortcutKeys = controller.hotkey.displayKeys
        model.modelReady = TinyModel.installed && TinyModel.helperAvailable
        model.microphone = readiness.microphoneAuthorized
        model.accessibility = readiness.accessibilityTrusted
        model.inputMonitoring = readiness.inputMonitoringGranted
        model.appleReady = readiness.speechAuthorized && readiness.supportsOnDevice
        model.ready = controller.isReady
        model.idle = controller.machine.phase == .idle
    }
    private func recordShortcut() {
        guard controller.machine.phase == .idle else { return }
        controller.configuringShortcut = true
        model.recordingShortcut = true
        model.shortcutHint = "Press your shortcut now. Use Cancel to keep the current shortcut."
        recorder.start()
    }
    private func importModel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose ggml-tiny.en-q5_1.bin. Its checksum will be verified before installation."
        if panel.runModal() == .OK, let url = panel.url { provisionModel(url) }
    }
    private func provisionModel(_ source: URL?) {
        guard !model.busy, controller.machine.phase == .idle else { return }
        model.busy = true
        model.message = source == nil ? "Downloading 32 MB model…" : "Verifying model…"
        TinyModel.provision(importing: source) { [weak self] succeeded in
            guard let self else { return }
            self.model.busy = false
            if succeeded { self.controller.engine = .whisperTiny }
            self.model.message = succeeded ? "Whisper Tiny is ready. Your voice stays on this Mac." :
                "Model installation failed. Retry the download or import the verified model file."
            self.refreshReadiness()
        }
    }
    private func prepareSpeech() {
        SFSpeechRecognizer.requestAuthorization { [weak self] _ in
            DispatchQueue.main.async { self?.refreshReadiness() }
        }
    }
    private func allowMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshReadiness() }
        }
    }
    private func allowAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    private func allowInputMonitoring() { _ = CGRequestListenEventAccess() }
    func applicationWillTerminate(_ notification: Notification) {
        recorder.stop()
        controller.stop()
        refreshTimer?.invalidate()
    }
}
