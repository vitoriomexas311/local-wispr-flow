# Hardware acceptance and release

Hosted tests cannot validate speech assets, microphone pickup, permission prompts,
OpenCode focus, or device-wide offline operation. A release remains blocked until
the actual packaged app passes these tests on a provisioned Mac. Use public,
synthetic, or explicitly non-sensitive speech only. Never attach raw workstation
logs, screenshots with other documents, or sensitive audio to GitHub.

Build from a clean, final source commit. The build embeds that SHA in the signed
bundle; dirty builds are labeled and rejected by the release gate. Package it
with `scripts/package.sh`. Test the extracted app. Record the ZIP's SHA-256,
source SHA, macOS version, CPU architecture, microphone/speaker devices, all target
app versions, UTC test time, per-case results, accuracy, and latency. A later code
or bundle change requires testing the replacement artifact.

The required cases are enumerated in `scripts/verify-release.py`. For every case,
record its exact `id`, `status`, `input`, and a content-free `evidence` reference.
Required input is `actual-microphone`; injected audio does not satisfy hardware
gates. Offline cases additionally require `externalNetworking` set to
`unavailable-device-wide`, established by disconnecting every external interface.
Sandboxing only LocalFlow is insufficient because Apple recognition uses OS
services. The duration case must record `heldSeconds >= 600`.

Keep the acceptance JSON outside Git so it can identify the final commit without
a self-referential SHA. Top-level keys: `schema: 1`, `sourceCommit`, `archiveSHA256`,
`macOSVersion`, `architecture`, `inputDevice`, `outputDevice`, `testedAtUTC`,
`applicationVersions` (TextEdit, Terminal, OpenCode, browser), and `cases`.

Accuracy is a reported measurement, not a fixed numeric release cutoff. On
September 14, 2026, the owner removed the diagnostic 15% word-error target as a
blocker for the personal pilot. Preserve original probe reports and their stated
criteria; do not relabel historical failures. This does not waive actual microphone,
insertion, cancellation, duration, or offline verification.

Before release:

1. Run `python3 scripts/verify-release.py artifacts/acceptance.json dist/LocalFlow-ARCH-draft.zip`.
2. Verify the latest **CI** and **Security** runs succeeded for that exact SHA,
   including CodeQL's zero-finding check and 100% executable core line coverage.
3. Publish that same tested ZIP, checksum, acceptance JSON and content-free
   measurement reports, and dependency inventory. Do not rebuild during publishing.

Unsigned, unnotarized distribution requires macOS's explicit approval. Never
remove quarantine, disable Gatekeeper, or install a public-repo self-hosted
runner on a CUI workstation. Coverage and scans do not establish speech accuracy
or certify company compliance.
