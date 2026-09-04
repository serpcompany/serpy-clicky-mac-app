#!/bin/zsh
set -euo pipefail

mode=${1:-}
selection=${2:-}
result_path=${3:-}
if [[ "$mode" != focused || -z "$selection" || -z "$result_path" ]]; then
  print -u2 "usage: $0 focused <test-id> <evidence/issue-13-*.xcresult>"
  exit 64
fi

repo_root=$(cd "${0:A:h}/.." && pwd -P)
result_path=${result_path:A}
case "$result_path" in
  "$repo_root"/evidence/issue-13-*.xcresult) ;;
  *) print -u2 "result must be a new evidence/issue-13-*.xcresult path"; exit 64 ;;
esac
[[ ! -e "$result_path" ]] || { print -u2 "result already exists"; exit 64; }
! pgrep -f '/SERPy.app/Contents/MacOS/SERPy|GuideCompanionUITests-Runner' >/dev/null || {
  print -u2 "a serpy or XCUI process is already running"; exit 75
}

temp_parent=$(cd /private/tmp && pwd -P)
run_root=$(mktemp -d "$temp_parent/serpy-local-xcui.XXXXXX")
if [[ ${SERPY_UI_RUNNER_FIXTURE:-} == external-session-timeout && -n ${SERPY_UI_FIXTURE_RUN_TOKEN:-} ]]; then
  run_token=$SERPY_UI_FIXTURE_RUN_TOKEN
else
  run_token=$(uuidgen)
fi
/usr/bin/printf '%s' "$run_token" > "$run_root/.serpy-local-xcui-owner"
owned_pgid=""
owned_leader=""
launch_services=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister
wall_seconds=${SERPY_UI_WALL_SECONDS:-900}
disk_budget_kib=${SERPY_UI_DISK_KIB:-8388608}
disk_usage_command=/usr/bin/du
if [[ ${SERPY_UI_RUNNER_FIXTURE:-} == disk-measurement-race ]]; then
  disk_usage_command="$run_root/du-race-fixture"
  /usr/bin/printf '%s\n' '#!/bin/zsh' \
    'root=${@[-1]}' \
    'counter_file="$root/.du-race-count"' \
    'if [[ -f "$counter_file" ]]; then count=$(<"$counter_file"); else count=0; fi' \
    'count=$((count + 1))' \
    'print -n "$count" > "$counter_file"' \
    '(( count < 3 )) && exit 1' \
    'exec /usr/bin/du "$@"' > "$disk_usage_command"
  /bin/chmod 700 "$disk_usage_command"
fi

terminate_owned_group() {
  [[ -n "$owned_pgid" ]] || return 0
  local process_group=$owned_pgid
  local leader=$owned_leader
  kill -TERM -- -"$process_group" 2>/dev/null || true
  for _ in {1..25}; do
    kill -0 -- -"$process_group" 2>/dev/null || break
    sleep 0.2
  done
  if kill -0 -- -"$process_group" 2>/dev/null; then
    kill -KILL -- -"$process_group" 2>/dev/null || true
  fi
  [[ -n "$leader" ]] && wait "$leader" 2>/dev/null || true
  for _ in {1..25}; do
    kill -0 -- -"$process_group" 2>/dev/null || break
    sleep 0.2
  done
  if kill -0 -- -"$process_group" 2>/dev/null; then
    print -u2 "owned UI process group survived teardown: $process_group"
    return 1
  fi
  owned_pgid=""
  owned_leader=""
}

approved_xctest_temporary_roots() {
  local root container_root canonical_root
  local darwin_temp=$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)
  local roots=("$darwin_temp")
  for container_root in \
    "$HOME/Library/Containers/com.serpcompany.guidecompanion.internal.uitests/Data/tmp" \
    "$HOME/Library/Containers/com.serpcompany.guidecompanion.internal.uitests.xctrunner/Data/tmp"; do
    roots+=("$container_root")
  done
  for root in "${roots[@]}"; do
    canonical_root=$(/bin/realpath "$root" 2>/dev/null) || continue
    [[ -d "$canonical_root" ]] && print -r -- "$canonical_root"
  done
}

cleanup_xctest_session() {
  local session_name="serpy-xctest-session.${run_token//-/}"
  local approved_root candidate owner
  while IFS= read -r approved_root; do
    [[ -n "$approved_root" ]] || continue
    candidate="$approved_root/$session_name"
    [[ -d "$candidate" && ! -L "$candidate" ]] || continue
    [[ $(cd "$candidate" && pwd -P) == "$candidate" ]] || {
      print -u2 "refusing noncanonical XCTest session: $candidate"
      return 1
    }
    owner=$(<"$candidate/.serpy-xctest-run-owner" 2>/dev/null) || {
      print -u2 "refusing unowned XCTest session: $candidate"
      return 1
    }
    [[ "$owner" == "$run_token" ]] || {
      print -u2 "refusing mismatched XCTest session: $candidate"
      return 1
    }
    /bin/chmod -RN "$candidate" 2>/dev/null || true
    /usr/bin/find "$candidate" -depth -delete 2>/dev/null || true
    [[ ! -e "$candidate" ]] || {
      print -u2 "owned XCTest session survived teardown: $candidate"
      return 1
    }
  done < <(approved_xctest_temporary_roots)
}

cleanup() {
  local original_status=${1:-0}
  trap - EXIT
  terminate_owned_group || true
  local cleanup_failed=false
  cleanup_xctest_session || cleanup_failed=true
  local app
  for app in "$run_root/DerivedData/Build/Products/Debug/SERPy.app" "$run_root/DerivedData/Build/Products/Debug/GuideCompanionUITests-Runner.app"; do
    [[ -d "$app" ]] && "$launch_services" -u "$app" 2>/dev/null || true
  done
  for _ in {1..5}; do
    /bin/chmod -RN "$run_root" 2>/dev/null || true
    find "$run_root" -depth -delete 2>/dev/null || true
    [[ ! -e "$run_root" ]] && break
    sleep 0.5
  done
  if [[ -e "$run_root" ]]; then
    if [[ ${SERPY_UI_RUNNER_FIXTURE:-} == command-fails-top-level && -n ${SERPY_UI_CLEANUP_MARKER:-} ]]; then
      /usr/bin/printf '%s' "cleanup-failed status=$original_status root-absent=false" > "$SERPY_UI_CLEANUP_MARKER"
    fi
    print -u2 "owned UI run root survived teardown: $run_root"
    exit 74
  fi
  if [[ "$cleanup_failed" == true ]]; then
    print -u2 "XCTest session cleanup failed"
    exit 74
  fi
  if [[ ${SERPY_UI_RUNNER_FIXTURE:-} == command-fails-top-level && -n ${SERPY_UI_CLEANUP_MARKER:-} ]]; then
    /usr/bin/printf '%s' "cleanup-complete status=$original_status root-absent=true" > "$SERPY_UI_CLEANUP_MARKER"
  fi
  exit "$original_status"
}
trap 'cleanup $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

run_bounded() {
  local started_at=$SECONDS
  perl -MPOSIX -e 'defined POSIX::setsid() or die "setsid failed"; exec @ARGV or die "exec failed"' -- "$@" &
  owned_leader=$!
  owned_pgid=$owned_leader
  local session_ready=false
  for _ in {1..50}; do
    if kill -0 -- -"$owned_pgid" 2>/dev/null; then
      session_ready=true
      break
    fi
    kill -0 "$owned_leader" 2>/dev/null || break
    sleep 0.02
  done
  if [[ "$session_ready" != true ]]; then
    local early_status
    if wait "$owned_leader"; then early_status=0; else early_status=$?; fi
    owned_pgid=""
    owned_leader=""
    return "$early_status"
  fi
  while kill -0 -- -"$owned_pgid" 2>/dev/null; do
    sleep 2
    local used_kib=""
    local measurement=""
    for _ in {1..3}; do
      measurement=$($disk_usage_command -sk "$run_root" 2>/dev/null) || measurement=""
      used_kib=${measurement%%[[:space:]]*}
      [[ "$used_kib" == <-> ]] && break
      used_kib=""
      sleep 0.1
    done
    if [[ -z "$used_kib" ]]; then
      print -u2 "disk usage measurement unavailable after 3 attempts"
      terminate_owned_group
      return 75
    fi
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
  if wait "$owned_leader"; then child_status=0; else child_status=$?; fi
  if kill -0 -- -"$owned_pgid" 2>/dev/null; then
    terminate_owned_group
    return 75
  fi
  owned_pgid=""
  owned_leader=""
  return "$child_status"
}

if [[ ${SERPY_UI_RUNNER_FIXTURE:-} == ignore-term ]]; then
  fixture_marker=${SERPY_TEST_SESSION_ID:-missing-session}
  if run_bounded /bin/zsh -c 'trap "" TERM; while true; do sleep 1; done' "serpy-ui-runner-$fixture_marker"; then exit 0; else exit $?; fi
fi

if [[ ${SERPY_UI_RUNNER_FIXTURE:-} == leader-exits ]]; then
  fixture_marker=${SERPY_TEST_SESSION_ID:-missing-session}
  if run_bounded /bin/zsh -c '(trap "" TERM; while true; do sleep 1; done) & exit 0' "serpy-ui-runner-$fixture_marker"; then exit 0; else exit $?; fi
fi

if [[ ${SERPY_UI_RUNNER_FIXTURE:-} == external-session-timeout ]]; then
  fixture_marker=${SERPY_TEST_SESSION_ID:-missing-session}
  session_name="serpy-xctest-session.${run_token//-/}"
  while IFS= read -r approved_root; do
    [[ -n "$approved_root" ]] || continue
    /bin/mkdir "$approved_root/$session_name"
    /usr/bin/printf '%s' "$run_token" > "$approved_root/$session_name/.serpy-xctest-run-owner"
    /usr/bin/printf '%s' keep > "$approved_root/serpy-unrelated-$run_token"
  done < <(approved_xctest_temporary_roots)
  if run_bounded /bin/zsh -c 'trap "" TERM; while true; do sleep 1; done' "serpy-ui-runner-$fixture_marker"; then exit 0; else exit $?; fi
fi

if [[ ${SERPY_UI_RUNNER_FIXTURE:-} == command-fails-top-level ]]; then
  fixture_marker=${SERPY_TEST_SESSION_ID:-missing-session}
  ui_command=(/bin/zsh -c '
    /bin/mkdir -p "$1/DerivedData/Build/Products/Debug"
    /bin/dd if=/dev/zero of="$1/DerivedData/Build/Products/Debug/nonzero.fixture" bs=1 count=0 seek=3758096384 2>/dev/null
    for directory in {1..64}; do
      /bin/mkdir -p "$1/DerivedData/Build/Intermediates.noindex/$directory"
      for file in {1..64}; do
        : > "$1/DerivedData/Build/Intermediates.noindex/$directory/$file"
      done
    done
    exit 65
  ' "serpy-ui-runner-$fixture_marker" "$run_root")
elif [[ ${SERPY_UI_RUNNER_FIXTURE:-} == disk-measurement-race ]]; then
  fixture_marker=${SERPY_TEST_SESSION_ID:-missing-session}
  ui_command=(/bin/zsh -c 'sleep 4; exit 65' "serpy-ui-runner-$fixture_marker")
else
  ui_command=(/usr/bin/env TEST_RUNNER_SERPY_XCUI_RUN_TOKEN="$run_token" xcodebuild test -quiet -project GuideCompanion.xcodeproj -scheme GuideCompanion -testPlan GuideCompanionGolden -destination 'platform=macOS,arch=arm64' -derivedDataPath "$run_root/DerivedData" -clonedSourcePackagesDirPath "$run_root/SourcePackages" -resultBundlePath "$result_path" "-only-testing:$selection")
fi
if run_bounded "${ui_command[@]}"; then
  exit 0
else
  exit $?
fi
