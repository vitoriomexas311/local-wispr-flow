#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
architecture="${ARCHITECTURE:-$(uname -m)}"
work="$(mktemp -d "${TMPDIR:-/tmp}/localflow-installer.XXXXXX")"
trap 'rm -rf "$work"' EXIT
ditto -x -k "$repo_root/dist/LocalFlow-$architecture-draft.zip" "$work"
package="$work/LocalFlow-$architecture"
export LOCALFLOW_APPLICATIONS_DIR="$work/Applications"
export LOCALFLOW_TRASH_DIR="$work/Trash"
bash "$package/install.sh"
test -x "$LOCALFLOW_APPLICATIONS_DIR/LocalFlow.app/Contents/MacOS/LocalFlow"
codesign --verify --strict "$LOCALFLOW_APPLICATIONS_DIR/LocalFlow.app"
bash "$package/install.sh"
test -f "$LOCALFLOW_APPLICATIONS_DIR/LocalFlow Backups/previous"
bash "$package/install.sh" --rollback
codesign --verify --strict "$LOCALFLOW_APPLICATIONS_DIR/LocalFlow.app"
bash "$package/uninstall.sh"
test ! -e "$LOCALFLOW_APPLICATIONS_DIR/LocalFlow.app"
bash "$package/uninstall.sh"
# A modified ZIP must fail before writing an app.
printf 'tampered\n' >> "$package/SETUP.txt"
if bash "$package/install.sh"; then printf 'Tampered package accepted\n' >&2; exit 1; fi
test ! -e "$LOCALFLOW_APPLICATIONS_DIR/LocalFlow.app"
# Installation paths must not redirect writes through a symlink.
ln -s "$work/Trash" "$LOCALFLOW_APPLICATIONS_DIR/LocalFlow.app"
if bash "$package/install.sh"; then printf 'Symlink accepted\n' >&2; exit 1; fi
printf 'Installer lifecycle, rollback, tampering, and symlink checks passed.\n'
