import AppKit

private final class IndicatorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class RecordingIndicator {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private var revision: UInt64 = 0

    init() {
        panel = IndicatorPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 52),
                               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        let background = NSVisualEffectView(frame: panel.contentView!.bounds)
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        label.frame = NSRect(x: 16, y: 16, width: 388, height: 20)
        label.alignment = .center
        label.font = .systemFont(ofSize: 13, weight: .medium)
        background.addSubview(label)
        panel.contentView = background
    }

    func show(_ message: String, active: Bool) {
        revision &+= 1
        label.stringValue = message
        label.textColor = active ? .systemRed : .labelColor
        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 210, y: screen.visibleFrame.minY + 48))
        }
        panel.orderFrontRegardless()
        if !active {
            let expected = revision
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self, self.revision == expected else { return }
                self.panel.orderOut(nil)
            }
        }
    }
}
