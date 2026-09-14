#!/usr/bin/env python3
"""Validate external hardware evidence against the exact tested archive and SHA."""
import hashlib
import json
import pathlib
import plistlib
import re
import subprocess
import sys
import zipfile

REQUIRED = {
    "textedit.microphone", "textedit.selection", "browser.microphone",
    "terminal.opencode.microphone", "speech.punctuation", "speech.corrections",
    "speech.repeated-words", "speech.silence", "safety.cancel", "safety.focus-change",
    "safety.intervening-input", "safety.modifier-release", "safety.password-field",
    "safety.secure-input", "safety.no-submit", "safety.clipboard-unchanged",
    "duration.ten-minute-hold", "offline.cold-start", "offline.repeated-dictation"
}


def verify(report, archive, commit):
    if report.get("schema") != 1 or not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Unsupported evidence schema or invalid source commit")
    if report.get("sourceCommit") != commit:
        raise ValueError("Acceptance was not run on this source commit")
    if report.get("archiveSHA256") != hashlib.sha256(archive.read_bytes()).hexdigest():
        raise ValueError("Archive differs from the tested artifact")
    with zipfile.ZipFile(archive) as bundle:
        commits = [name for name in bundle.namelist() if name.endswith("/SOURCE_COMMIT")]
        plists = [name for name in bundle.namelist() if name.endswith("/LocalFlow.app/Contents/Info.plist")]
        if len(commits) != 1 or len(plists) != 1:
            raise ValueError("Missing or ambiguous app provenance")
        if bundle.read(commits[0]).decode().strip() != commit:
            raise ValueError("Package provenance differs from source commit")
        if plistlib.loads(bundle.read(plists[0])).get("LocalFlowSourceCommit") != commit:
            raise ValueError("App provenance differs from source commit")
    for key in ("macOSVersion", "architecture", "inputDevice", "outputDevice", "testedAtUTC"):
        if not isinstance(report.get(key), str) or not report[key].strip():
            raise ValueError(f"Missing measured environment: {key}")
    apps = report.get("applicationVersions", {})
    if not all(isinstance(apps.get(app), str) and apps[app] for app in ("TextEdit", "Terminal", "OpenCode", "browser")):
        raise ValueError("Required application versions are missing")
    cases = report.get("cases", [])
    names = [case.get("id") for case in cases]
    if len(set(names)) != len(names) or not REQUIRED.issubset(names):
        raise ValueError("Missing or duplicate acceptance cases")
    for case in cases:
        if case["id"] not in REQUIRED:
            continue
        if case.get("status") != "passed" or case.get("input") != "actual-microphone":
            raise ValueError(f"Hardware gate did not pass: {case['id']}")
        if not isinstance(case.get("evidence"), str) or not case["evidence"].strip():
            raise ValueError(f"Evidence reference missing: {case['id']}")
        if case["id"].startswith("offline.") and case.get("externalNetworking") != "unavailable-device-wide":
            raise ValueError("Offline evidence must isolate the entire device")
        if case["id"] == "duration.ten-minute-hold" and case.get("heldSeconds", 0) < 600:
            raise ValueError("Ten-minute microphone hold was not measured")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: verify-release.py ACCEPTANCE.json TESTED_ARCHIVE.zip")
    try:
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
        if subprocess.check_output(["git", "status", "--porcelain"], text=True).strip():
            raise ValueError("Commit all source changes before release verification")
        verify(json.loads(pathlib.Path(sys.argv[1]).read_text()), pathlib.Path(sys.argv[2]), head)
    except (ValueError, OSError, KeyError, zipfile.BadZipFile) as error:
        sys.exit(str(error))
    print("Exact-artifact hardware evidence passed. GitHub CI and Security must also pass for this SHA.")
