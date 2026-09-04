#!/bin/zsh
set -euo pipefail

check_name=${1:-all}
case "$check_name" in
  core-tests|app-build|all) ;;
  *) print -u2 "unknown check: $check_name"; exit 64 ;;
esac

temp_parent=$(cd "${TMPDIR:-/tmp}" && pwd -P)
if [[ -n ${SERPY_HARNESS_ROOT:-} ]]; then
  requested_root=$SERPY_HARNESS_ROOT
  root_parent=${requested_root:h}
  root_name=${requested_root:t}
  if [[ "$requested_root" == *"/../"* || "$requested_root" == *"/./"* || -L "$requested_root" ]]; then
    print -u2 "SERPY_HARNESS_ROOT must not contain traversal or be a symlink"
    exit 64
  fi
  canonical_parent=$(cd "$root_parent" 2>/dev/null && pwd -P) || {
    print -u2 "SERPY_HARNESS_ROOT parent must already exist"
    exit 64
  }
  if [[ "$canonical_parent" != "$temp_parent" || ! "$root_name" =~ '^serpy-headless\.[A-Za-z0-9]+$' ]]; then
    print -u2 "SERPY_HARNESS_ROOT must be a direct, owned child of the OS temp directory"
    exit 64
  fi
  run_root="$temp_parent/$root_name"
  mkdir "$run_root"
else
  run_root=$(mktemp -d "$temp_parent/serpy-headless.XXXXXX")
fi

owned_pgid=""
launch_services=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister
wall_seconds=${SERPY_WALL_SECONDS:-1800}
disk_budget_kib=${SERPY_DISK_BUDGET_KIB:-8388608}

terminate_owned_group() {
  [[ -n "$owned_pgid" ]] || return 0
  local process_group=$owned_pgid
  kill -TERM -- -"$process_group" 2>/dev/null || true
  for _ in {1..25}; do
    kill -0 -- -"$process_group" 2>/dev/null || break
    sleep 0.2
  done
  if kill -0 -- -"$process_group" 2>/dev/null; then
    kill -KILL -- -"$process_group" 2>/dev/null || true
  fi
  wait "$process_group" 2>/dev/null || true
  for _ in {1..25}; do
    kill -0 -- -"$process_group" 2>/dev/null || break
    sleep 0.2
  done
  if kill -0 -- -"$process_group" 2>/dev/null; then
    print -u2 "owned process group survived teardown: $process_group"
    return 1
  fi
  owned_pgid=""
}

cleanup() {
  terminate_owned_group || true
  local built_app
  for built_app in \
    "$run_root/derived-data/Build/Products/Debug/SERPy.app" \
    "$run_root/derived-data-golden/Build/Products/Debug/SERPy.app"; do
    if [[ -d "$built_app" ]]; then
      "$launch_services" -u "$built_app" 2>/dev/null || true
    fi
  done
  find "$run_root" -depth -delete 2>/dev/null || true
  rmdir "$run_root" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

run_bounded() {
  local started_at=$SECONDS
  perl -MPOSIX -e 'defined POSIX::setsid() or die "setsid failed"; exec @ARGV or die "exec failed"' -- "$@" &
  owned_pgid=$!
  local session_ready=false
  for _ in {1..50}; do
    if kill -0 -- -"$owned_pgid" 2>/dev/null; then
      session_ready=true
      break
    fi
    kill -0 "$owned_pgid" 2>/dev/null || break
    sleep 0.02
  done
  if [[ "$session_ready" != true ]]; then
    local early_status
    if wait "$owned_pgid"; then early_status=0; else early_status=$?; fi
    owned_pgid=""
    return "$early_status"
  fi
  while kill -0 -- -"$owned_pgid" 2>/dev/null; do
    sleep 2
    local used_kib=$(du -sk "$run_root" | awk '{print $1}')
    if (( used_kib > disk_budget_kib )); then
      print -u2 "disk budget exceeded: ${used_kib} KiB"
      terminate_owned_group
      return 75
    fi
    if (( SECONDS - started_at > wall_seconds )); then
      print -u2 "wall-clock budget exceeded: ${wall_seconds} seconds"
      terminate_owned_group
      return 75
    fi
  done
  local child_status
  if wait "$owned_pgid"; then child_status=0; else child_status=$?; fi
  if kill -0 -- -"$owned_pgid" 2>/dev/null; then
    terminate_owned_group
    return 75
  fi
  owned_pgid=""
  return "$child_status"
}

if [[ ${SERPY_INJECT_FAILURE:-} == "$check_name" || (${SERPY_INJECT_FAILURE:-} == all && "$check_name" == all) ]]; then
  print -u2 "deliberate injected failure: $check_name"
  exit 86
fi

if [[ ${SERPY_RUNNER_FIXTURE:-} == ignore-term ]]; then
  fixture_marker=${SERPY_TEST_SESSION_ID:-missing-session}
  if run_bounded /bin/zsh -c 'trap "" TERM; while true; do sleep 1; done' "serpy-runner-fixture-$fixture_marker"; then
    exit 0
  else
    fixture_status=$?
    exit "$fixture_status"
  fi
fi

if [[ ${SERPY_RUNNER_FIXTURE:-} == leader-exits ]]; then
  fixture_marker=${SERPY_TEST_SESSION_ID:-missing-session}
  if run_bounded /bin/zsh -c '(trap "" TERM; while true; do sleep 1; done) & exit 0' "serpy-runner-fixture-$fixture_marker"; then
    exit 0
  else
    fixture_status=$?
    exit "$fixture_status"
  fi
fi

run_core_tests() {
  run_bounded swift test \
    --package-path Packages/GuideModules \
    --scratch-path "$run_root/swiftpm" \
    --disable-automatic-resolution
}

run_app_build() {
  run_bounded xcodebuild build \
    -project GuideCompanion.xcodeproj \
    -scheme GuideCompanion \
    -configuration Debug \
    -derivedDataPath "$run_root/derived-data" \
    -clonedSourcePackagesDirPath "$run_root/source-packages" \
    -disableAutomaticPackageResolution \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    REGISTER_APP_WITH_LAUNCH_SERVICES=NO
  run_bounded xcodebuild build-for-testing \
    -project GuideCompanion.xcodeproj \
    -scheme GuideCompanion \
    -testPlan GuideCompanionGolden \
    -configuration Debug \
    -derivedDataPath "$run_root/derived-data-golden" \
    -clonedSourcePackagesDirPath "$run_root/source-packages-golden" \
    -disableAutomaticPackageResolution \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    REGISTER_APP_WITH_LAUNCH_SERVICES=NO
}

run_selected_check() {
  case "$check_name" in
    core-tests) run_core_tests ;;
    app-build) run_app_build ;;
    all) run_core_tests; run_app_build ;;
  esac
}

if run_selected_check; then
  exit 0
else
  run_status=$?
  exit "$run_status"
fi
