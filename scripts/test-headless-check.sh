#!/bin/zsh
set -euo pipefail

temp_parent=$(cd "${TMPDIR:-/tmp}" && pwd -P)

test -z "$(find Packages/GuideModules/Sources -type f -name '*UITest*' -print -quit)" || {
  print -u2 "UI-test composition leaked into a shipping package target"; exit 1
}
for fixture_source in GuideUITestComposition.swift UITestDictationAdapters.swift UITestGuideAdapters.swift UITestTalkAdapters.swift; do
  /usr/bin/grep -Fq "$fixture_source" project.yml || {
    print -u2 "$fixture_source is not excluded from Release"; exit 1
  }
done
/usr/bin/grep -Fq 'GuideCompanionCompositionTests' project.yml || {
  print -u2 "App composition contract target is missing"; exit 1
}
/usr/bin/grep -Fq 'precondition(mode == .production, "UI-test composition is unavailable in Release builds")' App/GuideCompanionApp.swift || {
  print -u2 "Release composition does not fail closed for --ui-testing"; exit 1
}
composition_invocation=$(/usr/bin/sed -n '/-scheme GuideCompanionCompositionTests/,/REGISTER_APP_WITH_LAUNCH_SERVICES=NO/p' scripts/run-headless-check.sh)
print -r -- "$composition_invocation" | /usr/bin/grep -Fq 'CODE_SIGNING_ALLOWED=NO' || {
  print -u2 "headless App composition tests require a developer certificate"; exit 1
}
print -r -- "$composition_invocation" | /usr/bin/grep -Fq 'CODE_SIGNING_REQUIRED=NO' || {
  print -u2 "headless App composition tests require signing"; exit 1
}

for check_name in core-tests app-build; do
  fixture_root=$(mktemp -d "$temp_parent/serpy-headless.XXXXXX")
  find "$fixture_root" -depth -delete
  set +e
  SERPY_HARNESS_ROOT=$fixture_root SERPY_INJECT_FAILURE=$check_name \
    scripts/run-headless-check.sh "$check_name" >/dev/null 2>&1
  run_status=$?
  set -e
  [[ $run_status -eq 86 ]] || { print -u2 "$check_name injected failure did not fail predictably"; exit 1; }
  [[ ! -e $fixture_root ]] || { print -u2 "$check_name left its owned temp root behind"; exit 1; }
done

traversal_base=$(mktemp -d "$temp_parent/serpy-headless.XXXXXX")
set +e
SERPY_HARNESS_ROOT="$traversal_base/../../serpy-runner-escape" \
  scripts/run-headless-check.sh core-tests >/dev/null 2>&1
traversal_status=$?
set -e
find "$traversal_base" -depth -delete
[[ $traversal_status -eq 64 ]] || { print -u2 "traversal-shaped root was not rejected"; exit 1; }

timeout_root=$(mktemp -d "$temp_parent/serpy-headless.XXXXXX")
find "$timeout_root" -depth -delete
timeout_marker=$(uuidgen)
set +e
SERPY_HARNESS_ROOT=$timeout_root SERPY_RUNNER_FIXTURE=ignore-term \
  SERPY_TEST_SESSION_ID=$timeout_marker SERPY_WALL_SECONDS=1 \
  scripts/run-headless-check.sh core-tests >/dev/null 2>&1
timeout_status=$?
set -e
[[ $timeout_status -eq 75 ]] || { print -u2 "TERM-ignoring fixture did not hit the budget"; exit 1; }
[[ ! -e $timeout_root ]] || { print -u2 "timed-out fixture root survived"; exit 1; }
! pgrep -f "[s]erpy-runner-fixture-$timeout_marker" >/dev/null || {
  print -u2 "TERM-ignoring descendant survived escalation"; exit 1
}

descendant_root=$(mktemp -d "$temp_parent/serpy-headless.XXXXXX")
find "$descendant_root" -depth -delete
descendant_marker=$(uuidgen)
set +e
SERPY_HARNESS_ROOT=$descendant_root SERPY_RUNNER_FIXTURE=leader-exits \
  SERPY_TEST_SESSION_ID=$descendant_marker SERPY_WALL_SECONDS=1 \
  scripts/run-headless-check.sh core-tests >/dev/null 2>&1
descendant_status=$?
set -e
[[ $descendant_status -eq 75 ]] || { print -u2 "leader-exit descendant did not hit the budget"; exit 1; }
[[ ! -e $descendant_root ]] || { print -u2 "leader-exit fixture root survived"; exit 1; }
! pgrep -f "[s]erpy-runner-fixture-$descendant_marker" >/dev/null || {
  print -u2 "descendant survived after its leader exited"; exit 1
}

interrupt_root=$(mktemp -d "$temp_parent/serpy-headless.XXXXXX")
find "$interrupt_root" -depth -delete
interrupt_marker=$(uuidgen)
SERPY_HARNESS_ROOT=$interrupt_root SERPY_RUNNER_FIXTURE=ignore-term \
  SERPY_TEST_SESSION_ID=$interrupt_marker SERPY_WALL_SECONDS=60 \
  scripts/run-headless-check.sh core-tests >/dev/null 2>&1 &
runner_pid=$!
for _ in {1..30}; do
  pgrep -f "[s]erpy-runner-fixture-$interrupt_marker" >/dev/null && break
  sleep 0.1
done
kill -TERM "$runner_pid"
set +e
wait "$runner_pid"
interrupt_status=$?
set -e
[[ $interrupt_status -eq 143 ]] || { print -u2 "interrupted runner returned $interrupt_status"; exit 1; }
[[ ! -e $interrupt_root ]] || { print -u2 "interrupted fixture root survived"; exit 1; }
! pgrep -f "[s]erpy-runner-fixture-$interrupt_marker" >/dev/null || {
  print -u2 "interrupted descendant survived teardown"; exit 1
}

print "headless runner rejection, red-capability, escalation, and cleanup: PASS"
