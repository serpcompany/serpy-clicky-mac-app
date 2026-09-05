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
        self.cloud_summary = {
            "schemaVersion": 2,
            "runId": "dab4658d-f470-4e84-bf24-622bb6f9346a",
            "sourceCommit": self.tested_commit,
            "result": "FAILED",
            "plan": "GuideCompanionGolden",
            "action": "GuideCompanionGolden - macOS",
            "destination": {
                "name": "Apple Virtual Machine 1",
                "platform": "macOS",
                "osVersion": "26.6.2",
            },
            "passedTests": 0,
            "failedTests": 18,
            "skippedTests": 0,
            "durationSeconds": 1351.054,
            "failures": [
                {
                    "count": 18,
                    "durationSecondsEach": 60,
                    "summary": "application.launch timed out in every test",
                }
            ],
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

    def write_valid_cli_inputs(self) -> Path:
        scripts = self.repo_root / "scripts"
        scripts.mkdir(exist_ok=True)
        validator = scripts / SCRIPT.name
        validator.write_text(SCRIPT.read_text())

        proof = deepcopy(self.complete)
        proof["evidenceStatus"] = "partial"
        proof["missingRequirements"] = [
            "artifacts.resultEvidence",
            "external.livePrimaryArtifactVerification",
        ]
        proof["artifacts"]["resultEvidence"] = []
        proof_path = (
            self.repo_root / "evidence" / "issue-13-real-app-UF12-auto-proof.json"
        )
        proof_path.write_text(json.dumps(proof))

        overall_path = self.repo_root / evidence_contract.OVERALL_STATUS_PATH
        overall_path.write_text(
            json.dumps(
                {
                    "schemaVersion": 1,
                    "issue": 13,
                    "overallStatus": "red",
                    "gates": {
                        "completeGoldenPlan": "red",
                        "xcodeCloudConfigured": True,
                        "xcodeCloudCleanRuns": 0,
                        "xcodeCloudRequiredCleanRuns": 10,
                        "installedAcceptance": "red",
                        "installedArtifact": "evidence/issue-13-build-43-m3-install-proof.json",
                    },
                }
            )
        )
        self.git(
            "add",
            "-f",
            validator.relative_to(self.repo_root).as_posix(),
            proof_path.relative_to(self.repo_root).as_posix(),
            overall_path.relative_to(self.repo_root).as_posix(),
        )
        self.git("-c", "commit.gpgSign=false", "commit", "-qm", "valid CLI inputs")
        return overall_path

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

    def test_swift_string_literals_cannot_forge_an_executable_test(self) -> None:
        source = self.repo_root / "GuideCompanionUITests" / "GoldenGuideUITests.swift"
        source.write_text(
            "final class GoldenGuideUITests {\n"
            "  let inline = \"func "
            "test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure() {}\"\n"
            "  let multiline = \"\"\"\n"
            "  func test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure() {}\n"
            "  \"\"\"\n"
            "}\n"
        )
        self.git("add", source.relative_to(self.repo_root).as_posix())
        self.git("-c", "commit.gpgSign=false", "commit", "-qm", "string test")
        document = deepcopy(self.complete)
        document["testedCommit"] = self.git("rev-parse", "HEAD").stdout.strip()
        self.assertIn(
            "xcodeTestIdentifier does not map to an executable GuideCompanionUITests method",
            self.validate(document),
        )

    def test_raw_and_interpolated_swift_strings_cannot_forge_a_test(self) -> None:
        source = self.repo_root / "GuideCompanionUITests" / "GoldenGuideUITests.swift"
        source.write_text(
            'final class GoldenGuideUITests {\n'
            '  let raw = ##"""\n'
            '  func test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure() {}\n'
            '  """##\n'
            '  let interpolated = """\n'
            '  \\(render("nested string with } and \\\"quotes\\\""))\n'
            '  func test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure() {}\n'
            '  """\n'
            '}\n'
        )
        self.git("add", source.relative_to(self.repo_root).as_posix())
        self.git("-c", "commit.gpgSign=false", "commit", "-qm", "raw string test")
        document = deepcopy(self.complete)
        document["testedCommit"] = self.git("rev-parse", "HEAD").stdout.strip()
        self.assertIn(
            "xcodeTestIdentifier does not map to an executable GuideCompanionUITests method",
            self.validate(document),
        )

    def test_method_under_false_compilation_condition_is_not_executable(self) -> None:
        source = self.repo_root / "GuideCompanionUITests" / "GoldenGuideUITests.swift"
        source.write_text(
            "final class GoldenGuideUITests {\n"
            "  #if false\n"
            "  func test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure() {}\n"
            "  #endif\n"
            "}\n"
        )
        self.git("add", source.relative_to(self.repo_root).as_posix())
        self.git("-c", "commit.gpgSign=false", "commit", "-qm", "false condition")
        document = deepcopy(self.complete)
        document["testedCommit"] = self.git("rev-parse", "HEAD").stdout.strip()
        self.assertIn(
            "xcodeTestIdentifier does not map to an executable GuideCompanionUITests method",
            self.validate(document),
        )

    def test_method_under_platform_compilation_condition_is_not_executable(self) -> None:
        source = self.repo_root / "GuideCompanionUITests" / "GoldenGuideUITests.swift"
        source.write_text(
            "#if os(iOS)\n"
            "final class GoldenGuideUITests {\n"
            "  func test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure() {}\n"
            "}\n"
            "#endif\n"
        )
        self.git("add", source.relative_to(self.repo_root).as_posix())
        self.git("-c", "commit.gpgSign=false", "commit", "-qm", "platform condition")
        document = deepcopy(self.complete)
        document["testedCommit"] = self.git("rev-parse", "HEAD").stdout.strip()
        self.assertIn(
            "xcodeTestIdentifier does not map to an executable GuideCompanionUITests method",
            self.validate(document),
        )

    def test_method_under_custom_compilation_condition_is_not_executable(self) -> None:
        source = self.repo_root / "GuideCompanionUITests" / "GoldenGuideUITests.swift"
        source.write_text(
            "final class GoldenGuideUITests {\n"
            "  #if SERPY_GOLDEN_FIXTURE\n"
            "  func test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure() {}\n"
            "  #endif\n"
            "}\n"
        )
        self.git("add", source.relative_to(self.repo_root).as_posix())
        self.git("-c", "commit.gpgSign=false", "commit", "-qm", "custom condition")
        document = deepcopy(self.complete)
        document["testedCommit"] = self.git("rev-parse", "HEAD").stdout.strip()
        self.assertIn(
            "xcodeTestIdentifier does not map to an executable GuideCompanionUITests method",
            self.validate(document),
        )

    def test_method_in_nested_elseif_or_else_branch_is_not_executable(self) -> None:
        source = self.repo_root / "GuideCompanionUITests" / "GoldenGuideUITests.swift"
        source.write_text(
            "final class GoldenGuideUITests {\n"
            "  #if OUTER\n"
            "    #if INNER\n"
            "    let marker = 1\n"
            "    #elseif ALTERNATE\n"
            "    let marker = 2\n"
            "    #else\n"
            "    func test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure() {}\n"
            "    #endif\n"
            "  #endif\n"
            "}\n"
        )
        self.git("add", source.relative_to(self.repo_root).as_posix())
        self.git("-c", "commit.gpgSign=false", "commit", "-qm", "nested condition")
        document = deepcopy(self.complete)
        document["testedCommit"] = self.git("rev-parse", "HEAD").stdout.strip()
        self.assertIn(
            "xcodeTestIdentifier does not map to an executable GuideCompanionUITests method",
            self.validate(document),
        )

    def test_condition_directives_in_noncode_do_not_hide_unconditional_method(self) -> None:
        source = self.repo_root / "GuideCompanionUITests" / "GoldenGuideUITests.swift"
        source.write_text(
            "// #if false\n"
            "/* #if os(iOS) */\n"
            "final class GoldenGuideUITests {\n"
            '  let ordinary = "#if SERPY_DISABLED"\n'
            '  let multiline = """\n#if false\n"""\n'
            '  let raw = ##"#if os(iOS)"##\n'
            '  let interpolated = "value \\(render(\"#if INNER\"))"\n'
            "  func test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure() {}\n"
            "}\n"
        )
        self.git("add", source.relative_to(self.repo_root).as_posix())
        self.git("-c", "commit.gpgSign=false", "commit", "-qm", "noncode directives")
        document = deepcopy(self.complete)
        document["testedCommit"] = self.git("rev-parse", "HEAD").stdout.strip()
        self.assertNotIn(
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

    def test_current_and_future_cloud_proofs_are_discovered_for_validation(self) -> None:
        tracked = {
            "evidence/issue-13-xcode-cloud-run12-flow-proof.json",
            "evidence/issue-13-xcode-cloud-run13-red-proof.json",
            "evidence/issue-13-xcode-cloud-run15-focused-green-proof.json",
            "evidence/issue-13-xcode-cloud-run20-proof.json",
        }
        self.assertEqual(
            evidence_contract.discover_cloud_proofs(tracked),
            sorted(path for path in tracked if "run12" not in path),
        )

    def test_cloud_summary_requires_plan_destination_counts_duration_failures_and_source(self) -> None:
        required_fields = (
            "sourceCommit",
            "plan",
            "action",
            "destination",
            "passedTests",
            "failedTests",
            "skippedTests",
            "durationSeconds",
            "failures",
        )
        for field in required_fields:
            with self.subTest(field=field):
                document = deepcopy(self.cloud_summary)
                del document[field]
                self.assertIn(
                    f"{field} is required",
                    evidence_contract.validate_cloud_summary(
                        document, repo_root=self.repo_root
                    ),
                )

    def test_cloud_summary_rejects_inconsistent_counts_and_failure_receipts(self) -> None:
        document = deepcopy(self.cloud_summary)
        document["result"] = "PASSED"
        document["failedTests"] = 1
        document["failures"] = []
        errors = evidence_contract.validate_cloud_summary(
            document, repo_root=self.repo_root
        )
        self.assertIn("PASSED cloud result must have failedTests=0", errors)
        self.assertIn("failed cloud result requires failure receipts", errors)

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

    def test_resolver_rejects_a_symlink_even_when_its_target_is_in_evidence(self) -> None:
        target = (
            self.repo_root / "evidence" / "issue-13-real-app-UF12-target-proof.json"
        )
        target.write_text("{}")
        proof_link = (
            self.repo_root / "evidence" / "issue-13-real-app-UF12-link-proof.json"
        )
        proof_link.symlink_to(target)
        with self.assertRaisesRegex(ValueError, "proof path must be beneath repo evidence"):
            evidence_contract.resolve_proof_path(
                self.repo_root, proof_link.relative_to(self.repo_root).as_posix()
            )

    def test_default_discovery_rejects_an_out_of_tree_symlink_proof(self) -> None:
        scripts = self.repo_root / "scripts"
        scripts.mkdir()
        validator = scripts / SCRIPT.name
        validator.write_text(SCRIPT.read_text())
        with tempfile.TemporaryDirectory() as outside_directory:
            outside_proof = Path(outside_directory) / "outside-proof.json"
            outside_proof.write_text("{}")
            proof_link = (
                self.repo_root
                / "evidence"
                / "issue-13-real-app-UF12-auto-proof.json"
            )
            proof_link.symlink_to(outside_proof)
            self.git("add", "-f", proof_link.relative_to(self.repo_root).as_posix())
            result = subprocess.run(
                [sys.executable, str(validator)],
                cwd=self.repo_root,
                capture_output=True,
                text=True,
            )
        self.assertEqual(result.returncode, 1)
        self.assertIn(
            "evidence/issue-13-real-app-UF12-auto-proof.json: "
            "ERROR: proof path must be beneath repo evidence",
            result.stderr,
        )

    def test_default_discovery_rejects_an_out_of_tree_symlink_cloud_summary(self) -> None:
        scripts = self.repo_root / "scripts"
        scripts.mkdir()
        validator = scripts / SCRIPT.name
        validator.write_text(SCRIPT.read_text())
        ordinary_proof = (
            self.repo_root / "evidence" / "issue-13-real-app-UF12-auto-proof.json"
        )
        ordinary_proof.write_text("{}")
        self.git("add", "-f", ordinary_proof.relative_to(self.repo_root).as_posix())
        with tempfile.TemporaryDirectory() as outside_directory:
            outside_summary = Path(outside_directory) / "outside-summary.json"
            outside_summary.write_text("{}")
            cloud_link = (
                self.repo_root
                / "evidence"
                / "issue-13-xcode-cloud-run99-auto-proof.json"
            )
            cloud_link.symlink_to(outside_summary)
            self.git("add", "-f", cloud_link.relative_to(self.repo_root).as_posix())
            result = subprocess.run(
                [sys.executable, str(validator)],
                cwd=self.repo_root,
                capture_output=True,
                text=True,
            )
        self.assertEqual(result.returncode, 1)
        self.assertIn(
            "evidence/issue-13-xcode-cloud-run99-auto-proof.json: "
            "ERROR: proof path must be beneath repo evidence",
            result.stderr,
        )

    def test_default_discovery_rejects_dirty_external_overall_status_symlink(
        self,
    ) -> None:
        overall_path = self.write_valid_cli_inputs()
        with tempfile.TemporaryDirectory() as outside_directory:
            outside_status = Path(outside_directory) / "overall-status.json"
            outside_status.write_text(overall_path.read_text())
            overall_path.unlink()
            overall_path.symlink_to(outside_status)
            result = subprocess.run(
                [sys.executable, str(self.repo_root / "scripts" / SCRIPT.name)],
                cwd=self.repo_root,
                capture_output=True,
                text=True,
            )
        self.assertEqual(result.returncode, 1)
        self.assertIn(
            "evidence/issue-13-overall-status.json: "
            "ERROR: proof path must be beneath repo evidence",
            result.stderr,
        )

    def test_default_discovery_rejects_tracked_same_tree_overall_status_symlink(
        self,
    ) -> None:
        overall_path = self.write_valid_cli_inputs()
        target = self.repo_root / "evidence" / "overall-status-target.json"
        target.write_text(overall_path.read_text())
        overall_path.unlink()
        overall_path.symlink_to(target.name)
        self.git(
            "add",
            "-f",
            target.relative_to(self.repo_root).as_posix(),
            overall_path.relative_to(self.repo_root).as_posix(),
        )
        self.git("-c", "commit.gpgSign=false", "commit", "-qm", "tracked status link")
        result = subprocess.run(
            [sys.executable, str(self.repo_root / "scripts" / SCRIPT.name)],
            cwd=self.repo_root,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn(
            "evidence/issue-13-overall-status.json: "
            "ERROR: proof path must be beneath repo evidence",
            result.stderr,
        )

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
