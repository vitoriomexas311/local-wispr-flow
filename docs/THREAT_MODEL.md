# Threat model

## Protected data and trust boundaries

Audio and recognized text are sensitive. Trust the local OS, Apple's on-device
recognizer or the pinned local Whisper runtime/model, and the selected destination. The application cannot protect a
compromised OS or control the destination's storage/network behavior.

The recognition capability flag is read, never forged. For the Apple engine, before microphone access,
require authorization and `supportsOnDeviceRecognition == true`. Every request
requires on-device recognition. No alternative recognizer is selected on error.
System asset provisioning is a distinct, explicit setup operation before use.

## Controls

- Recognition never invokes networking. No analytics, content logs, transcript
  history, clipboard use, or updater. Explicit Whisper provisioning invokes only
  the bundled download script and verifies a pinned model SHA-256 before an atomic
  install. Offline import uses the same verification. Neither path receives audio.
- The selected engine never falls back automatically. Whisper requires a verified
  model and bundled native helper, plus microphone, Accessibility, and Input
  Monitoring permissions; it does not require Apple's Speech authorization/assets.
- Whisper runs in a child process receiving bounded mono PCM over stdin and
  returning timestamped JSON through stdout. Audio and text are not written to
  temporary files or command-line arguments. Its logging is disabled and stderr
  discarded. Cancellation terminates the child; stale results cannot insert text.
- Helper source and model downloads are pinned. The C/C++ dependency is scanned
  alongside Swift. The production helper denies networking and file writes; company acceptance
  still includes device-wide offline validation.
- Bounded in-memory audio; destroy session references after completion/cancel.
  Swift and macOS may retain memory copies; secure erasure is not claimed.
- Focus and input guards before insertion; detected secure fields are rejected.
  No Return/Tab/control events, shell interpolation, or automatic retry.
- Keyboard monitoring inspects only hotkey/event metadata. Never collect typed
  characters or surrounding document content.
- TCC permissions are granted through normal OS controls; no database patching.
- Unsigned pilot installation does not disable Gatekeeper or strip quarantine.
- Public CI receives only code and synthetic test data, never company content.
- Whole-device offline operation requires external network isolation. The absence
  of app networking is not a sandbox over Apple's speech-service processes.

## Release evidence

Security scans and core coverage do not establish microphone, model, or target
compatibility. A release additionally requires recorded real-device offline and
cross-app acceptance for the exact binary. Unsupported or untested environments
must remain explicit. No release is labeled validated while these gates fail.
