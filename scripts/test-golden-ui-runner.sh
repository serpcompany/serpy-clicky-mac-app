#!/bin/zsh
set -euo pipefail

assert_clean() {
  local marker=$1
  local result=$2
  [[ ! -e "$result" ]] || { print -u2 "UI runner fixture wrote a result"; exit 1; }
  ! pgrep -f "[s]erpy-ui-runner-$marker" >/dev/null || { print -u2 "UI runner descendant survived"; exit 1; }
  test -z "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'serpy-local-xcui.*' -print -quit)"
}

for fixture in ignore-term leader-exits; do
  marker=$(uuidgen)
  result="evidence/issue-13-runner-fixture-$marker.xcresult"
  set +e
  SERPY_UI_RUNNER_FIXTURE=$fixture SERPY_TEST_SESSION_ID=$marker SERPY_UI_WALL_SECONDS=1 \
    scripts/run-golden-ui-test.sh focused GuideCompanionUITests/Fixture/never "$result" >/dev/null 2>&1
  run_status=$?
  set -e
  [[ $run_status -eq 75 ]] || { print -u2 "$fixture fixture returned $run_status"; exit 1; }
  assert_clean "$marker" "$result"
done

marker=$(uuidgen)
result="evidence/issue-13-runner-fixture-$marker.xcresult"
SERPY_UI_RUNNER_FIXTURE=ignore-term SERPY_TEST_SESSION_ID=$marker SERPY_UI_WALL_SECONDS=60 \
  scripts/run-golden-ui-test.sh focused GuideCompanionUITests/Fixture/never "$result" >/dev/null 2>&1 &
runner_pid=$!
for _ in {1..30}; do
  pgrep -f "[s]erpy-ui-runner-$marker" >/dev/null && break
  sleep 0.1
done
kill -TERM "$runner_pid"
set +e
wait "$runner_pid"
interrupt_status=$?
set -e
[[ $interrupt_status -eq 143 ]] || { print -u2 "interrupted runner returned $interrupt_status"; exit 1; }
assert_clean "$marker" "$result"

set +e
scripts/run-golden-ui-test.sh full GuideCompanionUITests/Fixture/never evidence/issue-13-forbidden.xcresult >/dev/null 2>&1
full_status=$?
scripts/run-golden-ui-test.sh focused GuideCompanionUITests/Fixture/never /tmp/issue-13-forbidden.xcresult >/dev/null 2>&1
path_status=$?
set -e
[[ $full_status -eq 64 ]] || { print -u2 "local full-suite mode was not rejected"; exit 1; }
[[ $path_status -eq 64 ]] || { print -u2 "outside result path was not rejected"; exit 1; }

print "golden UI runner rejection, timeout, interrupt, descendant, and cleanup: PASS"
