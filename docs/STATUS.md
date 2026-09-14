# Implementation status

No release has passed real-device acceptance yet.

## Current implementation

- Public repository created with atomic commits directly on main.
- Native release app builds locally. The system CLT installation is unchanged;
  `scripts/local-swift.sh` supplies an isolated overlay for its stale files.
- Eighteen core tests pass; all seven core source files have 100% executable-line
  coverage. This does not measure Apple's engine or platform adapters.
- Speech, microphone, Accessibility, and Input Monitoring permission setup has
  been exercised through the app. Ad-hoc rebuilt apps may require new grants.
- Local en-US assets are now available.
- Real Apple recognizer, injected synthetic audio: same 12-word fixture scored
  25% word error rate with Samantha and 8.33% with Eddy. Both measurements are
  retained; neither is a real microphone or network-isolation result.
- Core build/coverage CI has passed on macOS 14, 15, and 26. Native installer and
  architecture package checks are now included; each final SHA needs fresh CI.
- Swift CodeQL completed with zero reported findings. Gitleaks found no secrets
  in Git history. The first ShellCheck run found a message-format warning, which
  was fixed. Final required checks must pass on the release SHA.
- Integrated hotkey, microphone, rotation, target guard, and insertion code builds.
  Real cross-app and offline acceptance are still pending.
- Offline installer lifecycle, repeat installation, rollback, recoverable
  uninstall, checksum-tamper rejection, and symlink rejection passed locally.
- First speaker-to-microphone TextEdit attempt inserted no words: failed. It
  does not establish that microphone capture was reached. Clipboard unchanged.
- A full 600-second injected-audio test failed: 1,608 expected words, 235
  recognized, 1,381 word errors (85.88% WER). Do not use this build for long
  dictation. Per-window and partial-result diagnostics have been added to locate
  the loss without logging text. An utterance-reset issue reported for Apple's
  local engine is a hypothesis, not yet a confirmed diagnosis on this Mac.
- After the owner unlocked Privacy & Security, LocalFlow was added to Input
  Monitoring and restarted; that permission now reports allowed. Speech,
  Microphone, and Accessibility still report permission needed. Subsequent
  diagnostics and hardware tests await those owner-completed grants; computer
  use cannot access the OS permission-alert app.
- Native build, core coverage, and installer checks passed on macOS 14, 15, and
  26 at `14dc071`. Its separate architecture check had an incorrectly ordered
  `lipo` command; `46ebcd9` fixes that. Fresh CI must verify both architectures.
- The native hardware driver now requires observed Recording and explicit
  Inserted/Cancelled status. An unchanged empty field alone cannot pass a
  cancellation test. This driver change has compiled; hardware validation awaits
  the permissions above.
- The owner's photograph is now the app/menu-bar icon. Exported assets contain
  pixels and color-space information only. The original photo is not committed.

Platform executable coverage is not yet collected. Core coverage, mocked safety
decisions, and release-gate fixtures are not substitutes for hardware acceptance.

## Initial environment

- macOS 14.8.4, Apple Silicon; Swift 6.0.3 command-line tools.
- Speech readiness probe: en-US required assets unavailable;
  `supportsOnDeviceRecognition=false` despite `isAvailable=true`.
- Existing command-line tools contain duplicate SwiftBridging module maps;
  framework imports initially failed; isolated workaround implemented.
- Full Xcode and Developer ID signing identities absent. The pilot is unnotarized.

## Required acceptance

Core coverage, packaged app, real local recognizer, microphone, long recording,
Terminal/OpenCode, TextEdit, browser fields, cancellation/focus safety, offline
cold start, and CI must all be verified before a downloadable release is published.

No downloadable release has been published. The unvalidated draft ZIP stays local.
