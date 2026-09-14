#!/bin/bash
# Offline user installation. Does not download, elevate, or alter quarantine.
set -euo pipefail
umask 077
package_root="$(cd "$(dirname "$0")" && pwd)"
applications_dir="${LOCALFLOW_APPLICATIONS_DIR:-$HOME/Applications}"
target="$applications_dir/LocalFlow.app"
backups="$applications_dir/LocalFlow Backups"
marker="$backups/previous"
bundle_id="io.github.vitoriomexas311.localflow"
identity() { /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist"; }
fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || fail 'LocalFlow requires macOS.'
[[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ]] || fail 'LocalFlow requires macOS 14 or newer.'
if /usr/bin/pgrep -x LocalFlow >/dev/null; then fail 'Quit LocalFlow before installing or rolling back.'; fi
[[ ! -L "$applications_dir" && ! -L "$target" && ! -L "$backups" && ! -L "$marker" ]] || fail 'Refusing symlinked installation paths.'
mkdir -p "$applications_dir" "$backups"
if [[ "${1:-}" == --rollback ]]; then
    [[ -f "$marker" ]] || fail 'No previous installation is available.'
    previous_name="$(cat "$marker")"
    [[ "$previous_name" =~ ^LocalFlow-[0-9]+-[0-9]+\.app$ ]] || fail 'Invalid rollback record.'
    source_app="$backups/$previous_name"
else
    [[ $# -eq 0 ]] || fail 'Usage: bash install.sh [--rollback]'
    cd "$package_root"
    [[ "$(cat ARCHITECTURE)" == "$(uname -m)" ]] || fail 'Download the ZIP matching this Mac architecture.'
    /usr/bin/shasum -a 256 -c CHECKSUMS.sha256 || fail 'Package checksum verification failed.'
    source_app="$package_root/LocalFlow.app"
fi
[[ -d "$source_app" && ! -L "$source_app" && "$(identity "$source_app")" == "$bundle_id" ]] || fail 'Not a LocalFlow app bundle.'
/usr/bin/codesign --verify --strict "$source_app" || fail 'App integrity verification failed.'
if [[ -e "$target" ]]; then
    [[ -d "$target" && "$(identity "$target")" == "$bundle_id" ]] || fail 'An unrelated LocalFlow.app already exists; installation refused.'
fi
stage="$(mktemp -d "$applications_dir/.localflow-install.XXXXXX")"
backup=''
installed=false
cleanup() {
    local result=$?
    if [[ "$installed" == false && -n "$backup" && ! -e "$target" ]]; then mv "$backup" "$target"; fi
    rm -rf "$stage"
    exit "$result"
}
trap cleanup EXIT
/usr/bin/ditto "$source_app" "$stage/LocalFlow.app"
/usr/bin/codesign --verify --strict "$stage/LocalFlow.app"
if [[ -e "$target" ]]; then
    backup="$backups/LocalFlow-$(date +%s)-$$.app"
    mv "$target" "$backup"
fi
mv "$stage/LocalFlow.app" "$target"
installed=true
if [[ -n "$backup" ]]; then basename "$backup" > "$marker"; fi
printf 'Installed: %s\nOpen LocalFlow in Finder, approve it in macOS, and complete Setup.\n' "$target"
printf 'Unsigned pilot: macOS may require Privacy & Security → Open Anyway.\n'
