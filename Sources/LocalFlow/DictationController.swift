import AppKit
import DictationCore

@MainActor
final class DictationController {
    var onStatus: ((String, Bool) -> Void)?
    private(set) var machine = SessionMachine()
    private let audio = AudioCapture()
    private var speech: any RecognitionBackend = SpeechPipeline()
    private var engineChoice: RecognitionEngine = .apple
    private let monitor = HotkeyMonitor()
    private var destination: Destination?
    private var capturedRevision: UInt64 = 0
    private var timer: Timer?
    private var insertionTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var lastReadinessCheck: Double = 0
    private var readiness = Permissions.snapshot()

    var engine: RecognitionEngine {
        get { engineChoice }
        set {
            guard machine.phase == .idle else { return }
            speech.cancel()
            engineChoice = newValue
            speech = newValue == .apple ? SpeechPipeline() : WhisperPipeline()
            configureSpeech()
            UserDefaults.standard.set(newValue.rawValue, forKey: "recognitionEngine")
        }
    }

    var isReady: Bool {
        engine.isReady(readiness, modelInstalled: engine == .whisperTiny && TinyModel.installed,
                       helperAvailable: engine == .whisperTiny && TinyModel.helperAvailable)
    }

    private func configureSpeech() {
        speech.onResult = { [weak self] generation, text in
            guard let self else { return }
            self.apply(self.machine.recognized(generation: generation, text: text, now: self.now))
        }
        speech.onFailure = { [weak self] generation, reason in
            guard let self else { return }
            self.apply(self.machine.recognitionFailed(generation: generation, reason: reason))
        }
    }

    var hotkey: HotkeyChoice {
        get { monitor.policy.choice }
        set {
            guard machine.phase == .idle else { return }
            monitor.policy.choice = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: "hotkey")
        }
    }

    func start() {
        if let raw = UserDefaults.standard.string(forKey: "hotkey"), let choice = HotkeyChoice(rawValue: raw) {
            monitor.policy.choice = choice
        }
        monitor.onAction = { [weak self] action in
            guard let self else { return }
            let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let revision = self.monitor.activityRevision
            // Event tap callbacks must not block on microphone startup or Accessibility IPC.
            DispatchQueue.main.async {
                guard action != .begin || (self.monitor.isHeld && revision == self.monitor.activityRevision &&
                    frontPID == NSWorkspace.shared.frontmostApplication?.processIdentifier) else { return }
                self.handle(action)
            }
        }
        engine = UserDefaults.standard.string(forKey: "recognitionEngine")
            .flatMap(RecognitionEngine.init(rawValue:)) ?? .apple
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.cancel() }
            })
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private var now: Double { ProcessInfo.processInfo.systemUptime }

    private func handle(_ action: HotkeyAction) {
        switch action {
        case .begin:
            guard machine.phase == .idle else { return }
            readiness = Permissions.snapshot()
            destination = DestinationAccess.capture()
            capturedRevision = monitor.activityRevision
            apply(machine.begin(now: now, ready: isReady,
                                targetAllowed: destination != nil))
        case .release: apply(machine.release(now: now))
        case .cancel: cancel()
        case .activity: apply(machine.abort(.destinationChanged))
        case .interrupted: apply(machine.abort(.listenerInterrupted))
        case .none: break
        }
    }

    private func tick() {
        if now - lastReadinessCheck >= 1 {
            readiness = Permissions.snapshot()
            lastReadinessCheck = now
            if isReady && !monitor.isInstalled {
                if !monitor.install() { onStatus?("Allow Accessibility and Input Monitoring", false) }
            }
        }
        guard machine.phase != .idle else { return }
        let drained = audio.drain()
        if drained.failed || (machine.phase == .recording && !audio.isRunning) {
            apply(machine.abort(.microphoneFailed))
            return
        }
        speech.append(drained.chunks)
        speech.checkTimeout(now: now)
        let valid = targetIsCurrent(checkSelection: machine.phase != .inserting)
        apply(machine.tick(now: now, hotkeyHeld: monitor.isHeld, modifiersDown: monitor.modifiersDown,
                           targetValid: valid, permissionsValid: isReady))
        switch machine.phase {
        case .recording:
            let elapsed = Int(max(0, now - machine.startedAt))
            onStatus?(String(format: "Recording %d:%02d · Escape cancels", elapsed / 60, elapsed % 60), true)
        case .finalizing: onStatus?("Transcribing on this Mac…", true)
        case .waitingForModifiers: onStatus?("Release the shortcut keys…", true)
        case .inserting: onStatus?("Inserting…", true)
        case .idle: break
        }
    }

    private func targetIsCurrent(checkSelection: Bool = true) -> Bool {
        guard capturedRevision == monitor.activityRevision, let destination else { return false }
        return DestinationAccess.isCurrent(destination, checkSelection: checkSelection)
    }

    private func apply(_ effects: [SessionEffect]) {
        monitor.sessionActive = machine.phase != .idle
        for effect in effects {
            switch effect {
            case .start(let generation):
                guard speech.start(generation: generation) else { continue }
                do { try audio.start() }
                catch { apply(machine.abort(.microphoneFailed)) }
            case .finalize:
                audio.stop()
                let drained = audio.drain()
                if drained.failed { apply(machine.abort(.microphoneFailed)); continue }
                speech.append(drained.chunks)
                speech.finish()
            case .cancel:
                insertionTask?.cancel()
                insertionTask = nil
                audio.discard()
                speech.cancel()
                destination = nil
            case .insert(let generation, let text):
                guard let destination else {
                    apply(machine.insertionFinished(generation: generation, succeeded: false))
                    continue
                }
                insertionTask = Task { [weak self] in
                    guard let self else { return }
                    let succeeded = await DestinationAccess.insert(text, into: destination) {
                        self.machine.phase == .inserting && self.machine.generation == generation &&
                            self.targetIsCurrent(checkSelection: false)
                    }
                    self.apply(self.machine.insertionFinished(generation: generation, succeeded: succeeded))
                }
            case .completed:
                audio.discard()
                destination = nil
                insertionTask = nil
                onStatus?("Inserted", false)
            case .failed(let reason):
                if machine.phase == .idle { destination = nil }
                onStatus?(message(reason), false)
            }
        }
        monitor.sessionActive = machine.phase != .idle
    }

    func cancel() { apply(machine.abort()) }

    func stop() {
        cancel()
        timer?.invalidate()
        timer = nil
        monitor.stop()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers = []
    }

    private func message(_ code: FailureCode) -> String {
        switch code {
        case .notReady: return "Complete LocalFlow Setup before recording"
        case .unsupportedTarget: return "Focus a supported, editable text field"
        case .destinationChanged: return "Cancelled: the destination changed"
        case .cancelled: return "Cancelled"
        case .recognitionFailed: return "Local recognition failed; nothing inserted"
        case .recognitionTimeout: return "Local recognition timed out; nothing inserted"
        case .modifierTimeout: return "Shortcut keys stayed pressed; nothing inserted"
        case .insertionFailed: return "Insertion incomplete; check the destination before retrying"
        case .microphoneFailed: return "Microphone interrupted; nothing inserted"
        case .listenerInterrupted: return "Keyboard listener interrupted; recording cancelled"
        case .emptyTranscript: return "No speech recognized"
        case .transcriptTooLarge: return "Transcript exceeds the size limit; nothing inserted"
        }
    }
}
