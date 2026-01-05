#!/bin/bash
# Isolated workaround for overlapping Apple CLT installations. No system edits.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
compiler="$(xcrun --find swiftc)"
clt_root="/Library/Developer/CommandLineTools"
if [[ "$compiler" != "$clt_root/usr/bin/swiftc" ]] || [[ ! -f "$clt_root/usr/include/swift/module.modulemap" ]]; then
    exec swift "$@"
fi
shim_root="$repo_root/.build/local-toolchain"
mkdir -p "$shim_root"
python3 - "$shim_root" "$clt_root" "$compiler" <<'PY'
import json, pathlib, shlex, sys
root, clt, compiler = map(pathlib.Path, sys.argv[1:])
empty = root / 'empty.modulemap'
empty.write_text('')
entries = [{'type': 'file', 'name': str(clt / 'usr/include/swift/module.modulemap'),
            'external-contents': str(empty)}]
modules = clt / 'usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule'
for arch in ('arm64', 'x86_64'):
    public = modules / f'{arch}-apple-macos.swiftinterface'
    private = modules / f'{arch}-apple-macos.private.swiftinterface'
    if public.exists() and private.exists():
        entries.append({'type': 'file', 'name': str(private), 'external-contents': str(public)})
overlay = root / 'overlay.json'
overlay.write_text(json.dumps({'version': 0, 'roots': entries}))
frameworks = clt / 'Library/Developer/Frameworks'
args = ['-vfsoverlay', str(overlay), '-module-cache-path', str(root / 'cache'),
        '-F', str(frameworks), '-Xlinker', '-rpath', '-Xlinker', str(frameworks)]
wrapper = root / 'swiftc'
wrapper.write_text('#!/bin/bash\nexec ' + shlex.quote(str(compiler)) + ' "$@" ' + shlex.join(args) + '\n')
wrapper.chmod(0o755)
for tool in ('llvm-profdata', 'llvm-cov'):
    link = root / tool
    if not link.exists():
        link.symlink_to(compiler.parent / tool)
PY
export SWIFT_EXEC="$shim_root/swiftc"
exec swift "$@"
