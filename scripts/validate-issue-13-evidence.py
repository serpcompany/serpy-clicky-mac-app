#!/usr/bin/env python3
"""Validate that every tracked Issue 13 proof states its limits honestly."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import zipfile
import zlib
from pathlib import Path
from typing import Any, Optional, Tuple


PROOF_PATTERN = re.compile(r"^evidence/issue-13-real-app-.*-proof\.json$")
CLOUD_PROOF_PATTERN = re.compile(
    r"^evidence/issue-13-xcode-cloud-run(?:1[3-9]|[2-9][0-9]+).*proof\.json$"
)
OVERALL_STATUS_PATH = "evidence/issue-13-overall-status.json"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

REQUIRED_CLEANUP_DIMENSIONS = frozenset(
    {
        "wrapperExitCode",
        "serpyAndUITestProcessesRemaining",
        "xctestSessionRootsRemaining",
        "wrapperRootsRemaining",
        "launchServicesRegistrationsRemaining",
        "unexpectedSystemPromptsObserved",
        "networkRequestsObserved",
        "keychainAccessObserved",
        "buildCachesRemaining",
    }
)
INTEGER_CLEANUP_DIMENSIONS = frozenset(
    {
        "wrapperExitCode",
        "serpyAndUITestProcessesRemaining",
        "xctestSessionRootsRemaining",
        "wrapperRootsRemaining",
        "launchServicesRegistrationsRemaining",
        "buildCachesRemaining",
    }
)
BOOLEAN_CLEANUP_DIMENSIONS = REQUIRED_CLEANUP_DIMENSIONS - INTEGER_CLEANUP_DIMENSIONS


def _nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _path_list(value: Any) -> bool:
    return isinstance(value, list) and all(_nonempty_string(item) for item in value)


def _tracked_paths(repo_root: Path) -> set[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=repo_root,
        check=True,
        capture_output=True,
    )
    return {item.decode() for item in result.stdout.split(b"\0") if item}


def discover_proofs(tracked_paths: set[str]) -> list[str]:
    """Return every tracked Issue 13 proof rather than an allowlist."""
    return sorted(path for path in tracked_paths if PROOF_PATTERN.fullmatch(path))


def discover_cloud_proofs(tracked_paths: set[str]) -> list[str]:
    """Return current and future cloud summaries governed by schema version 2."""
    return sorted(path for path in tracked_paths if CLOUD_PROOF_PATTERN.fullmatch(path))


def _resolve_beneath_evidence(repo_root: Path, supplied_path: str) -> Path:
    supplied = Path(supplied_path)
    if supplied.is_absolute() or ".." in supplied.parts:
        raise ValueError("proof path must be beneath repo evidence")
    evidence_root = (repo_root / "evidence").resolve()
    resolved = (repo_root / supplied).resolve()
    try:
        common = Path(os.path.commonpath((evidence_root, resolved)))
    except ValueError as error:
        raise ValueError("proof path must be beneath repo evidence") from error
    if common != evidence_root:
        raise ValueError("proof path must be beneath repo evidence")
    return resolved


def resolve_proof_path(
    repo_root: Path,
    proof_path: str,
    *,
    expected_pattern: re.Pattern[str] = PROOF_PATTERN,
) -> Path:
    """Resolve one proof path to a regular file without permitting escape."""
    candidate = repo_root / proof_path
    resolved = _resolve_beneath_evidence(repo_root, proof_path)
    relative = resolved.relative_to(repo_root.resolve()).as_posix()
    if (
        candidate.is_symlink()
        or not expected_pattern.fullmatch(relative)
        or not resolved.is_file()
    ):
        raise ValueError("proof path must be beneath repo evidence")
    return resolved


def _git_commit_exists(repo_root: Path, commit: str) -> bool:
    return (
        subprocess.run(
            ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
            cwd=repo_root,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def _git_text_at_commit(repo_root: Path, commit: str, path: str) -> Optional[str]:
    result = subprocess.run(
        ["git", "show", f"{commit}:{path}"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    return result.stdout if result.returncode == 0 else None


def _strip_swift_noncode(source: str) -> str:
    """Blank Swift comments and string literals while preserving line structure."""
    output = list(source)
    length = len(source)

    def blank(start: int, end: int) -> None:
        for index in range(start, min(end, length)):
            if output[index] != "\n":
                output[index] = " "

    def string_delimiter(index: int) -> Optional[tuple[int, int, int]]:
        cursor = index
        hashes = 0
        while cursor < length and source[cursor] == "#":
            hashes += 1
            cursor += 1
        if cursor >= length or source[cursor] != '"':
            return None
        if hashes == 0 and index != cursor:
            return None
        quotes = 3 if source.startswith('"""', cursor) else 1
        return hashes, quotes, cursor + quotes

    def consume_line_comment(index: int) -> int:
        cursor = index + 2
        while cursor < length and source[cursor] != "\n":
            cursor += 1
        blank(index, cursor)
        return cursor

    def consume_block_comment(index: int) -> int:
        cursor = index + 2
        depth = 1
        while cursor < length and depth:
            if source.startswith("/*", cursor):
                depth += 1
                cursor += 2
            elif source.startswith("*/", cursor):
                depth -= 1
                cursor += 2
            else:
                cursor += 1
        blank(index, cursor)
        return cursor

    def consume_interpolation(index: int) -> int:
        cursor = index
        depth = 1
        while cursor < length and depth:
            if source.startswith("//", cursor):
                cursor = consume_line_comment(cursor)
                continue
            if source.startswith("/*", cursor):
                cursor = consume_block_comment(cursor)
                continue
            delimiter = string_delimiter(cursor)
            if delimiter is not None:
                cursor = consume_string(cursor, delimiter)
                continue
            if source[cursor] == "(":
                depth += 1
            elif source[cursor] == ")":
                depth -= 1
            cursor += 1
        return cursor

    def consume_string(index: int, delimiter: tuple[int, int, int]) -> int:
        hashes, quotes, cursor = delimiter
        interpolation = "\\" + ("#" * hashes) + "("
        closing = ('"' * quotes) + ("#" * hashes)
        while cursor < length:
            if source.startswith(closing, cursor):
                cursor += len(closing)
                blank(index, cursor)
                return cursor
            if source.startswith(interpolation, cursor):
                cursor = consume_interpolation(cursor + len(interpolation))
                continue
            if hashes == 0 and source[cursor] == "\\":
                cursor += min(2, length - cursor)
                continue
            cursor += 1
        blank(index, cursor)
        return cursor

    cursor = 0
    while cursor < length:
        if source.startswith("//", cursor):
            cursor = consume_line_comment(cursor)
            continue
        if source.startswith("/*", cursor):
            cursor = consume_block_comment(cursor)
            continue
        delimiter = string_delimiter(cursor)
        if delimiter is not None:
            cursor = consume_string(cursor, delimiter)
            continue
        cursor += 1
    return "".join(output)


def _swift_class_direct_scope(source: str, class_name: str) -> Optional[str]:
    class_match = re.search(
        rf"^[ \t]*(?:final[ \t]+)?class[ \t]+{re.escape(class_name)}\b[^{{]*{{",
        source,
        flags=re.MULTILINE,
    )
    if class_match is None:
        return None
    depth = 0
    direct_scope: list[str] = []
    for character in source[class_match.end() :]:
        if character == "{":
            depth += 1
            direct_scope.append(" ")
        elif character == "}":
            if depth == 0:
                return "".join(direct_scope)
            depth -= 1
            direct_scope.append(" ")
        elif depth == 0:
            direct_scope.append(character)
        else:
            direct_scope.append("\n" if character == "\n" else " ")
    return None


def _validate_test_source_and_plan(
    document: dict[str, Any], repo_root: Path, tested_commit: str
) -> list[str]:
    errors: list[str] = []
    identifier = document.get("xcodeTestIdentifier")
    match = re.fullmatch(r"([A-Za-z0-9_]+)/([A-Za-z0-9_]+)\(\)", str(identifier))
    if not match:
        return ["xcodeTestIdentifier must be Class/testMethod()"]
    class_name, method_name = match.groups()
    source_path = f"GuideCompanionUITests/{class_name}.swift"
    source = _git_text_at_commit(repo_root, tested_commit, source_path)
    executable_source = _strip_swift_noncode(source) if source is not None else ""
    class_scope = _swift_class_direct_scope(executable_source, class_name)
    method_pattern = re.compile(
        rf"^[ \t]*(?:override[ \t]+)?func[ \t]+{re.escape(method_name)}[ \t]*\(",
        flags=re.MULTILINE,
    )
    expected_token = str(document.get("testId", "")).replace("-", "_")
    if (
        class_scope is None
        or method_pattern.search(class_scope) is None
        or expected_token not in method_name
    ):
        errors.append(
            "xcodeTestIdentifier does not map to an executable GuideCompanionUITests method"
        )

    plan_name = document.get("testPlan")
    plan_text = (
        _git_text_at_commit(repo_root, tested_commit, f"{plan_name}.xctestplan")
        if _nonempty_string(plan_name)
        else None
    )
    if plan_text is None:
        errors.append("testPlan does not map to a committed xctestplan")
        return errors
    try:
        plan = json.loads(plan_text)
    except json.JSONDecodeError:
        errors.append("committed xctestplan is not valid JSON")
        return errors
    configurations = {
        item.get("name") for item in plan.get("configurations", []) if isinstance(item, dict)
    }
    if document.get("testPlanConfiguration") not in configurations:
        errors.append("testPlanConfiguration is absent from the committed xctestplan")
    targets = {
        item.get("target", {}).get("name")
        for item in plan.get("testTargets", [])
        if isinstance(item, dict) and isinstance(item.get("target"), dict)
    }
    if "GuideCompanionUITests" not in targets:
        errors.append("committed xctestplan does not include GuideCompanionUITests")
    return errors


def _validate_tracked_artifact(
    repo_root: Path, tracked_paths: set[str], artifact: str, field: str
) -> Tuple[Optional[Path], list[str]]:
    errors: list[str] = []
    try:
        path = _resolve_beneath_evidence(repo_root, artifact)
    except ValueError:
        return None, [f"artifacts.{field} path is not beneath repo evidence: {artifact}"]
    relative = path.relative_to(repo_root.resolve()).as_posix()
    if path.is_dir():
        prefix = relative.rstrip("/") + "/"
        files = [item for item in tracked_paths if item.startswith(prefix)]
        if not files:
            errors.append(f"artifacts.{field} is not committed: {artifact}")
        elif any(not (repo_root / item).is_file() for item in files):
            errors.append(f"artifacts.{field} has a missing committed member: {artifact}")
    elif relative not in tracked_paths:
        errors.append(f"artifacts.{field} is not committed: {artifact}")
    elif not path.is_file():
        errors.append(f"artifacts.{field} does not exist: {artifact}")
    return path, errors


def _read_xcresult_json(path: Path, view: str) -> Optional[dict[str, Any]]:
    result = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", view, "--path", str(path)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    try:
        summary = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    return summary if isinstance(summary, dict) and summary else None


def _read_xcresult_views(path: Path) -> Optional[Tuple[dict[str, Any], dict[str, Any]]]:
    summary = _read_xcresult_json(path, "summary")
    tests = _read_xcresult_json(path, "tests")
    if summary is None or tests is None:
        return None
    return summary, tests


def _read_retained_xcresult(
    path: Path,
) -> Optional[Tuple[dict[str, Any], dict[str, Any]]]:
    if path.name.endswith(".xcresult.zip") and path.is_file():
        if not zipfile.is_zipfile(path):
            return None
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            if any(Path(name).is_absolute() or ".." in Path(name).parts for name in names):
                return None
            roots = {
                Path(*Path(name).parts[: index + 1])
                for name in names
                for index, part in enumerate(Path(name).parts)
                if part.endswith(".xcresult")
            }
            if len(roots) != 1:
                return None
            with tempfile.TemporaryDirectory(prefix="serpy-xcresult-inspect.") as temporary:
                archive.extractall(temporary)
                extracted = Path(temporary) / roots.pop()
                return _read_xcresult_views(extracted)
    if path.name.endswith(".xcresult") and path.is_dir():
        return _read_xcresult_views(path)
    return None


def _test_nodes(value: Any, ancestors: tuple[dict[str, Any], ...] = ()):
    if isinstance(value, dict):
        if value.get("nodeType") in {"Test", "Test Case"}:
            yield value, ancestors
        child_ancestors = (
            ancestors + (value,) if _nonempty_string(value.get("nodeType")) else ancestors
        )
        for child in value.values():
            yield from _test_nodes(child, child_ancestors)
    elif isinstance(value, list):
        for child in value:
            yield from _test_nodes(child, ancestors)


def _xcresult_node_has_exact_identity(
    node: dict[str, Any],
    ancestors: tuple[dict[str, Any], ...],
    identifier: str,
    class_name: str,
    method: str,
) -> bool:
    owns_target = any(
        ancestor.get("nodeType") in {"UI test bundle", "Unit test bundle"}
        and ancestor.get("name") == "GuideCompanionUITests"
        for ancestor in ancestors
    )
    owns_class = any(
        ancestor.get("nodeType") == "Test Suite"
        and ancestor.get("name") == class_name
        for ancestor in ancestors
    )
    if not owns_target or not owns_class:
        return False
    if node.get("nodeIdentifier") in {
        identifier,
        f"GuideCompanionUITests/{identifier}",
    }:
        return True
    method_names = {method, f"{method}()"}
    if (
        node.get("name") not in method_names
        and node.get("nodeIdentifier") not in method_names
    ):
        return False
    return True


def validate_xcresult_data(
    summary: dict[str, Any], tests: dict[str, Any], document: dict[str, Any]
) -> list[str]:
    errors: list[str] = []
    result = document.get("result", {})
    for proof_field, summary_field in (
        ("executed", "totalTestCount"),
        ("passed", "passedTests"),
        ("failed", "failedTests"),
        ("skipped", "skippedTests"),
    ):
        if summary.get(summary_field) != result.get(proof_field):
            errors.append(
                f"xcresult {summary_field} does not match result.{proof_field}"
            )
    identifier = str(document.get("xcodeTestIdentifier", ""))
    class_name, _, raw_method = identifier.partition("/")
    method = raw_method.removesuffix("()")
    expected_result = (
        "Passed" if document.get("result", {}).get("status") == "passed" else "Failed"
    )
    matches = [
        node
        for node, ancestors in _test_nodes(tests)
        if (
            node.get("result") == expected_result
            and _xcresult_node_has_exact_identity(
                node, ancestors, identifier, class_name, method
            )
        )
    ]
    if len(matches) != 1:
        errors.append("xcresult does not contain the exact claimed test node and status")
    return errors


def _is_xcode_report_png(path: Path) -> bool:
    if not path.name.endswith("-xcode-report.png") or not path.is_file():
        return False
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        return False
    position = len(PNG_SIGNATURE)
    seen_ihdr = False
    seen_idat = False
    seen_iend = False
    while position + 12 <= len(data):
        length = int.from_bytes(data[position : position + 4], "big")
        chunk_end = position + 12 + length
        if chunk_end > len(data):
            return False
        chunk_type = data[position + 4 : position + 8]
        payload = data[position + 8 : position + 8 + length]
        expected_crc = int.from_bytes(data[position + 8 + length : chunk_end], "big")
        actual_crc = zlib.crc32(chunk_type + payload) & 0xFFFFFFFF
        if expected_crc != actual_crc:
            return False
        if chunk_type == b"IHDR":
            if seen_ihdr or position != len(PNG_SIGNATURE) or length != 13:
                return False
            seen_ihdr = True
        elif chunk_type == b"IDAT":
            seen_idat = True
        elif chunk_type == b"IEND":
            if length != 0 or chunk_end != len(data):
                return False
            seen_iend = True
            break
        position = chunk_end
    return seen_ihdr and seen_idat and seen_iend


def validate_document(
    document: dict[str, Any], *, repo_root: Path, tracked_paths: set[str]
) -> list[str]:
    errors: list[str] = []
    missing: list[str] = []

    if document.get("schemaVersion") != 2:
        errors.append("schemaVersion must be 2")
    if document.get("issue") != 13:
        errors.append("issue must be 13")
    if document.get("proofRole") not in {"focused-pass", "red-capability"}:
        errors.append("proofRole must be focused-pass or red-capability")
    if document.get("proofRole") == "focused-pass":
        missing.append("external.livePrimaryArtifactVerification")
    if document.get("evidenceStatus") == "complete":
        errors.append(
            "complete evidence requires live primary-artifact verification and reviewer approval"
        )
    if not re.fullmatch(r"GT-UF\d{2}-\d{3}", str(document.get("testId", ""))):
        errors.append("testId must be a GT-UF test ID")
    if not _nonempty_string(document.get("xcodeTestIdentifier")):
        errors.append("xcodeTestIdentifier is required")
    if not _nonempty_string(document.get("testPlan")):
        errors.append("testPlan is required")
    if not _nonempty_string(document.get("testPlanConfiguration")):
        errors.append("testPlanConfiguration is required")

    tested_commit = document.get("testedCommit")
    commit_resolves = False
    if tested_commit is None:
        missing.append("testedCommit")
    elif not re.fullmatch(r"[0-9a-f]{40}", str(tested_commit)):
        errors.append("testedCommit must be a full lowercase Git SHA or null")
    else:
        commit_resolves = _git_commit_exists(repo_root, tested_commit)
        if not commit_resolves:
            errors.append("testedCommit does not resolve to a commit")
    if commit_resolves:
        errors.extend(_validate_test_source_and_plan(document, repo_root, tested_commit))

    destination = document.get("destination")
    if not isinstance(destination, dict):
        errors.append("destination must be an object")
    else:
        for field in ("platform", "architecture", "osVersion", "osBuildNumber"):
            value = destination.get(field)
            if value is None:
                missing.append(f"destination.{field}")
            elif not _nonempty_string(value):
                errors.append(f"destination.{field} must be a nonempty string or null")

    result = document.get("result")
    failed = None
    result_status = None
    if not isinstance(result, dict):
        errors.append("result must be an object")
    else:
        result_status = result.get("status")
        if result_status not in {"passed", "failed-as-injected"}:
            errors.append("result.status must be passed or failed-as-injected")
        counts: dict[str, int] = {}
        for field in ("executed", "passed", "failed", "skipped"):
            value = result.get(field)
            if not isinstance(value, int) or isinstance(value, bool) or value < 0:
                errors.append(f"result.{field} must be a nonnegative integer")
            else:
                counts[field] = value
        if len(counts) == 4:
            if counts["executed"] != counts["passed"] + counts["failed"] + counts["skipped"]:
                errors.append("result counts do not add up to executed")
            if result_status == "passed" and counts["failed"] != 0:
                errors.append("passed result must have failed=0")
            if result_status == "passed" and counts["passed"] < 1:
                errors.append("passed result must include at least one passed test")
            if result_status == "failed-as-injected" and counts["failed"] < 1:
                errors.append("failed-as-injected result must have failed>0")
            if result_status == "failed-as-injected" and (
                counts["executed"],
                counts["passed"],
                counts["failed"],
                counts["skipped"],
            ) != (1, 0, 1, 0):
                errors.append(
                    "failed-as-injected requires executed=1, passed=0, failed=1, skipped=0"
                )
            failed = counts["failed"]
        duration = result.get("durationSeconds")
        if duration is None:
            missing.append("result.durationSeconds")
        elif not isinstance(duration, (int, float)) or isinstance(duration, bool) or duration <= 0:
            errors.append("result.durationSeconds must be positive or null")

    failures = document.get("failures")
    if not isinstance(failures, list):
        errors.append("failures must be an array")
    elif not all(
        isinstance(item, dict)
        and all(_nonempty_string(item.get(field)) for field in ("stage", "cause", "recovery"))
        for item in failures
    ):
        errors.append("each failure requires nonempty stage, cause, and recovery")
    elif failed and not failures:
        missing.append("failures")

    artifacts = document.get("artifacts")
    if not isinstance(artifacts, dict):
        errors.append("artifacts must be an object")
    else:
        for field in ("resultEvidence", "reportScreenshots", "secondary", "unavailable"):
            if not _path_list(artifacts.get(field)):
                errors.append(f"artifacts.{field} must be a nonempty-string array")
        result_evidence = artifacts.get("resultEvidence")
        report_screenshots = artifacts.get("reportScreenshots")
        if isinstance(result_evidence, list) and not result_evidence:
            missing.append("artifacts.resultEvidence")
        if isinstance(report_screenshots, list) and not report_screenshots:
            missing.append("artifacts.reportScreenshots")
        for field in ("resultEvidence", "reportScreenshots", "secondary"):
            paths = artifacts.get(field)
            if not isinstance(paths, list):
                continue
            for artifact in paths:
                if not _nonempty_string(artifact):
                    continue
                path, artifact_errors = _validate_tracked_artifact(
                    repo_root, tracked_paths, artifact, field
                )
                errors.extend(artifact_errors)
                if artifact_errors or path is None:
                    continue
                if field == "resultEvidence":
                    views = _read_retained_xcresult(path)
                    if views is None:
                        errors.append(
                            "artifacts.resultEvidence is not an inspectable xcresult"
                        )
                    else:
                        errors.extend(validate_xcresult_data(*views, document))
                if field == "reportScreenshots" and not _is_xcode_report_png(path):
                    errors.append(
                        "artifacts.reportScreenshots is not a well-formed Xcode report PNG"
                    )

    cleanup = document.get("cleanup")
    if not isinstance(cleanup, dict):
        errors.append("cleanup must be an object")
    else:
        measured = cleanup.get("measured")
        unverified = cleanup.get("unverifiedDimensions")
        if not isinstance(measured, dict):
            errors.append("cleanup.measured must be an object")
            measured_keys: set[str] = set()
        else:
            measured_keys = set(measured)
            for field, value in measured.items():
                if field in INTEGER_CLEANUP_DIMENSIONS:
                    if not isinstance(value, int) or isinstance(value, bool):
                        errors.append(f"cleanup.measured.{field} must be an integer")
                    elif value != 0:
                        errors.append(f"cleanup.measured.{field} must be 0")
                if field in BOOLEAN_CLEANUP_DIMENSIONS:
                    if not isinstance(value, bool):
                        errors.append(f"cleanup.measured.{field} must be boolean")
                    elif value:
                        errors.append(f"cleanup.measured.{field} must be false")
        if not _path_list(unverified):
            errors.append("cleanup.unverifiedDimensions must be a nonempty-string array")
            unverified_keys: set[str] = set()
        else:
            unverified_keys = set(unverified)
        unknown = (measured_keys | unverified_keys) - REQUIRED_CLEANUP_DIMENSIONS
        omitted = REQUIRED_CLEANUP_DIMENSIONS - (measured_keys | unverified_keys)
        overlap = measured_keys & unverified_keys
        if unknown:
            errors.append(f"cleanup contains unknown dimensions: {', '.join(sorted(unknown))}")
        if omitted:
            errors.append(f"cleanup omits dimensions: {', '.join(sorted(omitted))}")
        if overlap:
            errors.append(f"cleanup both measures and disclaims: {', '.join(sorted(overlap))}")
        missing.extend(f"cleanup.{field}" for field in sorted(unverified_keys))

    expected_missing = sorted(set(missing))
    if document.get("missingRequirements") != expected_missing:
        errors.append(
            "missingRequirements must exactly match unavailable proof: "
            + json.dumps(expected_missing)
        )

    expected_status = "red" if result_status == "failed-as-injected" else "partial"
    if document.get("evidenceStatus") != expected_status:
        errors.append(f"evidenceStatus must be {expected_status}")
    expected_role = "red-capability" if result_status == "failed-as-injected" else "focused-pass"
    if document.get("proofRole") != expected_role:
        errors.append(f"proofRole must be {expected_role} for result status {result_status}")
    return errors


def validate_overall_status(document: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if document.get("schemaVersion") != 1:
        errors.append("overall schemaVersion must be 1")
    if document.get("issue") != 13:
        errors.append("overall issue must be 13")
    gates = document.get("gates")
    if not isinstance(gates, dict):
        return errors + ["overall gates must be an object"]
    expected_gates = {
        "completeGoldenPlan": "red",
        "xcodeCloudConfigured": True,
        "xcodeCloudCleanRuns": 0,
        "xcodeCloudRequiredCleanRuns": 10,
        "installedAcceptance": "red",
        "installedArtifact": "evidence/issue-13-build-43-m3-install-proof.json",
    }
    if gates != expected_gates:
        errors.append("overall gates must match the current externally unverified red state")
    if document.get("overallStatus") == "green":
        errors.append(
            "overall green requires external live verification and is not accepted by this linter"
        )
    if document.get("overallStatus") != "red":
        errors.append("overallStatus must be red")
    return errors


def validate_cloud_summary(document: dict[str, Any], *, repo_root: Path) -> list[str]:
    """Validate the minimum reproducible facts for an Xcode Cloud test summary."""
    errors: list[str] = []
    if document.get("schemaVersion") != 2:
        errors.append("schemaVersion must be 2")

    run_id = document.get("runId")
    if not _nonempty_string(run_id):
        errors.append("runId is required")

    source_commit = document.get("sourceCommit")
    if not _nonempty_string(source_commit):
        errors.append("sourceCommit is required")
    elif not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        errors.append("sourceCommit must be a full lowercase Git SHA")
    elif not _git_commit_exists(repo_root, source_commit):
        errors.append("sourceCommit does not resolve to a commit")

    for field in ("plan", "action"):
        if not _nonempty_string(document.get(field)):
            errors.append(f"{field} is required")

    destination = document.get("destination")
    if not isinstance(destination, dict):
        errors.append("destination is required")
    else:
        for field in ("name", "platform", "osVersion"):
            if not _nonempty_string(destination.get(field)):
                errors.append(f"destination.{field} is required")

    counts: dict[str, int] = {}
    for field in ("passedTests", "failedTests", "skippedTests"):
        value = document.get(field)
        if value is None:
            errors.append(f"{field} is required")
        elif not isinstance(value, int) or isinstance(value, bool) or value < 0:
            errors.append(f"{field} must be a nonnegative integer")
        else:
            counts[field] = value

    duration = document.get("durationSeconds")
    if duration is None:
        errors.append("durationSeconds is required")
    elif not isinstance(duration, (int, float)) or isinstance(duration, bool) or duration <= 0:
        errors.append("durationSeconds must be positive")

    failures = document.get("failures")
    if failures is None:
        errors.append("failures is required")
    elif not isinstance(failures, list):
        errors.append("failures must be an array")
    else:
        valid_receipts = all(
            isinstance(failure, dict)
            and isinstance(failure.get("count"), int)
            and not isinstance(failure.get("count"), bool)
            and failure["count"] > 0
            and isinstance(failure.get("durationSecondsEach"), (int, float))
            and not isinstance(failure.get("durationSecondsEach"), bool)
            and failure["durationSecondsEach"] > 0
            and _nonempty_string(failure.get("summary"))
            for failure in failures
        )
        if not valid_receipts:
            errors.append(
                "each failure receipt requires positive count, durationSecondsEach, and summary"
            )
        failed_count = counts.get("failedTests")
        if failed_count and not failures:
            errors.append("failed cloud result requires failure receipts")
        if failed_count is not None and failures and valid_receipts:
            if sum(failure["count"] for failure in failures) != failed_count:
                errors.append("failure receipt counts must equal failedTests")
        if failed_count == 0 and failures:
            errors.append("passing cloud result must not include failure receipts")

    result = document.get("result")
    if result not in {"PASSED", "FAILED"}:
        errors.append("result must be PASSED or FAILED")
    elif result == "PASSED":
        if counts.get("failedTests") != 0:
            errors.append("PASSED cloud result must have failedTests=0")
        if counts.get("passedTests", 0) < 1:
            errors.append("PASSED cloud result must include at least one passed test")
    elif counts.get("failedTests", 0) < 1:
        errors.append("FAILED cloud result must include at least one failed test")

    if not _nonempty_string(document.get("resultArtifactId")):
        errors.append("resultArtifactId is required")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("proofs", nargs="*")
    args = parser.parse_args()
    repo_root = Path(__file__).resolve().parent.parent
    tracked_paths = _tracked_paths(repo_root)

    if args.proofs:
        try:
            proof_paths = [
                resolve_proof_path(repo_root, item).relative_to(repo_root).as_posix()
                for item in args.proofs
            ]
        except ValueError as error:
            print(f"ERROR: {error}", file=sys.stderr)
            return 64
    else:
        proof_paths = discover_proofs(tracked_paths)
    if not proof_paths:
        print("ERROR: no tracked Issue 13 proof JSON found", file=sys.stderr)
        return 1

    counts = {"complete": 0, "partial": 0, "red": 0}
    failed = False
    for proof_path in proof_paths:
        try:
            path = resolve_proof_path(
                repo_root, proof_path, expected_pattern=PROOF_PATTERN
            )
            document = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError, ValueError) as error:
            print(f"{proof_path}: ERROR: {error}", file=sys.stderr)
            failed = True
            continue
        errors = validate_document(document, repo_root=repo_root, tracked_paths=tracked_paths)
        if errors:
            failed = True
            for error in errors:
                print(f"{proof_path}: ERROR: {error}", file=sys.stderr)
        else:
            counts[document["evidenceStatus"]] += 1
            print(f"{proof_path}: {document['evidenceStatus'].upper()}")

    for cloud_path in discover_cloud_proofs(tracked_paths):
        try:
            path = resolve_proof_path(
                repo_root, cloud_path, expected_pattern=CLOUD_PROOF_PATTERN
            )
            document = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError, ValueError) as error:
            print(f"{cloud_path}: ERROR: {error}", file=sys.stderr)
            failed = True
            continue
        errors = validate_cloud_summary(document, repo_root=repo_root)
        if errors:
            failed = True
            for error in errors:
                print(f"{cloud_path}: ERROR: {error}", file=sys.stderr)
        else:
            print(f"{cloud_path}: CLOUD SUMMARY VALID")

    overall_path = repo_root / OVERALL_STATUS_PATH
    if OVERALL_STATUS_PATH not in tracked_paths:
        print(f"{OVERALL_STATUS_PATH}: ERROR: status input is not committed", file=sys.stderr)
        failed = True
    try:
        overall = json.loads(overall_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        print(f"{OVERALL_STATUS_PATH}: ERROR: {error}", file=sys.stderr)
        failed = True
        overall = {}
    overall_errors = validate_overall_status(overall)
    if overall_errors:
        failed = True
        for error in overall_errors:
            print(f"{OVERALL_STATUS_PATH}: ERROR: {error}", file=sys.stderr)
    elif overall:
        print(f"{OVERALL_STATUS_PATH}: {overall['overallStatus'].upper()}")

    if failed:
        return 1
    print(
        "Issue 13 evidence honesty lint: PASS "
        f"({counts['complete']} complete, {counts['partial']} partial, {counts['red']} red); "
        f"Issue 13 overall: {overall['overallStatus'].upper()}; "
        "completion authority: EXTERNAL-ONLY"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
