import SwiftUI
import DictationCore

@MainActor
final class SetupModel: ObservableObject {
    @Published var engine: RecognitionEngine = .whisperTiny
    @Published var shortcut = ""
    @Published var recordingShortcut = false
    @Published var shortcutHint = "A key with any modifiers, or modifiers on their own."
    @Published var modelReady = false
    @Published var microphone = false
    @Published var accessibility = false
    @Published var inputMonitoring = false
    @Published var appleReady = false
    @Published var ready = false
    @Published var busy = false
    @Published var idle = true
    @Published var message = ""
    var selectEngine: ((RecognitionEngine) -> Void)?
    var recordShortcut: (() -> Void)?
    var cancelShortcut: (() -> Void)?
    var download: (() -> Void)?
    var importModel: (() -> Void)?
    var permissions: [(String, () -> Void)] = []
    var prepareApple: (() -> Void)?
}

struct FlowButton: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 11)
            .foregroundStyle(primary ? Color.white : SetupView.ink)
            .background(primary ? SetupView.coral : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(SetupView.ink.opacity(primary ? 0 : 0.16)))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct SetupView: View {
    @ObservedObject var model: SetupModel
    static let ink = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let coral = Color(red: 0.91, green: 0.24, blue: 0.25)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Image(systemName: "waveform").foregroundStyle(Self.coral).font(.system(size: 24, weight: .semibold))
                Text("LocalFlow").font(.system(size: 23, weight: .semibold))
                Spacer()
            }
            Divider()
            HStack {
                Text("Shortcut").frame(width: 110, alignment: .leading)
                Text(model.recordingShortcut ? "Press keys…" : model.shortcut)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .accessibilityLabel("Current shortcut: \(model.shortcut)")
                Spacer()
                Button(model.recordingShortcut ? "Cancel" : "Change") {
                    if model.recordingShortcut { model.cancelShortcut?() } else { model.recordShortcut?() }
                }.buttonStyle(FlowButton()).disabled(!model.idle)
                    .accessibilityLabel(model.recordingShortcut ? "Cancel shortcut recording" : "Change shortcut")
            }
            if model.recordingShortcut {
                Text(model.shortcutHint).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack {
                Text("Engine").frame(width: 110, alignment: .leading)
                Picker("Engine", selection: Binding(get: { model.engine }, set: { model.selectEngine?($0) })) {
                    ForEach(RecognitionEngine.allCases, id: \.self) { engine in Text(engine.title).tag(engine) }
                }.labelsHidden().disabled(!model.idle || model.busy)
            }
            if model.engine == .whisperTiny {
                HStack(spacing: 12) {
                    Label(model.modelReady ? "Model installed" : "Model required · 32 MB", systemImage: model.modelReady ? "checkmark.circle.fill" : "arrow.down.circle")
                        .foregroundStyle(model.modelReady ? Color.green : Self.ink)
                    Spacer()
                    if !model.modelReady {
                        Button("Download") { model.download?() }.buttonStyle(FlowButton(primary: true))
                    }
                    Button("Import…") { model.importModel?() }.buttonStyle(FlowButton())
                    if model.busy { ProgressView().controlSize(.small) }
                }.disabled(model.busy || !model.idle)
            } else {
                Button(model.appleReady ? "Apple Speech available" : "Enable Apple Speech") { model.prepareApple?() }
                    .buttonStyle(FlowButton())
            }
            Divider()
            Text("Permissions").font(.system(size: 13, weight: .semibold))
            VStack(spacing: 12) {
                ForEach(Array(model.permissions.enumerated()), id: \.offset) { index, permission in
                    let allowed = [model.microphone, model.accessibility, model.inputMonitoring][index]
                    HStack {
                        Text(permission.0)
                        Spacer()
                        if allowed {
                            Label("Allowed", systemImage: "checkmark").foregroundStyle(Color.green)
                        } else {
                            Button("Allow") { permission.1() }.buttonStyle(FlowButton())
                                .accessibilityLabel("Allow \(permission.0)")
                        }
                    }
                }
            }
            if model.busy || !model.message.isEmpty {
                Text(model.message).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 13)).padding(28).foregroundStyle(Self.ink)
        .frame(minWidth: 540, minHeight: 510).background(Color.white)
        .preferredColorScheme(.light)
    }
}
