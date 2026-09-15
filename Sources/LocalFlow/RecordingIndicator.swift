import AppKit

private final class IndicatorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class RecordingIndicator {
    private let panel: NSPanel
    private let symbol = NSImageView()
    private var revision: UInt64 = 0

    init() {
        panel = IndicatorPanel(contentRect: NSRect(x: 0, y: 0, width: 36, height: 36),
                               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        let background = NSView(frame: panel.contentView!.bounds)
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor(white: 0.98, alpha: 1).cgColor
        background.layer?.cornerRadius = 10
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor(white: 0.12, alpha: 0.16).cgColor
        symbol.frame = NSRect(x: 9, y: 9, width: 18, height: 18)
        symbol.imageScaling = .scaleProportionallyUpOrDown
        background.addSubview(symbol)
        panel.contentView = background
    }

    func show(_ message: String, active: Bool) {
        revision &+= 1
        let name: String
        if active {
            name = message.hasPrefix("Recording ") ? "waveform" : "ellipsis"
        } else if message == "Inserted" {
            name = "checkmark"
        } else {
            name = message.hasPrefix("Cancelled") ? "xmark" : "exclamationmark"
        }
        symbol.image = NSImage(systemSymbolName: name, accessibilityDescription: message)?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .semibold))
        symbol.contentTintColor = active
            ? NSColor(red: 0.91, green: 0.24, blue: 0.25, alpha: 1)
            : (message == "Inserted" ? .systemGreen : .darkGray)
        symbol.setAccessibilityLabel(message)
        panel.setAccessibilityLabel(message)
        // Keep the indicator below the menu bar, clear of the notch and screen edge.
        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 52,
                                         y: screen.visibleFrame.maxY - 48))
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
