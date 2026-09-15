#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
model="${1:?Pass the verified model file}"
work="$(mktemp -d "${TMPDIR:-/tmp}/localflow-model-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export LOCALFLOW_MODEL_DIR="$work/Models"
# Offline import must work with network access denied.
/usr/bin/sandbox-exec -p '(version 1)(allow default)(deny network*)' /bin/bash "$repo_root/Distribution/download-model.sh" "$model"
installed="$LOCALFLOW_MODEL_DIR/ggml-tiny.en-q5_1.bin"
before="$(shasum -a 256 "$installed")"
printf 'invalid model\n' > "$work/invalid.bin"
if bash "$repo_root/Distribution/download-model.sh" "$work/invalid.bin"; then
    printf 'Invalid model accepted\n' >&2; exit 1
fi
[[ "$(shasum -a 256 "$installed")" == "$before" ]]
rm "$installed"
ln -s "$model" "$installed"
if bash "$repo_root/Distribution/download-model.sh" "$model"; then
    printf 'Symlink model destination accepted\n' >&2; exit 1
fi
printf 'Offline model import, tamper preservation, and symlink rejection passed.\n'
