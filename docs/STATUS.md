# Implementation status

No release has passed real-device acceptance yet.

## Current implementation

- Public repository created with atomic commits directly on main.
- Native release app builds locally. The system CLT installation is unchanged;
  `scripts/local-swift.sh` supplies an isolated overlay for its stale files.
- Sixteen core tests pass; all six core source files have 100% executable-line
  coverage. This does not measure Apple's engine or platform adapters.
- Speech, microphone, Accessibility, and Input Monitoring permission setup has
  been exercised through the app. Ad-hoc rebuilt apps may require new grants.
- Local en-US assets are now available.
- Real Apple recognizer, injected synthetic audio: same 12-word fixture scored
  25% word error rate with Samantha and 8.33% with Eddy. Both measurements are
  retained; neither is a real microphone or network-isolation result.
- Hosted CI passes after selecting Xcode 16.2 explicitly on macOS 14.
- Integrated hotkey, microphone, rotation, target guard, and insertion code builds.
  Real cross-app and offline acceptance are still pending.

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

The owner's supplied portrait will be converted to the LocalFlow app icon after
functional validation. No downloadable release has been published.
