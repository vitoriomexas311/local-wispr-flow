#!/bin/bash
set -euo pipefail
umask 077
applications_dir="${LOCALFLOW_APPLICATIONS_DIR:-$HOME/Applications}"
trash_dir="${LOCALFLOW_TRASH_DIR:-$HOME/.Trash}"
target="$applications_dir/LocalFlow.app"
[[ -e "$target" ]] || { printf 'LocalFlow is already uninstalled.\n'; exit 0; }
[[ ! -L "$target" && ! -L "$applications_dir" && ! -L "$trash_dir" ]] || { printf 'Refusing symlinked paths.\n' >&2; exit 1; }
identity="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$target/Contents/Info.plist")"
[[ "$identity" == io.github.vitoriomexas311.localflow ]] || { printf 'Unrelated app; refusing removal.\n' >&2; exit 1; }
mkdir -p "$trash_dir"
destination="$trash_dir/LocalFlow-$(date +%s)-$$.app"
mv "$target" "$destination"
printf 'Moved app to %s\nQuit any running LocalFlow instance. Backups and shortcut settings are preserved.\n' "$destination"
