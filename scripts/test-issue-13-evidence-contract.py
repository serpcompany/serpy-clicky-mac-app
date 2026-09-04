#!/usr/bin/env python3
"""Focused tests for the Issue 13 evidence contract validator."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path


SCRIPT = Path(__file__).with_name("validate-issue-13-evidence.py")
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("evidence_contract", SCRIPT)
assert SPEC and SPEC.loader
evidence_contract = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(evidence_contract)


class EvidenceContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.repo_root = Path(self.temporary_directory.name)
        artifact = self.repo_root / "evidence" / "primary-report.png"
        artifact.parent.mkdir()
        artifact.write_bytes(b"curated fixture")
        self.tracked_paths = {"evidence/primary-report.png"}
        self.complete = {
            "schemaVersion": 2,
            "issue": 13,
            "evidenceStatus": "complete",
            "missingRequirements": [],
            "testId": "GT-UF12-001",
            "xcodeTestIdentifier": "GoldenGuideUITests/test_example()",
            "testedCommit": "1" * 40,
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
                "primary": ["evidence/primary-report.png"],
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

    def validate(self, document):
        return evidence_contract.validate_document(
            document,
            repo_root=self.repo_root,
            tracked_paths=self.tracked_paths,
        )

    def test_complete_proof_with_committed_primary_artifact_passes(self) -> None:
        self.assertEqual(self.validate(self.complete), [])

    def test_complete_proof_requires_a_committed_primary_artifact(self) -> None:
        document = deepcopy(self.complete)
        document["artifacts"]["primary"] = ["evidence/missing.xcresult"]
        errors = self.validate(document)
        self.assertIn(
            "artifacts.primary is not committed: evidence/missing.xcresult", errors
        )

    def test_incomplete_failed_proof_must_be_red_and_name_every_gap(self) -> None:
        document = deepcopy(self.complete)
        document["testedCommit"] = None
        document["result"].update(
            status="failed-as-injected",
            passed=0,
            failed=1,
            durationSeconds=None,
        )
        document["failures"] = []
        document["artifacts"]["primary"] = []
        document["artifacts"]["unavailable"] = ["primary result bundle"]
        document["cleanup"]["measured"].pop("networkRequestsObserved")
        document["cleanup"]["unverifiedDimensions"] = ["networkRequestsObserved"]
        document["missingRequirements"] = [
            "artifacts.primary",
            "cleanup.networkRequestsObserved",
            "failures",
            "result.durationSeconds",
            "testedCommit",
        ]
        document["evidenceStatus"] = "red"
        self.assertEqual(self.validate(document), [])

    def test_incomplete_proof_cannot_claim_complete(self) -> None:
        document = deepcopy(self.complete)
        document["artifacts"]["primary"] = []
        document["artifacts"]["unavailable"] = ["primary result bundle"]
        document["missingRequirements"] = ["artifacts.primary"]
        errors = self.validate(document)
        self.assertIn("evidenceStatus must be partial", errors)

    def test_measured_cleanup_value_must_match_its_dimension(self) -> None:
        document = deepcopy(self.complete)
        document["cleanup"]["measured"]["networkRequestsObserved"] = 0
        errors = self.validate(document)
        self.assertIn(
            "cleanup.measured.networkRequestsObserved must be boolean", errors
        )


if __name__ == "__main__":
    unittest.main()
