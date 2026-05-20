#!/usr/bin/env python3
"""Require measured executable lines for every core source, with no exclusions."""
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parent.parent
if len(sys.argv) != 2:
    sys.exit("usage: check-coverage.py LLVM_COV_EXPORT.json")
expected = {p.name for p in (root / "Sources/DictationCore").glob("*.swift")}
measured = {}
for unit in json.loads(pathlib.Path(sys.argv[1]).read_text())["data"]:
    for source in unit["files"]:
        name = pathlib.Path(source["filename"])
        if name.parent.name == "DictationCore" and name.parent.parent.name == "Sources":
            if name.name in measured:
                sys.exit(f"duplicate coverage record: {name.name}")
            measured[name.name] = source["summary"]["lines"]
if not expected or expected != set(measured):
    sys.exit(f"coverage file mismatch: expected {sorted(expected)}, got {sorted(measured)}")
passed = True
for name, lines in sorted(measured.items()):
    valid = lines["count"] > 0 and lines["count"] == lines["covered"]
    passed &= valid
    print(f"{name}: {lines['covered']}/{lines['count']} executable lines")
sys.exit(0 if passed else 1)
