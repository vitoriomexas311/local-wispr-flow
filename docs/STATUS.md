# Implementation status

No release has passed real-device acceptance yet.

## Current verified build

The approved local app was built from `4c401c5d53dcd94d0ec91ea8c5031cb651308273`.
Keep that bundle unchanged while completing microphone acceptance: rebuilding an
ad-hoc signed app can invalidate existing macOS permission grants.

- The repository is public, MIT licensed, with atomic commits pushed to main.
- Twenty-three core tests pass, with 100% executable-line coverage across all
  eight core files. Platform executable coverage has not been collected.
- Both [CI](https://github.com/vitoriomexas311/local-wispr-flow/actions/runs/34911299940)
  and [Security](https://github.com/vitoriomexas311/local-wispr-flow/actions/runs/34911299998)
  passed for this source commit. Checks include macOS 14, 15, and 26, architecture
  packaging, installer lifecycle, Swift CodeQL, Gitleaks, and shell checks.
- All four grants were verified: Speech Recognition, Microphone, Accessibility,
  and Input Monitoring. Local en-US recognition is supported and available.
- The current machine preference is Option–Shift–Space. The shipped default is
  Control–Option–Space; Shift–Tab is also supported. Caps Lock is not implemented
  and no keyboard remapping was applied.
- A native TextEdit test observed capture start and cancellation, with the field
  and clipboard unchanged. Computer use also observed the actual floating
  `Recording 0:04 · Escape cancels` banner, at bottom center above the Dock.
  These closed-lid tests prove activation, not acoustic pickup or dictation insertion.
- The short injected-audio test using Apple's recognizer scored 8.33% word error
  rate. The full 600-second injected test completed all 14 recognition windows:
  1,608 expected words, 1,385 recognized, 261 errors, 16.23% word error rate.
  That report retains its original failed status against the diagnostic 15% target.
- On September 14, the owner removed that accuracy target as a blocker for the
  personal pilot. Accuracy remains reported; hardware and offline acceptance
  requirements remain. The release verifier does not impose a numeric WER cutoff.
- The final recognition window retained fewer segments than earlier completed
  utterances in that window. Possible transcript loss in final-result reconciliation
  remains under investigation; the measurements do not prove the cause is model
  accuracy alone. Earlier fixes improved the ten-minute result from 85.88% WER.
- A speaker-to-microphone attempt inserted no text. This Mac still reported its
  lid closed with the built-in microphone selected. The owner must open the lid
  or use an external microphone before acoustic acceptance can establish pickup.
- Computer use refused Terminal.app access. The isolated OpenCode 1.18.31 launcher
  in `Tests/Manual` supports owner-performed testing; no alternative automation API
  may be used to bypass that refusal. Terminal/OpenCode acceptance is outstanding.
- Browser insertion, the full real-microphone duration test, and device-wide offline
  cold-start/repeated dictation acceptance are outstanding. Mocked and injected
  tests cannot satisfy those gates.
- The owner's photograph is the app/menu-bar icon. Only exported pixel assets are
  committed; the original photo is excluded.

## Local package

The draft `LocalFlow-arm64-draft.zip` contains the approved build and an offline
installer. Its SHA-256 is
`cc83c2c4d65c78a1ce0b18a4c9924de2c6bcbbeedb0213cf23adea9ce39d6cfa`.
The app executable SHA-256 is
`98129b17fc5cfcdc5287d8f587799cf9f04ac5727a3a43434ea3a690c429ec84`.
These identify an unvalidated local draft, not a published release.

Installer lifecycle checks passed in CI for this source. The latest local rerun
correctly refused to install while LocalFlow was running; that refusal is not a
local lifecycle pass. Do not quit or replace the approved app merely to repeat
already passing CI checks.

## Optional engine research

The owner requested a comparison of downloadable local models. Moonshine Tiny
Streaming and quantized Whisper tiny.en were recommended for evaluation; neither
is integrated or installed. Apple remains the implemented engine. A future model
option must preserve offline dictation and explicit, separately controlled asset
provisioning.

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
