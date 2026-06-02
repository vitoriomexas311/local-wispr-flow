#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
scripts/local-swift.sh build --product LocalFlowHarness
binary_dir="$(scripts/local-swift.sh build --show-bin-path)"
bundle="$repo_root/.build/LocalFlowHarness.app"
mkdir -p "$bundle/Contents/MacOS"
cp "$binary_dir/LocalFlowHarness" "$bundle/Contents/MacOS/LocalFlowHarness"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LocalFlowHarness</string>
<key>CFBundleIdentifier</key><string>io.github.vitoriomexas311.localflow.harness</string>
<key>CFBundleName</key><string>LocalFlow Harness</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSBackgroundOnly</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$bundle"
printf '%s\n' "$bundle"
