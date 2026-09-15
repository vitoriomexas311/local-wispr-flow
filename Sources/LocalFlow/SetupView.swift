import SwiftUI
import DictationCore

@MainActor
final class SetupModel: ObservableObject {
    @Published var engine: RecognitionEngine = .whisperTiny
    @Published var shortcut = ""
    @Published var shortcutKeys: [String] = []
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
            .modifier(PressFeedback(pressed: configuration.isPressed))
    }
}

struct SetupView: View {
    @ObservedObject var model: SetupModel
    @State private var choosingModel = false
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
                if model.recordingShortcut {
                    Text("Press keys…").foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 5) {
                        ForEach(Array(model.shortcutKeys.enumerated()), id: \.offset) { _, key in
                            Text(key)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 9)
                                .frame(minWidth: 30, minHeight: 32)
                                .background(Color(white: 0.97))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Self.ink.opacity(0.18)))
                                .shadow(color: Self.ink.opacity(0.1), radius: 0, y: 2)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Current shortcut: \(model.shortcut)")
                }
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
                Text("Model").frame(width: 110, alignment: .leading)
                Button { choosingModel.toggle() } label: {
                    HStack(spacing: 10) {
                        Text(model.engine.title).fontWeight(.medium)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(Color(white: 0.98))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Self.ink.opacity(0.16)))
                }
                .buttonStyle(PressButton())
                .accessibilityLabel("Choose model")
                .accessibilityValue(model.engine.title)
                .disabled(!model.idle || model.busy)
                .overlay(alignment: .topLeading) {
                    if choosingModel {
                    VStack(spacing: 4) {
                        ForEach(RecognitionEngine.allCases, id: \.self) { engine in
                            Button {
                                choosingModel = false
                                model.selectEngine?(engine)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(engine.title)
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Self.coral)
                                        .opacity(model.engine == engine ? 1 : 0)
                                }
                                .padding(12).contentShape(Rectangle())
                            }
                            .buttonStyle(ModelOptionStyle(selected: model.engine == engine))
                            .accessibilityValue(model.engine == engine ? "Selected" : "")
                            .disabled(!model.idle || model.busy)
                        }
                    }
                    .padding(6).frame(maxWidth: .infinity)
                    .foregroundStyle(Self.ink).background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Self.ink.opacity(0.16)))
                    .shadow(color: Self.ink.opacity(0.12), radius: 12, y: 5)
                    .offset(y: 44)
                    .onExitCommand { choosingModel = false }
                    }
                }
                .onChange(of: model.idle) { _, idle in if !idle { choosingModel = false } }
                .onChange(of: model.busy) { _, busy in if busy { choosingModel = false } }
            }.zIndex(1)
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

private struct ModelOptionStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        ModelOptionLabel(label: configuration.label, selected: selected, pressed: configuration.isPressed)
    }

    private struct ModelOptionLabel: View {
        let label: ButtonStyleConfiguration.Label
        let selected: Bool
        let pressed: Bool
        @State private var hovered = false
        var body: some View {
            label
                .background(SetupView.ink.opacity(pressed ? 0.12 : hovered ? 0.07 : selected ? 0.04 : 0))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .modifier(PressFeedback(pressed: pressed, depth: 1))
                .onHover { hovered = $0 }
        }
    }
}

private struct PressButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(PressFeedback(pressed: configuration.isPressed))
    }
}

private struct PressFeedback: ViewModifier {
    let pressed: Bool
    var depth: CGFloat = 2
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled

    func body(content: Content) -> some View {
        content
            .brightness(pressed && enabled ? -0.035 : 0)
            .shadow(color: SetupView.ink.opacity(enabled ? 0.14 : 0.04),
                    radius: pressed ? 0 : 0.5, y: pressed ? 0 : depth)
            .offset(y: pressed && !reduceMotion ? depth : 0)
            .scaleEffect(pressed && !reduceMotion ? 0.985 : 1)
            .opacity(enabled ? 1 : 0.5)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.75), value: pressed)
    }
}
