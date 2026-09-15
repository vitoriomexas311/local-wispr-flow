# LocalFlow

<img src="Resources/LocalFlow.png" width="112" alt="LocalFlow photo icon">

Private hold-to-dictate for macOS 14+. Native Swift, Apple's on-device speech
engine or an optional **32 MB Whisper Tiny English model**, with no cloud fallback.

**Pilot. No validated public release yet.** Core and native-engine tests are
separate from real microphone/offline acceptance. See the measured status before
company deployment.

Hold Control–Option–Space, speak, release, and insert the final text in the
original field. US English is the first supported language. Prepare Apple speech
assets or install the tiny Whisper model before offline use. Unsupported configurations refuse capture.

Choose another shortcut in LocalFlow Setup, including Shift–Tab. That choice
uses Shift–Tab for dictation while LocalFlow is listening, overriding its usual
backward focus navigation. Plain Tab continues to work normally.

Application, installer, and test code are MIT licensed. Apple's speech framework
and model are proprietary macOS components. The optional Whisper runtime and model
are MIT licensed.

## Tiny local model

In LocalFlow Setup, click **Download Whisper Tiny · 32 MB**, then select
**Whisper Tiny English**. Allow Microphone, Accessibility, and Input Monitoring.
Apple Speech permission is needed only for the Apple engine.

From the release ZIP (or repository), provisioning also works with:

```sh
bash Distribution/download-model.sh
```

In an extracted release ZIP the script is at the top level:
`bash ./download-model.sh`. After this one-time model download, dictation is
entirely local. No account, API key, Python, Homebrew, or compiler is needed by
employees. The model stays outside the signed app, so installing it does not
invalidate app permissions.

For an offline workstation, transfer `ggml-tiny.en-q5_1.bin` and use **Import
model file offline…**, or pass its path to the same script. Both routes verify
the exact SHA-256; an incomplete or different model is rejected.

The app transcribes during the hold in bounded, overlapping windows, retains text
in memory, and inserts only after release. The recording banner appears at the
bottom center above the Dock. A closed MacBook lid disconnects its built-in
microphone; use an external microphone when working with the lid closed.

## Privacy boundary

LocalFlow will not intentionally persist audio/transcripts, use the clipboard,
send telemetry, or send speech to a server. A destination application can still
store or transmit the text you insert. This project does not certify CUI
compliance or control macOS memory, diagnostics, or other applications.

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
