#!/usr/bin/env python3
"""Start an empty OpenCode 1.18.31 manual test session. Never submits a prompt."""
import argparse
import getpass
import json
import os
from pathlib import Path
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("binary", type=Path, help="Locally downloaded OpenCode executable")
parser.add_argument("--version", action="store_true", help="Verify the executable without starting the TUI")
args = parser.parse_args()
binary = args.binary.resolve(strict=True)
if not binary.is_file() or not os.access(binary, os.X_OK):
    parser.error("OpenCode must be an executable file")
managed = [Path("/Library/Application Support/opencode"),
           Path("/Library/Managed Preferences/ai.opencode.managed.plist"),
           Path("/Library/Managed Preferences") / getpass.getuser() / "ai.opencode.managed.plist"]
if any(item.exists() for item in managed):
    parser.error("Managed OpenCode settings are present; use an approved test environment")
root = Path(tempfile.mkdtemp(prefix="localflow-opencode-"))
for name in ("config/opencode", "data", "cache", "state", "home", "workspace", "tmp"):
    (root / name).mkdir(parents=True, exist_ok=True)
environment = {
    "PATH": os.defpath, "TERM": "xterm-256color", "LANG": "en_US.UTF-8",
    "TMPDIR": str(root / "tmp"), "OPENCODE_TEST_HOME": str(root / "home"),
    "OPENCODE_CONFIG_DIR": str(root / "config/opencode"),
    "OPENCODE_CONFIG_CONTENT": json.dumps({"autoupdate": False, "share": "disabled",
        "enabled_providers": [], "permission": {"*": "deny"}, "lsp": False, "formatter": False}),
}
for suffix, directory in (("CONFIG", "config"), ("DATA", "data"), ("CACHE", "cache"), ("STATE", "state")):
    environment[f"XDG_{suffix}_HOME"] = str(root / directory)
for flag in ("DISABLE_PROJECT_CONFIG", "DISABLE_AUTOUPDATE", "DISABLE_MODELS_FETCH",
             "DISABLE_CLAUDE_CODE", "DISABLE_DEFAULT_PLUGINS", "DISABLE_LSP_DOWNLOAD",
             "EXPERIMENTAL_DISABLE_FILEWATCHER", "EXPERIMENTAL_DISABLE_COPY_ON_SELECT"):
    environment[f"OPENCODE_{flag}"] = "true"
print(f"Public-fixture test workspace: {root}", flush=True)
os.chdir(root / "workspace")
arguments = [str(binary)] + (["--version"] if args.version else ["--pure", "--hostname", "127.0.0.1"])
os.execve(binary, arguments, environment)
