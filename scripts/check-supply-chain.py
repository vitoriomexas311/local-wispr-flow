#!/usr/bin/env python3
"""Fail closed on unreviewed runtime dependencies or mutable workflow actions.

These source checks supplement CodeQL and review; they cannot prove privacy.
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
errors = []
for file in (root / ".github/workflows").glob("*.yml"):
    for action in re.findall(r"uses:\s*(\S+)", file.read_text()):
        if not re.fullmatch(r"[A-Za-z0-9_./-]+@[0-9a-f]{40}", action):
            errors.append(f"Mutable or unreviewed action: {file.name}: {action}")
manifest = (root / "Package.swift").read_text()
if re.search(r"\.package\s*\(", manifest):
    errors.append("Runtime dependency added: review inventory and vulnerability policy")
for file in (root / "Sources").rglob("*.swift"):
    # The app has no network transport or clipboard adapter by design.
    if re.search(r"\b(URLSession|URLRequest|NSPasteboard|NWConnection|WKWebView)\b", file.read_text()):
        errors.append(f"Privacy boundary changed: {file.relative_to(root)}")
if errors:
    sys.exit("\n".join(errors))
print("Pinned actions, zero Swift package dependencies, and privacy source guardrails passed.")
