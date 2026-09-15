# Implementation status

The tiny local engine is implemented and downloaded. No public release has passed
all real-device acceptance gates yet.

## Implemented

- Native macOS menu-bar app, photo icon, hold-to-dictate shortcuts, recording HUD,
  cancellation, guarded destination insertion, and offline installer.
- Apple on-device recognition remains available. Optional Whisper tiny.en Q5_1
  uses a 32.2 MB verified model and a bundled native whisper.cpp helper.
- Setup includes engine selection, explicit model download, and verified offline
  file import. Whisper needs Microphone, Accessibility, and Input Monitoring;
  Apple's Speech permission/assets apply only to the Apple engine.
- Whisper processes bounded 25-second windows with one-second overlap. PCM and
  text travel through memory pipes. The helper denies network access and file
  writes. Cancelled/stale results cannot insert text. No automatic engine fallback.
- Model provisioning is outside the signed app and preserves existing app grants.
  Replacing an unsigned app build may still require fresh macOS permission grants.
- Default shortcut: Control–Option–Space. Other choices include Option–Shift–Space
  and Shift–Tab. Caps Lock is not implemented. The recording banner is bottom
  center above the Dock.

## Measured results, September 15, 2026

All speech fixtures below are public synthetic audio, **not real microphone
acceptance**. Accuracy is reported, not a fixed numeric release gate.

- 26 core tests passed; all nine core source files have 100% executable-line
  coverage. This does not measure the native dependency or platform adapters.
- The native helper passed malformed-input, silence, timestamp-bound, and real
  recognition tests with network access and file writes denied.
- Clean application build `a8294d3`: short resampling/transcription test passed,
  with 0.28 seconds finalization latency and 8.33% word error rate.
- Same build: 58-second, multi-window transcription passed, with 0.32 seconds
  finalization latency; 155 recognized words, 13 errors out of 156 expected.
- The ten-minute development integration run completed in 600.35 seconds,
  finalizing in 0.34 seconds: 1,596 recognized words, 139 errors out of 1,608
  expected (8.64% WER). This run preceded the final helper sandbox integration;
  the clean multi-window test above exercised that production sandbox path.
- Actual pipeline cancellation/stale-result tests passed in the clean app build.
- Offline model import, checksum rejection preserving the existing model, and
  symlink refusal passed. App installation, repeat install, rollback, uninstall,
  checksum-tamper rejection, and independent symlink rejection passed locally.
- [CI at a8294d3](https://github.com/vitoriomexas311/local-wispr-flow/actions/runs/35014881586)
  passed on macOS 14, 15, and 26, including both architecture builds and packaged
  Whisper integration tests. Subsequent commits require their own checks.
- Swift and C/C++ CodeQL run separately, alongside secret scanning, shell lint,
  source guardrails, and release-gate tests. Their live run results are authoritative;
  a pending scan is not a pass.

## Remaining acceptance

This Mac reported its lid closed with the built-in microphone selected. That mic
is disconnected by hardware with the lid closed. The owner has been asked to open
the lid or connect an external microphone before microphone-to-text validation.
Computer use refused Terminal.app, so Terminal/OpenCode testing must be performed
by the owner; the isolated launcher is in `Tests/Manual`.

Actual microphone insertion, selected-text replacement, browser/Terminal
compatibility, protected-field behavior, the real ten-minute hold, and whole-device
offline cold-start/repeated dictation are not yet established for the new build.
Platform executable coverage has not been collected. Tests and scans do not
certify company-wide CUI compliance.

The earlier Apple engine ten-minute run scored 16.23% WER and showed possible
final-utterance loss. That Apple-specific investigation is unresolved; the optional
Whisper engine does not use that accumulator. Historical failed reports remain
unchanged. The owner removed the diagnostic 15% accuracy target as a personal-pilot
blocker on September 14.

## Artifacts and environment

`dist/LocalFlow-arm64-draft.zip` and its adjacent `.sha256` file are local candidates.
Read the embedded `SOURCE_COMMIT` and checksum for current provenance. Do not
publish or label a candidate validated until its exact-artifact hardware gates pass.
The model is installed separately under
`~/Library/Application Support/LocalFlow/Models` and is not stored in Git.

Local machine: macOS 14.8.4, Apple Silicon, Swift 6.0.3 command-line tools. The
isolated `scripts/local-swift.sh` workaround leaves the system CLT installation
unchanged. Full Xcode and a Developer ID identity are absent; the pilot is ad-hoc
signed and unnotarized. Employees need no compiler or package manager.
