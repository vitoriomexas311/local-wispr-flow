# Local hardware driver

`scripts/build-harness.sh` builds a separate, undistributed native test app.
Authorize its Accessibility/event-posting permission with `--authorize` using
LaunchServices. Never run it against a document containing sensitive data.

Create a new TextEdit document containing exactly `LOCALFLOW_TEST `, or
`LOCALFLOW_TEST replace me` for the selection case. Run the packaged LocalFlow
app with its normal permissions. Generate public fixture audio locally:

```sh
mkdir -p .build/evidence
fixture_dir="$(mktemp -d /tmp/localflow-public-fixtures.XXXXXX)"
cp Tests/Fixtures/short.txt "$fixture_dir/short.txt"
say -v 'Eddy (English (US))' -r 145 -f "$fixture_dir/short.txt" -o "$fixture_dir/short.aiff"
open -g -n -W --stdout "$PWD/.build/evidence/microphone.json" \
  --stderr "$PWD/.build/evidence/microphone.stderr" .build/LocalFlowHarness.app \
  --args --dictate "$fixture_dir/short.aiff" \
  "$fixture_dir/short.txt" com.apple.TextEdit normal
```

Cases: `normal`, `selection`, `cancel`. The driver checks a test marker, activates
the explicit destination, holds the production shortcut using native events,
and plays synthetic speech through the speakers. It reads the saved LocalFlow
shortcut setting and reports the chosen shortcut, including Shift–Tab. LocalFlow must capture the
real microphone. This differs from LocalFlow's injected-audio `--verify-speech`
probe. Record both input and output devices and ambient conditions separately.
Keep LocalFlow's Setup window open in the background: the driver verifies its
fixed recording and completion/cancellation labels. An unchanged field with no
observed recording is a failure, including in the cancellation case.
Fixtures may be up to 600 seconds. Reports include the measured shortcut hold
duration so the full-duration gate can be checked. A temporary fixture directory
avoids requesting access to Documents; use public synthetic audio only.

The driver never logs field contents or clipboard contents. JSON reports contain
counts, timings, booleans, and enumerated reasons only. `open` does not propagate
the app exit status: inspect the last JSON report's `status`. Use a new report
path each run because LaunchServices appends stdout. Word error rate <=15% is
the short-fixture threshold, not a promise for arbitrary speech.

This harness compiling does not mean hardware acceptance passes. Current actual
results and outstanding gates are in `docs/STATUS.md`. Never upload raw OS logs
or audio recorded on a CUI workstation to hosted CI.
