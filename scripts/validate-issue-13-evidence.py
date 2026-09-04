#!/usr/bin/env python3
"""Validate that Issue 13 proof summaries describe their limits honestly."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


DEFAULT_PROOFS = (
    "evidence/issue-13-real-app-UF08-injected-red-m3-proof.json",
    "evidence/issue-13-real-app-UF12-m3-run3-proof.json",
)

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


def validate_document(
    document: dict[str, Any],
    *,
    repo_root: Path,
    tracked_paths: set[str],
) -> list[str]:
    errors: list[str] = []

    if document.get("schemaVersion") != 2:
        errors.append("schemaVersion must be 2")
    if document.get("issue") != 13:
        errors.append("issue must be 13")
    if not re.fullmatch(r"GT-UF\d{2}-\d{3}", str(document.get("testId", ""))):
        errors.append("testId must be a GT-UF test ID")
    if not _nonempty_string(document.get("xcodeTestIdentifier")):
        errors.append("xcodeTestIdentifier is required")
    if not _nonempty_string(document.get("testPlan")):
        errors.append("testPlan is required")
    if not _nonempty_string(document.get("testPlanConfiguration")):
        errors.append("testPlanConfiguration is required")

    missing: list[str] = []
    tested_commit = document.get("testedCommit")
    if tested_commit is None:
        missing.append("testedCommit")
    elif not re.fullmatch(r"[0-9a-f]{40}", str(tested_commit)):
        errors.append("testedCommit must be a full lowercase Git SHA or null")

    destination = document.get("destination")
    if not isinstance(destination, dict):
        errors.append("destination must be an object")
    else:
        for field in ("platform", "architecture", "osVersion", "osBuildNumber"):
            if not _nonempty_string(destination.get(field)):
                errors.append(f"destination.{field} is required")

    result = document.get("result")
    failed = None
    if not isinstance(result, dict):
        errors.append("result must be an object")
    else:
        if not _nonempty_string(result.get("status")):
            errors.append("result.status is required")
        counts: dict[str, int] = {}
        for field in ("executed", "passed", "failed", "skipped"):
            value = result.get(field)
            if not isinstance(value, int) or isinstance(value, bool) or value < 0:
                errors.append(f"result.{field} must be a nonnegative integer")
            else:
                counts[field] = value
        if len(counts) == 4 and counts["executed"] != (
            counts["passed"] + counts["failed"] + counts["skipped"]
        ):
            errors.append("result counts do not add up to executed")
        failed = counts.get("failed")
        duration = result.get("durationSeconds")
        if duration is None:
            missing.append("result.durationSeconds")
        elif (
            not isinstance(duration, (int, float))
            or isinstance(duration, bool)
            or duration <= 0
        ):
            errors.append("result.durationSeconds must be positive or null")

    failures = document.get("failures")
    if not isinstance(failures, list):
        errors.append("failures must be an array")
    elif not all(isinstance(item, dict) and item for item in failures):
        errors.append("each failures entry must be a nonempty object")
    elif failed and not failures:
        missing.append("failures")

    artifacts = document.get("artifacts")
    if not isinstance(artifacts, dict):
        errors.append("artifacts must be an object")
    else:
        primary = artifacts.get("primary")
        secondary = artifacts.get("secondary")
        unavailable = artifacts.get("unavailable")
        if not _path_list(primary):
            errors.append("artifacts.primary must be an array of repo-relative paths")
        elif not primary:
            missing.append("artifacts.primary")
        if not _path_list(secondary):
            errors.append("artifacts.secondary must be an array of repo-relative paths")
        if not _path_list(unavailable):
            errors.append("artifacts.unavailable must be a nonempty-string array")
        for field, paths in (("primary", primary), ("secondary", secondary)):
            if not isinstance(paths, list):
                continue
            for artifact in paths:
                if not _nonempty_string(artifact):
                    continue
                if artifact.startswith("/") or ".." in Path(artifact).parts:
                    errors.append(f"artifacts.{field} path is not repo-relative: {artifact}")
                elif artifact not in tracked_paths:
                    errors.append(f"artifacts.{field} is not committed: {artifact}")
                elif not (repo_root / artifact).is_file():
                    errors.append(f"artifacts.{field} does not exist: {artifact}")

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
                if field in INTEGER_CLEANUP_DIMENSIONS and (
                    not isinstance(value, int) or isinstance(value, bool) or value < 0
                ):
                    errors.append(f"cleanup.measured.{field} must be a nonnegative integer")
                if field in BOOLEAN_CLEANUP_DIMENSIONS and not isinstance(value, bool):
                    errors.append(f"cleanup.measured.{field} must be boolean")
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
    declared_missing = document.get("missingRequirements")
    if declared_missing != expected_missing:
        errors.append(
            "missingRequirements must exactly match unavailable proof: "
            + json.dumps(expected_missing)
        )

    evidence_status = document.get("evidenceStatus")
    result_status = result.get("status") if isinstance(result, dict) else None
    expected_status = (
        "red"
        if isinstance(result_status, str) and result_status.startswith("failed")
        else "partial"
        if expected_missing
        else "complete"
    )
    if evidence_status != expected_status:
        errors.append(f"evidenceStatus must be {expected_status}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("proofs", nargs="*", default=list(DEFAULT_PROOFS))
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    tracked_paths = _tracked_paths(repo_root)
    counts = {"complete": 0, "partial": 0, "red": 0}
    failed = False

    for proof_path in args.proofs:
        path = repo_root / proof_path
        try:
            document = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError) as error:
            print(f"{proof_path}: ERROR: {error}", file=sys.stderr)
            failed = True
            continue
        errors = validate_document(
            document, repo_root=repo_root, tracked_paths=tracked_paths
        )
        if errors:
            failed = True
            for error in errors:
                print(f"{proof_path}: ERROR: {error}", file=sys.stderr)
        else:
            counts[document["evidenceStatus"]] += 1
            print(f"{proof_path}: {document['evidenceStatus'].upper()}")

    if failed:
        return 1
    print(
        "Issue 13 evidence contract: PASS "
        f"({counts['complete']} complete, {counts['partial']} partial, {counts['red']} red)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
