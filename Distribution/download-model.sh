#!/bin/bash
# Explicit provisioning only. Dictation never invokes this script.
set -euo pipefail
umask 077
model_dir="${LOCALFLOW_MODEL_DIR:-$HOME/Library/Application Support/LocalFlow/Models}"
model_name='ggml-tiny.en-q5_1.bin'
expected='c77c5766f1cef09b6b7d47f21b546cbddd4157886b3b5d6d4f709e91e66c7c2b'
model_url='https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-tiny.en-q5_1.bin'
if [[ $# -gt 1 ]]; then printf 'usage: bash download-model.sh [LOCAL_MODEL_FILE]\n' >&2; exit 2; fi
mkdir -p "$model_dir"
[[ ! -L "$model_dir" && ! -L "$model_dir/$model_name" ]] || { printf 'Refusing symlink model destination.\n' >&2; exit 1; }
staged="$(mktemp "$model_dir/.tiny.XXXXXX")"
trap 'rm -f "$staged"' EXIT
if [[ $# -eq 1 ]]; then
    [[ -f "$1" && ! -L "$1" ]] || { printf 'Choose a regular model file.\n' >&2; exit 1; }
    cp "$1" "$staged"
else
    /usr/bin/curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --tlsv1.2 --connect-timeout 20 --max-time 600 "$model_url" -o "$staged"
fi
actual="$(/usr/bin/shasum -a 256 "$staged" | /usr/bin/awk '{print $1}')"
[[ "$actual" == "$expected" ]] || { printf 'Model checksum failed; existing model preserved.\n' >&2; exit 1; }
chmod 600 "$staged"
mv -f "$staged" "$model_dir/$model_name"
printf 'Whisper Tiny English installed and verified. Dictation can now run offline.\n'
