#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
architecture="${ARCHITECTURE:-$(uname -m)}"
case "$architecture" in arm64|x86_64) ;; *) exit 2 ;; esac
source_app="$repo_root/.build/app-$architecture/LocalFlow.app"
[[ -d "$source_app" ]] || { printf 'Build the app first.\n' >&2; exit 1; }
mkdir -p dist
stage="$(mktemp -d "$repo_root/dist/.package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
payload="$stage/LocalFlow-$architecture"
mkdir "$payload"
ditto "$source_app" "$payload/LocalFlow.app"
cp Distribution/install.sh Distribution/uninstall.sh Distribution/SETUP.txt LICENSE "$payload/"
cp docs/DEPENDENCIES.md "$payload/DEPENDENCIES.md"
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
