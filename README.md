# LocalFlow

<img src="Resources/LocalFlow.png" width="112" alt="LocalFlow waveform icon">

Private hold-to-dictate for macOS 14+. Native Swift, Apple's on-device speech
engine or an optional **32 MB Whisper Tiny English model**, with no cloud fallback.

**[Download v0.1.0 — universal offline ZIP](https://github.com/vitoriomexas311/local-wispr-flow/releases/download/v0.1.0/LocalFlow-v0.1.0-universal-offline.zip).** Unsigned macOS release, with the model included.
[Release notes and validation](https://github.com/vitoriomexas311/local-wispr-flow/releases/tag/v0.1.0) distinguish automated offline checks from owner-reported microphone acceptance.

Hold Control–Option–Space, speak, release, and insert the final text in the
original field. US English is the first supported language. Prepare Apple speech
assets or install the tiny Whisper model before offline use. Unsupported configurations refuse capture.

Click **Change** next to Shortcut and press any key with your preferred modifiers.
Modifier-only chords (including Fn) are supported. Release modifiers to save them.
Existing shortcuts are preserved across upgrades. Shortcuts take priority while
LocalFlow runs; OS-reserved combinations may be intercepted by macOS. Caps Lock
and media keys are not hold shortcuts. Test your choice in a disposable text field.

Application, installer, and test code are MIT licensed. Apple's speech framework
and model are proprietary macOS components. The optional Whisper runtime and model
are MIT licensed.

## Tiny local model

For another Mac, transfer the **universal offline ZIP**, extract it, and run:

```sh
bash ./setup.sh --offline ./Models/ggml-tiny.en-q5_1.bin
```

The offline ZIP contains the app for Apple Silicon and Intel plus the verified
32 MB model. Setup installs both without networking, selects Whisper by default
on a fresh installation, and opens the app. Allow Microphone, Accessibility, and
Input Monitoring in macOS. No account, compiler, Homebrew, Python, or API key.

A smaller app-only ZIP uses the same command, downloading the model once. To
prohibit that download and supply your own verified copy:

```sh
bash ./setup.sh --offline /path/to/ggml-tiny.en-q5_1.bin
```

Model import/download is also available in the app. Apple Speech remains an
optional engine and needs its separate permission and OS assets. No recognition
engine falls back to a cloud service.

The app transcribes during the hold in bounded, overlapping windows, retains text
in memory, and inserts only after release. A small 36×36 recording symbol appears at the
top right below the menu bar. A closed MacBook lid disconnects its built-in
microphone; use an external microphone when working with the lid closed.

## Privacy boundary

LocalFlow will not intentionally persist audio/transcripts, use the clipboard,
send telemetry, or send speech to a server. A destination application can still
store or transmit the text you insert. This project does not certify CUI
compliance or control macOS memory, diagnostics, or other applications.

The app does not air-gap the Mac: disconnect its networks separately and follow
your organization’s transfer policy. Use the bundled Whisper model for offline
installation. The release was owner-authorized without further physical tests;
full cross-app and whole-device offline acceptance is not claimed.

See [the threat model](docs/THREAT_MODEL.md) and [implementation status](docs/STATUS.md).

## Development

```sh
# Build tools: Swift 6+, macOS SDK, CMake 3.20+
scripts/local-swift.sh test --disable-xctest --enable-code-coverage
scripts/build-app.sh
scripts/package.sh
```

Quit LocalFlow before replacing its development bundle. To build a separate
candidate without touching the running app, prefix build/package commands with
`LOCALFLOW_BUILD_VARIANT=candidate-app`. The package is created
under `dist/` as a local draft. It installs using `bash ./install.sh`, without
downloads, a compiler, a package manager, or sudo. macOS approval and permissions
remain explicit. No quarantine or Gatekeeper bypass is included.

[Hardware acceptance](docs/ACCEPTANCE.md), [dependency inventory](docs/DEPENDENCIES.md),
and [native test driver](Tests/MacHarness/README.md) describe the remaining gates.
