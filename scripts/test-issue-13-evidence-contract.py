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
        forged = (
            b"\x89PNG\r\n\x1a\n"
            + (13).to_bytes(4, "big")
            + b"IHDR"
            + (1200).to_bytes(4, "big")
            + (800).to_bytes(4, "big")
        )
        (self.repo_root / "evidence" / "issue-13-UF12-forged-xcode-report.png").write_bytes(
            forged
        )
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
            "complete evidence requires live primary-artifact verification and reviewer approval",
            errors,
        )
        self.assertIn(
            "artifacts.resultEvidence is not an inspectable xcresult", errors
        )

    def test_copied_artifact_at_a_different_commit_still_cannot_be_complete(self) -> None:
        (self.repo_root / "copy-marker.txt").write_text("later commit")
        self.git("add", "copy-marker.txt")
        self.git("-c", "commit.gpgSign=false", "commit", "-qm", "later")
        document = deepcopy(self.complete)
        document["testedCommit"] = self.git("rev-parse", "HEAD").stdout.strip()
        self.assertIn(
            "complete evidence requires live primary-artifact verification and reviewer approval",
            self.validate(document),
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
        self.assertIn(
            "failed-as-injected requires executed=1, passed=0, failed=1, skipped=0",
            self.validate(document),
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

    def test_forged_twenty_four_byte_png_is_not_a_report_image(self) -> None:
        forged = self.repo_root / "evidence" / "issue-13-UF12-forged-xcode-report.png"
        self.assertFalse(evidence_contract._is_xcode_report_png(forged))

    def test_tested_commit_must_resolve(self) -> None:
        document = deepcopy(self.complete)
        document["testedCommit"] = "f" * 40
        self.assertIn("testedCommit does not resolve to a commit", self.validate(document))

    def test_xcode_identifier_must_map_to_an_actual_method(self) -> None:
        document = deepcopy(self.complete)
        document["xcodeTestIdentifier"] = "GoldenGuideUITests/test_does_not_exist()"
        self.assertIn(
            "xcodeTestIdentifier does not map to an executable GuideCompanionUITests method",
            self.validate(document),
        )

    def test_commented_out_swift_function_is_not_an_executable_test(self) -> None:
        source = self.repo_root / "GuideCompanionUITests" / "GoldenGuideUITests.swift"
        source.write_text(
            "final class GoldenGuideUITests {\n"
            "  // func test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure() {}\n"
            "}\n"
        )
        self.git("add", source.relative_to(self.repo_root).as_posix())
        self.git("-c", "commit.gpgSign=false", "commit", "-qm", "comment test")
        document = deepcopy(self.complete)
        document["testedCommit"] = self.git("rev-parse", "HEAD").stdout.strip()
        self.assertIn(
            "xcodeTestIdentifier does not map to an executable GuideCompanionUITests method",
            self.validate(document),
        )

    def test_claimed_method_must_be_owned_by_the_exact_swift_class(self) -> None:
        source = self.repo_root / "GuideCompanionUITests" / "GoldenGuideUITests.swift"
        source.write_text(
            "final class GoldenGuideUITests {}\n"
            "final class OtherTests {\n"
            "  func test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure() {}\n"
            "}\n"
        )
        self.git("add", source.relative_to(self.repo_root).as_posix())
        self.git("-c", "commit.gpgSign=false", "commit", "-qm", "move test method")
        document = deepcopy(self.complete)
        document["testedCommit"] = self.git("rev-parse", "HEAD").stdout.strip()
        self.assertIn(
            "xcodeTestIdentifier does not map to an executable GuideCompanionUITests method",
            self.validate(document),
        )

    def test_unrelated_xcresult_text_cannot_match_the_claimed_test(self) -> None:
        summary = {
            "totalTestCount": 1,
            "passedTests": 1,
            "failedTests": 0,
            "skippedTests": 0,
        }
        tests = {
            "testNodes": [
                {
                    "nodeType": "Test Case",
                    "name": "test_unrelated()",
                    "result": "Passed",
                    "details": self.complete["xcodeTestIdentifier"],
                }
            ]
        }
        self.assertIn(
            "xcresult does not contain the exact claimed test node and status",
            evidence_contract.validate_xcresult_data(summary, tests, self.complete),
        )

    def test_injected_failure_requires_the_exact_failed_test_node(self) -> None:
        document = deepcopy(self.complete)
        document["proofRole"] = "red-capability"
        document["evidenceStatus"] = "red"
        document["result"].update(
            status="failed-as-injected", executed=1, passed=0, failed=1, skipped=0
        )
        summary = {
            "totalTestCount": 1,
            "passedTests": 0,
            "failedTests": 1,
            "skippedTests": 0,
        }
        tests = {
            "testNodes": [
                {
                    "nodeType": "Test Case",
                    "name": "test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure()",
                    "result": "Passed",
                }
            ]
        }
        self.assertIn(
            "xcresult does not contain the exact claimed test node and status",
            evidence_contract.validate_xcresult_data(summary, tests, document),
        )

    def test_xcresult_bare_method_under_wrong_target_and_class_is_rejected(self) -> None:
        summary = {
            "totalTestCount": 1,
            "passedTests": 1,
            "failedTests": 0,
            "skippedTests": 0,
        }
        tests = {
            "testNodes": [
                {
                    "nodeType": "Test Plan",
                    "name": "GuideCompanionGolden",
                    "children": [
                        {
                            "nodeType": "Unit test bundle",
                            "name": "OtherUITests",
                            "children": [
                                {
                                    "nodeType": "Test Suite",
                                    "name": "OtherTests",
                                    "children": [
                                        {
                                            "nodeType": "Test Case",
                                            "name": "test_unrelated()",
                                            "nodeIdentifier": self.complete[
                                                "xcodeTestIdentifier"
                                            ],
                                            "result": "Passed",
                                        }
                                    ],
                                }
                            ],
                        }
                    ],
                }
            ]
        }
        self.assertIn(
            "xcresult does not contain the exact claimed test node and status",
            evidence_contract.validate_xcresult_data(summary, tests, self.complete),
        )

    def test_failed_result_requires_stage_cause_and_recovery(self) -> None:
        document = deepcopy(self.complete)
        document["proofRole"] = "red-capability"
        document["evidenceStatus"] = "red"
        document["result"].update(
            status="failed-as-injected", executed=1, passed=0, failed=1, skipped=0
        )
        document["failures"] = [{"x": 1}]
        self.assertIn(
            "each failure requires nonempty stage, cause, and recovery",
            self.validate(document),
        )

    def test_plan_and_configuration_must_map_to_committed_xctestplan(self) -> None:
        document = deepcopy(self.complete)
        document["testPlanConfiguration"] = "Invented"
        self.assertIn(
            "testPlanConfiguration is absent from the committed xctestplan",
            self.validate(document),
        )

    def test_tracked_proof_discovery_cannot_omit_uf09_or_claim_cloud_install_authority(self) -> None:
        tracked = {
            "evidence/issue-13-real-app-UF08-proof.json",
            "evidence/issue-13-real-app-UF09-proof.json",
            "evidence/issue-13-real-app-UF12-proof.json",
            "evidence/issue-13-xcode-cloud-run12-flow-proof.json",
            "evidence/issue-13-build-43-m3-install-proof.json",
        }
        self.assertEqual(
            evidence_contract.discover_proofs(tracked),
            sorted(path for path in tracked if "real-app" in path),
        )

    def test_cli_proof_path_must_resolve_beneath_evidence(self) -> None:
        with self.assertRaisesRegex(ValueError, "proof path must be beneath repo evidence"):
            evidence_contract.resolve_proof_path(
                self.repo_root, "../../outside-proof.json"
            )
        with self.assertRaisesRegex(ValueError, "proof path must be beneath repo evidence"):
            evidence_contract.resolve_proof_path(
                self.repo_root, str(self.repo_root / "absolute-proof.json")
            )

    def test_cli_rejects_an_out_of_tree_symlink_proof_argument(self) -> None:
        scripts = self.repo_root / "scripts"
        scripts.mkdir()
        validator = scripts / SCRIPT.name
        validator.write_text(SCRIPT.read_text())
        with tempfile.TemporaryDirectory() as outside_directory:
            outside_proof = Path(outside_directory) / "outside-proof.json"
            outside_proof.write_text("{}")
            proof_link = self.repo_root / "evidence" / "issue-13-symlink-proof.json"
            proof_link.symlink_to(outside_proof)
            result = subprocess.run(
                [
                    sys.executable,
                    str(validator),
                    proof_link.relative_to(self.repo_root).as_posix(),
                ],
                cwd=self.repo_root,
                capture_output=True,
                text=True,
            )
        self.assertEqual(result.returncode, 64)
        self.assertIn("ERROR: proof path must be beneath repo evidence", result.stderr)

    def test_overall_gate_cannot_be_green_before_cloud_burn_in_and_installed_pass(self) -> None:
        overall = {
            "schemaVersion": 1,
            "issue": 13,
            "overallStatus": "green",
            "gates": {
                "completeGoldenPlan": "red",
                "xcodeCloudConfigured": True,
                "xcodeCloudCleanRuns": 0,
                "xcodeCloudRequiredCleanRuns": 10,
                "installedAcceptance": "red",
                "installedArtifact": "evidence/issue-13-build-43-m3-install-proof.json",
            },
        }
        self.assertIn(
            "overallStatus must be red",
            evidence_contract.validate_overall_status(overall),
        )

    def test_invented_all_green_overall_gate_is_rejected_unconditionally(self) -> None:
        overall = {
            "schemaVersion": 1,
            "issue": 13,
            "overallStatus": "green",
            "gates": {
                "completeGoldenPlan": "green",
                "xcodeCloudConfigured": True,
                "xcodeCloudCleanRuns": 10,
                "xcodeCloudRequiredCleanRuns": 10,
                "installedAcceptance": "green",
                "installedArtifact": "invented.dmg",
            },
        }
        self.assertIn(
            "overall green requires external live verification and is not accepted by this linter",
            evidence_contract.validate_overall_status(overall),
        )


if __name__ == "__main__":
    unittest.main()
