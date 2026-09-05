#!/usr/bin/python3
"""Prove the full golden plan explicitly selects every golden UI test once."""

import json
import re
import sys
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parent.parent
PLAN_PATH = REPOSITORY_ROOT / "GuideCompanionGolden.xctestplan"
GOLDEN_SOURCES = (
    REPOSITORY_ROOT / "GuideCompanionUITests/GoldenPermissionsAndLifecycleUITests.swift",
    REPOSITORY_ROOT / "GuideCompanionUITests/GoldenDictationUITests.swift",
    REPOSITORY_ROOT / "GuideCompanionUITests/GoldenGuideUITests.swift",
)
CLASS_PATTERN = re.compile(r"final\s+class\s+(Golden\w+UITests)\s*:\s*GoldenUITestCase")
TEST_PATTERN = re.compile(r"\bfunc\s+(test_GT_[A-Za-z0-9_]+)\s*\(")


def fail(message: str) -> None:
    print(f"golden plan selection: FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def discover_source_tests() -> list[str]:
    discovered: list[str] = []
    for source_path in GOLDEN_SOURCES:
        source = source_path.read_text(encoding="utf-8")
        classes = CLASS_PATTERN.findall(source)
        if len(classes) != 1:
            fail(f"expected one golden test class in {source_path.name}, found {len(classes)}")
        class_name = classes[0]
        methods = TEST_PATTERN.findall(source)
        if not methods:
            fail(f"found no golden test methods in {source_path.name}")
        discovered.extend(f"{class_name}/{method}()" for method in methods)
    if len(discovered) != len(set(discovered)):
        fail("source declares a duplicate golden test identifier")
    return sorted(discovered)


def selected_plan_tests() -> list[str]:
    plan = json.loads(PLAN_PATH.read_text(encoding="utf-8"))
    targets = plan.get("testTargets")
    if not isinstance(targets, list) or len(targets) != 1:
        fail("full plan must contain exactly one test target")
    target = targets[0]
    if target.get("target", {}).get("name") != "GuideCompanionUITests":
        fail("full plan target must be GuideCompanionUITests")
    selected = target.get("selectedTests")
    if not isinstance(selected, list) or not selected:
        fail("GuideCompanionUITests must declare a nonempty selectedTests array")
    if target.get("skippedTests"):
        fail("full plan must not skip selected golden tests")
    if not all(isinstance(identifier, str) for identifier in selected):
        fail("selectedTests must contain only string identifiers")
    if len(selected) != len(set(selected)):
        duplicates = sorted({identifier for identifier in selected if selected.count(identifier) > 1})
        fail(f"selectedTests contains duplicates: {', '.join(duplicates)}")
    return sorted(selected)


source_tests = discover_source_tests()
plan_tests = selected_plan_tests()
missing = sorted(set(source_tests) - set(plan_tests))
extra = sorted(set(plan_tests) - set(source_tests))
if missing or extra:
    details = []
    if missing:
        details.append(f"missing: {', '.join(missing)}")
    if extra:
        details.append(f"extra: {', '.join(extra)}")
    fail("; ".join(details))

print(f"golden plan explicit selection: PASS ({len(source_tests)} tests)")
