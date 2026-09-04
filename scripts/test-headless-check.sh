#!/bin/zsh
set -euo pipefail

fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/serpy-headless.XXXXXX")
find "$fixture_root" -depth -delete

set +e
SERPY_HARNESS_ROOT=$fixture_root SERPY_INJECT_FAILURE=core-tests \
  scripts/run-headless-check.sh core-tests >/dev/null 2>&1
run_status=$?
set -e

[[ $run_status -eq 86 ]] || { print -u2 "injected failure did not fail predictably"; exit 1; }
[[ ! -e $fixture_root ]] || { print -u2 "runner left its owned temp root behind"; exit 1; }
print "headless runner red-capability and cleanup: PASS"
