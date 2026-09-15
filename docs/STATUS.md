# Implementation status

## v0.1.0 release, September 15, 2026

[The public release](https://github.com/vitoriomexas311/local-wispr-flow/releases/tag/v0.1.0)
is built from `316b316368dd047cd8c18f3be2c9aecc35aa0e49`. Its universal ZIP bundles
Whisper Tiny English and supports setup without networking. The owner explicitly
authorized publishing without additional physical tests and reports microphone
functionality works. This supersedes the original all-hardware-gates release
requirement for this release only; the strict verifier remains available for
future independently measured hardware acceptance.

Exact ZIP SHA-256: `5654c65ebee24c6ee541b62e6ccf68e2c7fa60aedfdf285b03bf6654bb86a353`.
CI and Security passed for that source commit. Exact-ZIP offline setup/reinstall,
installer lifecycle, rollback, tamper and symlink checks passed. The bundled
native worker recognized the public JFK fixture with networking and file writes
denied. A whole-app nested-sandbox experiment could not run because macOS rejects
nested sandbox initialization; it is not counted as passing.

Earlier source `8b3a72b` passed real microphone-to-TextEdit insertion on a public
22-word fixture, including a custom shortcut: zero word errors and unchanged
clipboard. Separate file-injection comparisons at `f3aec69` (three trials) gave
median finalization of 0.083 seconds / one word error for Apple and 0.425 seconds /
zero errors for Whisper. These narrow results do not establish broad accuracy.

No new physical microphone, cross-app, ten-minute hold or whole-device offline
tests were performed for the release. The machine is not made air-gapped by the
app. Release `VALIDATION.json` records these limits; no CUI certification is claimed.

The sections below retain historical implementation and test notes.

## Implemented

- Native macOS menu-bar app, waveform icon, hold-to-dictate shortcuts, recording HUD,
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
- Shortcut recorder accepts custom physical keys with any standard modifiers,
  plus modifier-only chords including Fn. Legacy preset settings migrate in place.
  Caps Lock/media keys and OS-reserved combinations have platform limitations.
- Compact settings show only shortcut, engine/model, permissions and active status.
- Universal offline packaging includes Apple Silicon/Intel binaries and the verified
  Whisper model. `bash ./setup.sh` installs both offline and opens the app. An
  app-only package downloads the model once; explicit offline import is supported.


## Measured results, September 15, 2026

All speech fixtures below are public synthetic audio, **not real microphone
acceptance**. Accuracy is reported, not a fixed numeric release gate.

- 28 core tests passed; all nine core source files have 100% executable-line
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

The owner waived further physical testing for v0.1.0. Original uncompleted
hardware cases remain unverified; fixture tests cannot substitute for them.
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

`dist/LocalFlow-universal-draft.zip` (with model) and architecture-specific ZIPs
are local candidates with adjacent `.sha256` files.
Read the embedded `SOURCE_COMMIT` and checksum for current provenance. Do not
publish or label a candidate validated until its exact-artifact hardware gates pass.
The model is installed separately under
`~/Library/Application Support/LocalFlow/Models` and is not stored in Git.

Local machine: macOS 14.8.4, Apple Silicon, Swift 6.0.3 command-line tools. The
isolated `scripts/local-swift.sh` workaround leaves the system CLT installation
unchanged. Full Xcode and a Developer ID identity are absent; the pilot is ad-hoc
signed and unnotarized. Employees need no compiler or package manager.
