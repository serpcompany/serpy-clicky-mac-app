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

temp_parent=$(cd "${TMPDIR:-/tmp}" && pwd -P)
run_root=$(mktemp -d "$temp_parent/serpy-local-xcui.XXXXXX")
owned_pgid=""
owned_leader=""
launch_services=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister
wall_seconds=${SERPY_UI_WALL_SECONDS:-900}
disk_budget_kib=${SERPY_UI_DISK_KIB:-8388608}

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

cleanup() {
  terminate_owned_group || true
  local app
  for app in "$run_root/DerivedData/Build/Products/Debug/SERPy.app" "$run_root/DerivedData/Build/Products/Debug/GuideCompanionUITests-Runner.app"; do
    [[ -d "$app" ]] && "$launch_services" -u "$app" 2>/dev/null || true
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

ui_command=(xcodebuild test -quiet -project GuideCompanion.xcodeproj -scheme GuideCompanion -testPlan GuideCompanionGolden -destination 'platform=macOS,arch=arm64' -derivedDataPath "$run_root/DerivedData" -clonedSourcePackagesDirPath "$run_root/SourcePackages" -resultBundlePath "$result_path" "-only-testing:$selection")
run_bounded "${ui_command[@]}"
