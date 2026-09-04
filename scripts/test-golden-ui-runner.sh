#!/bin/zsh
set -euo pipefail

marker=$(uuidgen)
result="evidence/issue-13-runner-fixture-$marker.xcresult"
set +e
SERPY_UI_RUNNER_FIXTURE=ignore-term SERPY_TEST_SESSION_ID=$marker SERPY_UI_WALL_SECONDS=1 \
  scripts/run-golden-ui-test.sh focused GuideCompanionUITests/Fixture/never "$result" >/dev/null 2>&1
run_status=$?
set -e
[[ $run_status -eq 75 ]] || { print -u2 "UI runner timeout fixture returned $run_status"; exit 1; }
[[ ! -e $result ]] || { print -u2 "UI runner fixture wrote a result"; exit 1; }
! pgrep -f "[s]erpy-ui-runner-$marker" >/dev/null || { print -u2 "UI runner descendant survived"; exit 1; }
test -z "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'serpy-local-xcui.*' -print -quit)"
print "golden UI runner timeout and cleanup: PASS"
