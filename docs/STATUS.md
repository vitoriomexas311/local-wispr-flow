# Implementation status

No release has passed real-device acceptance yet.

## Initial environment

- macOS 14.8.4, Apple Silicon; Swift 6.0.3 command-line tools.
- Speech readiness probe: en-US required assets unavailable;
  `supportsOnDeviceRecognition=false` despite `isAvailable=true`.
- Existing command-line tools contain duplicate SwiftBridging module maps;
  framework imports fail. Investigating an isolated workaround.
- Full Xcode and Developer ID signing identities absent. The pilot is unnotarized.

## Required acceptance

Core coverage, packaged app, real local recognizer, microphone, long recording,
Terminal/OpenCode, TextEdit, browser fields, cancellation/focus safety, offline
cold start, and CI must all be verified before a downloadable release is published.
