# Manual Terminal/OpenCode acceptance

Use public synthetic text and speech only. Start the verified OpenCode 1.18.31
executable in a new Terminal.app window:

```sh
python3 Tests/Manual/start-opencode.py /absolute/path/to/opencode
```

The launcher creates an empty temporary workspace, isolated XDG directories and
OpenCode test home, and a minimal environment with no inherited provider keys.
It disables sharing, updates, remote model-list fetches, external plugins, and
providers. It does not alter user settings or override managed company settings.
Temporary test data is retained at the printed path; delete that test directory
after recording the content-free results you need.

Manually type `LOCALFLOW_TEST ` into OpenCode's input, hold LocalFlow's shortcut,
speak the public short fixture, and release all shortcut keys. Check the inserted
text, selection/caret behavior, and that no prompt was submitted. Do not press
Return. Repeat the safety cases specified in `docs/ACCEPTANCE.md`, recording the
actual app versions, source SHA, artifact hash, accuracy, latency, and results.

Where computer-use access to Terminal.app is prohibited, the owner must perform
the interaction. Do not use another automation API to work around that restriction.
Preparing this workspace or observing a running process does not pass acceptance.

Configuration isolation was checked against the tagged source:
[global paths](https://github.com/anomalyco/opencode/blob/v1.18.31/packages/core/src/global.ts),
[config directories](https://github.com/anomalyco/opencode/blob/v1.18.31/packages/opencode/src/config/paths.ts),
[auth storage](https://github.com/anomalyco/opencode/blob/v1.18.31/packages/opencode/src/auth/index.ts).
The test-home override is version-specific; recheck these paths when changing the
OpenCode version. These test controls do not change LocalFlow's downstream privacy
boundary or certify OpenCode for CUI.
