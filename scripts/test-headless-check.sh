#!/bin/zsh
set -euo pipefail

for check_name in core-tests app-build; do
  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/serpy-headless.XXXXXX")
  find "$fixture_root" -depth -delete

  set +e
  SERPY_HARNESS_ROOT=$fixture_root SERPY_INJECT_FAILURE=$check_name \
    scripts/run-headless-check.sh "$check_name" >/dev/null 2>&1
  run_status=$?
  set -e

  [[ $run_status -eq 86 ]] || { print -u2 "$check_name injected failure did not fail predictably"; exit 1; }
  [[ ! -e $fixture_root ]] || { print -u2 "$check_name left its owned temp root behind"; exit 1; }
done
print "headless runner red-capability and cleanup: PASS"
