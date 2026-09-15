#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/localflow-setup.XXXXXX")"
trap 'rm -rf "$work"' EXIT
architecture="${ARCHITECTURE:-$(uname -m)}"
ditto -x -k "$root/dist/LocalFlow-$architecture-draft.zip" "$work"
package="$work/LocalFlow-$architecture"
export LOCALFLOW_APPLICATIONS_DIR="$work/Applications"
export LOCALFLOW_MODEL_DIR="$work/Models"
export LOCALFLOW_OPEN_RECORD="$work/opened"
mkdir "$work/bin"
cat > "$work/bin/open" <<'OPEN'
#!/bin/bash
printf '%s' "$1" > "$LOCALFLOW_OPEN_RECORD"
OPEN
chmod +x "$work/bin/open"
export PATH="$work/bin:/usr/bin:/bin:/usr/sbin:/sbin"
/usr/bin/sandbox-exec -p '(version 1)(allow default)(deny network*)' /bin/bash "$package/setup.sh"
test "$(cat "$work/opened")" == "$work/Applications/LocalFlow.app"
cmp "$package/Models/ggml-tiny.en-q5_1.bin" "$work/Models/ggml-tiny.en-q5_1.bin"
codesign --verify --deep --strict "$work/Applications/LocalFlow.app"
/usr/bin/sandbox-exec -p '(version 1)(allow default)(deny network*)' /bin/bash "$package/setup.sh" --offline "$package/Models/ggml-tiny.en-q5_1.bin"
printf 'One-command setup and repeat offline import passed with networking denied.\n'
