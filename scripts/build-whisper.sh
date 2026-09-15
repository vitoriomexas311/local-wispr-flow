#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
architecture="${ARCHITECTURE:-$(uname -m)}"
case "$architecture" in arm64|x86_64) ;; *) exit 2 ;; esac
revision='927cfce34f31707e17f2bff35c349632fb9e2c3a'
checksum='41b664fee09e79176ac277b5237debec34f8d74af3c7d71f333f1ec67989ecde'
vendor="$repo_root/.build/vendor"
mkdir -p "$vendor"
archive="$vendor/whisper.tar.gz"
if [[ ! -f "$archive" ]]; then
    curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --tlsv1.2 "https://codeload.github.com/ggml-org/whisper.cpp/tar.gz/$revision" -o "$archive"
fi
actual="$(shasum -a 256 "$archive" | awk '{print $1}')"
[[ "$actual" == "$checksum" ]] || { printf 'Whisper source checksum mismatch.\n' >&2; exit 1; }
patch_file="$repo_root/Native/Whisper/hardening.patch"
patch_hash="$(shasum -a 256 "$patch_file" | awk '{print $1}')"
source_parent="$vendor/hardened-$patch_hash"
source_dir="$source_parent/whisper.cpp-$revision"
if [[ ! -f "$source_parent/.ready" ]]; then
    mkdir -p "$source_parent"
    tar -xzf "$archive" -C "$source_parent"
    patch --batch --forward -d "$source_dir" -p1 < "$patch_file"
    touch "$source_parent/.ready"
fi
cmake_bin="${CMAKE:-cmake}"
if ! command -v "$cmake_bin" >/dev/null && [[ -x "$repo_root/.build/tools/cmake-env/bin/cmake" ]]; then
    cmake_bin="$repo_root/.build/tools/cmake-env/bin/cmake"
fi
build_dir="$repo_root/.build/whisper-$architecture"
"$cmake_bin" -S "$repo_root/Native/Whisper" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="$architecture" -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DWHISPER_SOURCE="$source_dir"
"$cmake_bin" --build "$build_dir" --target localflow-whisper --parallel 4
