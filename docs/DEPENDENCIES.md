# Dependency inventory

LocalFlow's Swift executable has no third-party Swift packages. It links Apple's
AppKit, Foundation, AVFoundation, Speech, CoreGraphics, Carbon/HIServices, and the
Swift standard libraries supplied with macOS. Apple speech assets are a
proprietary OS dependency and must be provisioned before offline operation.

Application, installer, and test source is in this MIT-licensed repository.
The test driver is a separate executable and is excluded from distribution.
The app does not bundle OpenCode; it is a separately installed test destination.

Build/test requirements: macOS 14+, Swift 6+, and a compatible macOS SDK.
Hosted checks select Xcode 16.2, 16.4, and 26.3. Python 3 is used for development
verification scripts; it is not required to install or run the app. Employees
need only standard macOS tools for the offline installer.

CI-only tools: GitHub Actions checkout and CodeQL (pinned to immutable commits in
the workflows), Gitleaks 8.30.1 (release archive verified with SHA-256), and
ShellCheck from the hosted runner image. Dependabot checks action updates.
The host OS and scanner databases are maintained upstream; their exact versions
are visible in each CI run. No scan is a guarantee of zero vulnerabilities.

## Optional local Whisper runtime

The native helper statically links whisper.cpp and its bundled ggml (MIT), pinned
to commit `927cfce34f31707e17f2bff35c349632fb9e2c3a` (v1.9.4). Source archive SHA-256:
`41b664fee09e79176ac277b5237debec34f8d74af3c7d71f333f1ec67989ecde`.
The build uses CMake 3.20+ and Apple's C/C++ toolchain. No runtime compiler, Python,
package manager, remote inference endpoint, or model account is required.
The committed `Native/Whisper/hardening.patch` modifies this pinned source to
disable dynamic backend loading, widen intermediate arithmetic, and correct
null-checked allocation behavior. The build directory includes the patch SHA-256;
this is a patched dependency, not an unmodified upstream binary.

Optional model: OpenAI Whisper tiny.en, Q5_1 conversion distributed by the
whisper.cpp maintainer (MIT). Revision
`5359861c739e955e79d9a303bcbc70fb988958b1`; file `ggml-tiny.en-q5_1.bin`; SHA-256
`c77c5766f1cef09b6b7d47f21b546cbddd4157886b3b5d6d4f709e91e66c7c2b`.
Only explicit provisioning accesses the model host. Offline import checks the
same hash. See `Native/Whisper/README.md` for the memory-only helper protocol.
