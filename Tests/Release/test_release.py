"""Synthetic gate fixtures only; these never constitute hardware evidence."""
import copy
import hashlib
import importlib.util
import pathlib
import plistlib
import tempfile
import unittest
import zipfile

root = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("release_gate", root / "scripts/verify-release.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class GateTests(unittest.TestCase):
    def test_requires_exact_artifact_and_real_hardware_cases(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = pathlib.Path(directory) / "synthetic.zip"
            commit = "a" * 40
            with zipfile.ZipFile(archive, "w") as bundle:
                bundle.writestr("LocalFlow/SOURCE_COMMIT", commit)
                bundle.writestr("LocalFlow/LocalFlow.app/Contents/Info.plist",
                                plistlib.dumps({"LocalFlowSourceCommit": commit}))
            report = {
                "schema": 1, "sourceCommit": commit,
                "archiveSHA256": hashlib.sha256(archive.read_bytes()).hexdigest(),
                "macOSVersion": "synthetic", "architecture": "synthetic",
                "inputDevice": "synthetic", "outputDevice": "synthetic", "testedAtUTC": "synthetic",
                "applicationVersions": {app: "synthetic" for app in ("TextEdit", "Terminal", "OpenCode", "browser")},
                "cases": [{"id": name, "status": "passed", "input": "actual-microphone", "heldSeconds": 600,
                           "externalNetworking": "unavailable-device-wide", "evidence": "synthetic gate test"}
                          for name in sorted(gate.REQUIRED)]
            }
            gate.verify(report, archive, commit)
            for key, value in [("schema", 0), ("sourceCommit", "b" * 40), ("archiveSHA256", "0" * 64),
                               ("macOSVersion", ""), ("applicationVersions", {}), ("cases", [])]:
                with self.subTest(key=key), self.assertRaises(ValueError):
                    gate.verify(dict(report, **{key: value}), archive, commit)
            for key, value in [("status", "blocked"), ("input", "injected-audio"), ("evidence", "")]:
                modified = copy.deepcopy(report)
                modified["cases"][0][key] = value
                with self.subTest(key=key), self.assertRaises(ValueError):
                    gate.verify(modified, archive, commit)
            for name, key, value in [("offline.cold-start", "externalNetworking", "app-only-sandbox"),
                                     ("duration.ten-minute-hold", "heldSeconds", 599)]:
                modified = copy.deepcopy(report)
                next(case for case in modified["cases"] if case["id"] == name)[key] = value
                with self.subTest(name=name), self.assertRaises(ValueError):
                    gate.verify(modified, archive, commit)
            modified = copy.deepcopy(report)
            modified["cases"].append(modified["cases"][0])
            with self.assertRaises(ValueError):
                gate.verify(modified, archive, commit)
            with zipfile.ZipFile(archive, "a") as bundle:
                bundle.writestr("changed.txt", "different bytes")
            with self.assertRaises(ValueError):
                gate.verify(report, archive, commit)


if __name__ == "__main__":
    unittest.main()
