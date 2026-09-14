# Implementation status

No release has passed real-device acceptance yet.

## Current implementation

- Public repository created with atomic commits directly on main.
- Native release app builds locally. The system CLT installation is unchanged;
  `scripts/local-swift.sh` supplies an isolated overlay for its stale files.
- Twenty-one core tests pass; all eight core source files have 100% executable-line
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
  recognized, 1,381 word errors (85.88% WER). A subsequent 58-second trace on
  `af7cf57` confirmed that Apple's local engine completed three earlier
  utterances (78 segments) before returning only nine segments in the first
  window's final callback. The completed-utterance accumulator and adapter fix
  are implemented and core-tested; real recognition retesting remains required.
- All four grants were verified allowed for the diagnostic `af7cf57` build.
  Its TextEdit attempt still inserted nothing: the hardware Space state was true
  while the downstream session state was false. The event tap consumes Space;
  the hold check now uses the upstream HID state. Hardware retesting is required.
- Unsigned rebuilt apps require fresh OS grants. Computer use cannot access the
  permission-alert app. Existing keyboard grants may show enabled yet refer to
  an obsolete signature; reset only LocalFlow's affected grant and approve the
  current bundle through normal macOS settings.
- Keep public diagnostic audio in a temporary folder. Reading a fixture under
  Documents can wait for an unrelated Files & Folders grant before recognition
  starts; the production microphone flow requires no document-file access.
- Native build, core coverage, and installer checks passed on macOS 14, 15, and
  26 at `14dc071`. Its separate architecture check had an incorrectly ordered
  `lipo` command; `46ebcd9` fixes that. Fresh CI must verify both architectures.
- The native hardware driver now requires observed Recording and explicit
  Inserted/Cancelled status. An unchanged empty field alone cannot pass a
  cancellation test. This driver change has compiled; hardware validation remains
  outstanding.
- Both CI and Security passed at `af7cf57`, including both architecture builds,
  all three macOS runners, CodeQL, Gitleaks, shell checks, and release-gate tests.
  The subsequent speech/hotkey fixes require fresh CI and hardware evidence.
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
