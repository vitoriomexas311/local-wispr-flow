# Local Whisper helper

Built from whisper.cpp v1.9.4, commit
`927cfce34f31707e17f2bff35c349632fb9e2c3a`, using the archive SHA-256 in
`scripts/build-whisper.sh`. The source archive is downloaded only at developer
build time. The helper statically links whisper.cpp/ggml and uses Apple's
Accelerate framework, with GPU, server, and OpenMP support disabled.

`hardening.patch` is applied to a fresh, checksum-verified upstream archive in a
directory keyed by the patch hash. It promotes intermediate arithmetic before
multiplication, uses nonthrowing allocations where upstream checks for null,
and removes dynamic backend loading from the macOS runtime. These are source
fixes; CodeQL still scans the dependency and rejects every reported finding.

Each invocation reads one bounded request from stdin: a little-endian uint32
sample count followed by mono Float32 samples at 16 kHz. A request contains at
most 25 seconds. Stdout contains JSON segments with text and second-based start
and end timestamps. Exit codes 2–5 indicate argument, input, model, and inference
failure, respectively. No audio/transcript files are created. Library logging is
disabled. The app must discard results from cancelled generations and terminate
workers on cancellation or timeout.

The optional model is English-only Whisper tiny.en Q5_1 (32.2 MB), pinned by
revision and SHA-256 in `Distribution/download-model.sh`. Run that script to
provision it, or pass a local model file to import it without networking. The
model is stored outside the signed application, so provisioning does not replace
the app or invalidate its permissions.

The helper accepts only the installed model path under the current account's
home directory (queried from macOS, not an environment override). It refuses a
symlink at the model file, requires the exact file size, then hashes the complete
in-memory bytes before passing those same bytes to Whisper. Changed model files
cannot exploit a gap between the GUI readiness check and native parsing.

Developer build: install CMake 3.20+ and run `scripts/build-whisper.sh`.
Employees use the prebuilt helper; no CMake or Python is needed at runtime.
`Tests/Whisper/test_worker.py` tests malformed input, silence, and a public
injected-audio fixture with the helper's network access denied. It is not a
microphone or complete-device offline acceptance test.
