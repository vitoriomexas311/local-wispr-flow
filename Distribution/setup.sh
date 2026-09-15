#!/bin/bash
# One-command setup. Bundled/imported models need no network; downloads are explicit.
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
model=''
case "${1:-}" in
    '') [[ $# -eq 0 ]] || exit 2 ;;
    --offline) [[ $# -eq 2 ]] || { printf 'Usage: bash setup.sh [--offline MODEL_FILE]\n' >&2; exit 2; }; model="$2" ;;
    *) printf 'Usage: bash setup.sh [--offline MODEL_FILE]\n' >&2; exit 2 ;;
esac
if [[ -z "$model" && -f "$root/Models/ggml-tiny.en-q5_1.bin" ]]; then
    model="$root/Models/ggml-tiny.en-q5_1.bin"
fi
# Verify the archive's manifest before executing its provisioning script.
(cd "$root" && shasum -a 256 -c CHECKSUMS.sha256)
bash "$root/install.sh"
if [[ -n "$model" ]]; then
    bash "$root/download-model.sh" "$model"
else
    printf 'Downloading the verified 32 MB Whisper model once. Future dictation is offline.\n'
    bash "$root/download-model.sh"
fi
printf '\nSetup complete. Open LocalFlow and grant the three macOS permissions.\n'
open "${LOCALFLOW_APPLICATIONS_DIR:-$HOME/Applications}/LocalFlow.app"
