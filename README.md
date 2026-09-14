# LocalFlow

Private hold-to-dictate for macOS 14+. Native Swift, Apple's on-device speech
engine, no cloud fallback, and no third-party runtime dependencies.

**Development in progress. No validated downloadable release yet.**

Hold Control–Option–Space, speak, release, and insert the final text in the
original field. US English is the first supported language. Local speech assets
must be installed before offline use. Unsupported configurations refuse capture.

Application, installer, and test code are MIT licensed. Apple's speech framework
and model are proprietary macOS components.

## Privacy boundary

LocalFlow will not intentionally persist audio/transcripts, use the clipboard,
send telemetry, or send speech to a server. A destination application can still
store or transmit the text you insert. This project does not certify CUI
compliance or control macOS memory, diagnostics, or other applications.

See [the threat model](docs/THREAT_MODEL.md) and [implementation status](docs/STATUS.md).
