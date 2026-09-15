#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
architecture="${ARCHITECTURE:-$(uname -m)}"
case "$architecture" in arm64|x86_64|universal) ;; *) exit 2 ;; esac
variant="${LOCALFLOW_BUILD_VARIANT:-app}"
case "$variant" in app|candidate-app) ;; *) exit 2 ;; esac
source_app="$repo_root/.build/$variant-$architecture/LocalFlow.app"
[[ -d "$source_app" ]] || { printf 'Build the app first.\n' >&2; exit 1; }
mkdir -p dist
stage="$(mktemp -d "$repo_root/dist/.package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
payload="$stage/LocalFlow-$architecture"
mkdir "$payload"
ditto "$source_app" "$payload/LocalFlow.app"
cp Distribution/setup.sh Distribution/install.sh Distribution/uninstall.sh Distribution/download-model.sh Distribution/WHISPER-RUNTIME-LICENSE.txt Distribution/WHISPER-MODEL-LICENSE.txt Distribution/SETUP.txt LICENSE "$payload/"
cp docs/DEPENDENCIES.md "$payload/DEPENDENCIES.md"
if [[ "${INCLUDE_MODEL:-0}" == 1 ]]; then
    model="${LOCALFLOW_MODEL_FILE:-$HOME/Library/Application Support/LocalFlow/Models/ggml-tiny.en-q5_1.bin}"
    expected='c77c5766f1cef09b6b7d47f21b546cbddd4157886b3b5d6d4f709e91e66c7c2b'
    [[ -f "$model" && ! -L "$model" && "$(shasum -a 256 "$model" | awk '{print $1}')" == "$expected" ]] || { printf 'A verified model is required for the offline ZIP.\n' >&2; exit 1; }
    mkdir "$payload/Models"
    cp "$model" "$payload/Models/ggml-tiny.en-q5_1.bin"
fi
printf '%s\n' "$architecture" > "$payload/ARCHITECTURE"
/usr/libexec/PlistBuddy -c 'Print :LocalFlowSourceCommit' "$source_app/Contents/Info.plist" > "$payload/SOURCE_COMMIT"
printf '%s\n' 'Development candidate unless accompanied by passing hardware evidence for its exact ZIP SHA-256 and SOURCE_COMMIT. Check the matching GitHub release validation before deployment.' > "$payload/VALIDATION.txt"
python3 - "$payload" <<'PY'
import hashlib
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
lines = []
for file in sorted(root.rglob('*')):
    if file.is_symlink():
        sys.exit('Unexpected symlink in package')
    if file.is_file():
        lines.append(f'{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.relative_to(root)}\n')
(root / 'CHECKSUMS.sha256').write_text(''.join(lines))
PY
(cd "$payload" && shasum -a 256 -c CHECKSUMS.sha256)
codesign --verify --strict "$payload/LocalFlow.app"
archive="$repo_root/dist/LocalFlow-$architecture-draft.zip"
ditto -c -k --keepParent "$payload" "$archive"
(cd "$repo_root/dist" && shasum -a 256 "LocalFlow-$architecture-draft.zip" > "LocalFlow-$architecture-draft.zip.sha256")
printf 'Local draft package: %s\n' "$archive"
