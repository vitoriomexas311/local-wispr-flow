#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
variant="${LOCALFLOW_BUILD_VARIANT:-app}"
case "$variant" in app|candidate-app) ;; *) exit 2 ;; esac
for architecture in arm64 x86_64; do
    ARCHITECTURE="$architecture" "$root/scripts/build-app.sh"
done
bundle="$root/.build/$variant-universal/LocalFlow.app"
if pgrep -f "$bundle/Contents/MacOS/LocalFlow" >/dev/null; then
    printf 'Quit the universal development app before rebuilding it.\n' >&2
    exit 1
fi
mkdir -p "$(dirname "$bundle")"
ditto "$root/.build/$variant-arm64/LocalFlow.app" "$bundle"
for executable in MacOS/LocalFlow Helpers/localflow-whisper; do
    lipo -create "$root/.build/$variant-arm64/LocalFlow.app/Contents/$executable" \
        "$root/.build/$variant-x86_64/LocalFlow.app/Contents/$executable" -output "$bundle/Contents/$executable"
    lipo "$bundle/Contents/$executable" -verify_arch arm64 x86_64
done
codesign --force --sign - --options runtime "$bundle/Contents/Helpers/localflow-whisper"
codesign --force --sign - --options runtime --entitlements "$root/Resources/LocalFlow.entitlements" "$bundle"
codesign --verify --deep --strict "$bundle"
printf 'Universal app: %s\n' "$bundle"
