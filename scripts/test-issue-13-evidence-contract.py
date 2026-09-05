#!/usr/bin/env python3
"""Focused adversarial tests for the Issue 13 evidence contract validator."""

from __future__ import annotations

import base64
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from copy import deepcopy
from pathlib import Path


SCRIPT = Path(__file__).with_name("validate-issue-13-evidence.py")
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("evidence_contract", SCRIPT)
assert SPEC and SPEC.loader
evidence_contract = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(evidence_contract)

PNG_1X1 = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
)


class EvidenceContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.repo_root = Path(self.temporary_directory.name)
        (self.repo_root / "evidence").mkdir()
        (self.repo_root / "GuideCompanionUITests").mkdir()
        (self.repo_root / "GuideCompanionUITests" / "GoldenGuideUITests.swift").write_text(
            "final class GoldenGuideUITests {\n"
            "  func test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure() {}\n"
            "}\n"
        )
        (self.repo_root / "GuideCompanionGolden.xctestplan").write_text(
            json.dumps(
                {
                    "configurations": [{"name": "Golden UI", "options": {}}],
                    "testTargets": [{"target": {"name": "GuideCompanionUITests"}}],
                }
            )
        )
        result_archive = self.repo_root / "evidence" / "fixture.xcresult.zip"
        with zipfile.ZipFile(result_archive, "w") as archive:
            archive.writestr("fixture.xcresult/Info.plist", "fixture")
            archive.writestr("fixture.xcresult/Data/data", "fixture")
        (self.repo_root / "evidence" / "fixture-xcode-report.png").write_bytes(PNG_1X1)
        (self.repo_root / "evidence" / "notes.txt").write_text("not result evidence")
        self.git("init", "-q")
        self.git("config", "user.name", "Evidence Test")
        self.git("config", "user.email", "evidence@example.invalid")
        self.git("add", "-f", ".")
        self.git("-c", "commit.gpgSign=false", "commit", "-qm", "fixture")
        self.tested_commit = self.git("rev-parse", "HEAD").stdout.strip()
        self.tracked_paths = set(self.git("ls-files").stdout.splitlines())
        self.complete = {
            "schemaVersion": 2,
            "issue": 13,
            "proofRole": "focused-pass",
            "evidenceStatus": "complete",
            "missingRequirements": [],
            "testId": "GT-UF12-001",
            "xcodeTestIdentifier": "GoldenGuideUITests/test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure()",
            "testedCommit": self.tested_commit,
            "testPlan": "GuideCompanionGolden",
            "testPlanConfiguration": "Golden UI",
            "destination": {
                "platform": "macOS",
                "architecture": "arm64",
                "osVersion": "26.5.2",
                "osBuildNumber": "25F84",
            },
            "result": {
                "status": "passed",
                "executed": 1,
                "passed": 1,
                "failed": 0,
                "skipped": 0,
                "durationSeconds": 1.25,
            },
            "failures": [],
            "artifacts": {
                "resultEvidence": ["evidence/fixture.xcresult.zip"],
                "reportScreenshots": ["evidence/fixture-xcode-report.png"],
                "secondary": [],
                "unavailable": [],
            },
            "cleanup": {
                "measured": {
                    **{
                        field: 0
                        for field in evidence_contract.INTEGER_CLEANUP_DIMENSIONS
                    },
                    **{
                        field: False
                        for field in evidence_contract.BOOLEAN_CLEANUP_DIMENSIONS
                    },
                },
                "unverifiedDimensions": [],
            },
        }

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def git(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["git", *arguments],
            cwd=self.repo_root,
            check=True,
            capture_output=True,
            text=True,
        )

    def validate(self, document):
        return evidence_contract.validate_document(
            document,
            repo_root=self.repo_root,
            tracked_paths=self.tracked_paths,
        )

    def test_manufactured_primary_files_cannot_make_a_complete_proof(self) -> None:
        errors = self.validate(self.complete)
        self.assertIn(
            "artifacts.resultEvidence is not an inspectable xcresult", errors
        )
        self.assertIn(
            "artifacts.reportScreenshots is not a correlated Xcode report image",
            errors,
        )

    def test_passed_status_rejects_failed_count(self) -> None:
        document = deepcopy(self.complete)
        document["result"].update(executed=2, passed=1, failed=1)
        document["failures"] = [{"summary": "unexpected"}]
        self.assertIn("passed result must have failed=0", self.validate(document))

    def test_failed_as_injected_requires_a_failure(self) -> None:
        document = deepcopy(self.complete)
        document["evidenceStatus"] = "red"
        document["proofRole"] = "red-capability"
        document["result"].update(status="failed-as-injected", passed=0, failed=0)
        self.assertIn(
            "failed-as-injected result must have failed>0", self.validate(document)
        )

    def test_unsafe_measured_cleanup_is_rejected_for_every_status(self) -> None:
        document = deepcopy(self.complete)
        document["cleanup"]["measured"].update(
            serpyAndUITestProcessesRemaining=99,
            wrapperRootsRemaining=99,
            networkRequestsObserved=True,
        )
        errors = self.validate(document)
        self.assertIn(
            "cleanup.measured.serpyAndUITestProcessesRemaining must be 0", errors
        )
        self.assertIn("cleanup.measured.wrapperRootsRemaining must be 0", errors)
        self.assertIn("cleanup.measured.networkRequestsObserved must be false", errors)

    def test_unrelated_tracked_text_cannot_satisfy_result_evidence(self) -> None:
        document = deepcopy(self.complete)
        document["artifacts"]["resultEvidence"] = ["evidence/notes.txt"]
        self.assertIn(
            "artifacts.resultEvidence is not an inspectable xcresult",
            self.validate(document),
        )

    def test_tested_commit_must_resolve(self) -> None:
        document = deepcopy(self.complete)
        document["testedCommit"] = "f" * 40
        self.assertIn("testedCommit does not resolve to a commit", self.validate(document))

    def test_xcode_identifier_must_map_to_an_actual_method(self) -> None:
        document = deepcopy(self.complete)
        document["xcodeTestIdentifier"] = "GoldenGuideUITests/test_does_not_exist()"
        self.assertIn(
            "xcodeTestIdentifier does not map to a GuideCompanionUITests method",
            self.validate(document),
        )

    def test_plan_and_configuration_must_map_to_committed_xctestplan(self) -> None:
        document = deepcopy(self.complete)
        document["testPlanConfiguration"] = "Invented"
        self.assertIn(
            "testPlanConfiguration is absent from the committed xctestplan",
            self.validate(document),
        )

    def test_tracked_proof_discovery_cannot_omit_uf09(self) -> None:
        tracked = {
            "evidence/issue-13-real-app-UF08-proof.json",
            "evidence/issue-13-real-app-UF09-proof.json",
            "evidence/issue-13-real-app-UF12-proof.json",
        }
        self.assertEqual(evidence_contract.discover_proofs(tracked), sorted(tracked))

    def test_cli_proof_path_must_resolve_beneath_evidence(self) -> None:
        with self.assertRaisesRegex(ValueError, "proof path must be beneath repo evidence"):
            evidence_contract.resolve_proof_path(
                self.repo_root, "../../outside-proof.json"
            )
        with self.assertRaisesRegex(ValueError, "proof path must be beneath repo evidence"):
            evidence_contract.resolve_proof_path(
                self.repo_root, str(self.repo_root / "absolute-proof.json")
            )

    def test_overall_gate_cannot_be_green_before_cloud_burn_in_and_installed_pass(self) -> None:
        overall = {
            "schemaVersion": 1,
            "issue": 13,
            "overallStatus": "green",
            "gates": {
                "completeGoldenPlan": "red",
                "xcodeCloudConfigured": False,
                "xcodeCloudCleanRuns": 0,
                "xcodeCloudRequiredCleanRuns": 10,
                "installedAcceptance": "red",
                "installedArtifact": None,
            },
        }
        self.assertIn(
            "overallStatus must be red",
            evidence_contract.validate_overall_status(overall),
        )


if __name__ == "__main__":
    unittest.main()
