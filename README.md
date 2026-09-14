# LocalFlow

<img src="Resources/LocalFlow.png" width="112" alt="LocalFlow photo icon">

Private hold-to-dictate for macOS 14+. Native Swift, Apple's on-device speech
engine, no cloud fallback, and no third-party runtime dependencies.

**Experimental. No validated downloadable release yet.** A ten-minute
recognition test lost substantial text. The fixes still require real-device
acceptance before company deployment.

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

## Development

```sh
scripts/local-swift.sh test --disable-xctest --enable-code-coverage
scripts/build-app.sh
scripts/package.sh
```

Quit LocalFlow before replacing its development bundle. The package is created
under `dist/` as a local draft. It installs using `bash ./install.sh`, without
downloads, a compiler, a package manager, or sudo. macOS approval and permissions
remain explicit. No quarantine or Gatekeeper bypass is included.

[Hardware acceptance](docs/ACCEPTANCE.md), [dependency inventory](docs/DEPENDENCIES.md),
and [native test driver](Tests/MacHarness/README.md) describe the remaining gates.
