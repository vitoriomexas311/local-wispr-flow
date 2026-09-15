#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
configuration="${CONFIGURATION:-release}"
architecture="${ARCHITECTURE:-$(uname -m)}"
case "$configuration" in debug|release) ;; *) exit 2 ;; esac
case "$architecture" in arm64|x86_64) ;; *) exit 2 ;; esac
scripts/local-swift.sh build --product LocalFlow -c "$configuration" --arch "$architecture"
binary_dir="$(scripts/local-swift.sh build -c "$configuration" --arch "$architecture" --show-bin-path)"
variant="${LOCALFLOW_BUILD_VARIANT:-app}"
case "$variant" in app|candidate-app) ;; *) exit 2 ;; esac
bundle="$repo_root/.build/$variant-$architecture/LocalFlow.app"
if /usr/bin/pgrep -f "$bundle/Contents/MacOS/LocalFlow" >/dev/null; then
    printf 'Quit LocalFlow before replacing its signed development bundle.\n' >&2
    exit 1
fi
ARCHITECTURE="$architecture" scripts/build-whisper.sh
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources" "$bundle/Contents/Helpers"
cp "$repo_root/.build/whisper-$architecture/localflow-whisper" "$bundle/Contents/Helpers/localflow-whisper"
codesign --force --sign - --options runtime "$bundle/Contents/Helpers/localflow-whisper"
cp Distribution/download-model.sh Distribution/WHISPER-RUNTIME-LICENSE.txt Distribution/WHISPER-MODEL-LICENSE.txt "$bundle/Contents/Resources/"
cp "$binary_dir/LocalFlow" "$bundle/Contents/MacOS/LocalFlow"
# The isolated mixed-CLT workaround also supports Swift Testing. Its development
# framework search path must not be inherited by the distributed application.
development_frameworks='/Library/Developer/CommandLineTools/Library/Developer/Frameworks'
if otool -l "$bundle/Contents/MacOS/LocalFlow" | awk -v expected="$development_frameworks" '$1 == "path" && $2 == expected {found=1} END {exit !found}'; then
    install_name_tool -delete_rpath "$development_frameworks" "$bundle/Contents/MacOS/LocalFlow"
fi
cp Resources/Info.plist "$bundle/Contents/Info.plist"
cp Resources/LocalFlow.icns "$bundle/Contents/Resources/LocalFlow.icns"
source_commit="$(git rev-parse HEAD)"
if [[ -n "$(git status --porcelain)" ]]; then source_commit="$source_commit-dirty"; fi
/usr/libexec/PlistBuddy -c "Add :LocalFlowSourceCommit string $source_commit" "$bundle/Contents/Info.plist"
codesign --force --sign - --options runtime --entitlements Resources/LocalFlow.entitlements "$bundle"
codesign --verify --strict "$bundle"
printf '%s\n' "$bundle"
