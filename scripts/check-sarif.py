#!/usr/bin/env python3
import json
import pathlib
import sys

files = list(pathlib.Path(sys.argv[1]).rglob("*.sarif"))
if not files:
    sys.exit("CodeQL produced no SARIF report")
count = 0
for file in files:
    for run in json.loads(file.read_text())["runs"]:
        count += len(run.get("results", []))
print(f"CodeQL findings: {count}")
sys.exit(1 if count else 0)
