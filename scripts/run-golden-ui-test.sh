#!/bin/zsh
set -euo pipefail

mode=${1:-}
selection=${2:-}
result_path=${3:-}
if [[ "$mode" == full ]]; then
  result_path=$selection
  selection=""
elif [[ "$mode" != focused || -z "$selection" ]]; then
  print -u2 "usage: $0 focused <test-id> <evidence/*.xcresult> | full <evidence/*.xcresult>"
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
launch_services=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister

stop_group() {
  [[ -n "$owned_pgid" ]] || return 0
  local group=$owned_pgid
  kill -TERM -- -"$group" 2>/dev/null || true
  for _ in {1..25}; do kill -0 -- -"$group" 2>/dev/null || break; sleep 0.2; done
  kill -0 -- -"$group" 2>/dev/null && kill -KILL -- -"$group" 2>/dev/null || true
  wait "$group" 2>/dev/null || true
  kill -0 -- -"$group" 2>/dev/null && { print -u2 "owned UI process group survived"; return 1; }
  owned_pgid=""
}

cleanup() {
  stop_group || true
  for app in "$run_root/DerivedData/Build/Products/Debug/SERPy.app" "$run_root/DerivedData/Build/Products/Debug/GuideCompanionUITests-Runner.app"; do
    [[ -d "$app" ]] && "$launch_services" -u "$app" 2>/dev/null || true
  done
  find "$run_root" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

ui_command=(xcodebuild test -quiet -project GuideCompanion.xcodeproj -scheme GuideCompanion -testPlan GuideCompanionGolden -destination 'platform=macOS,arch=arm64' -derivedDataPath "$run_root/DerivedData" -clonedSourcePackagesDirPath "$run_root/SourcePackages" -resultBundlePath "$result_path")
[[ -n "$selection" ]] && ui_command+=("-only-testing:$selection")
if [[ ${SERPY_UI_RUNNER_FIXTURE:-} == ignore-term ]]; then
  ui_command=(/bin/zsh -c 'trap "" TERM; while true; do sleep 1; done' "serpy-ui-runner-${SERPY_TEST_SESSION_ID:-fixture}")
fi

perl -MPOSIX -e 'defined POSIX::setsid() or die "setsid failed"; exec @ARGV or die "exec failed"' -- "${ui_command[@]}" &
owned_pgid=$!
for _ in {1..50}; do kill -0 -- -"$owned_pgid" 2>/dev/null && break; sleep 0.02; done
started=$SECONDS
while kill -0 -- -"$owned_pgid" 2>/dev/null; do
  sleep 2
  (( $(du -sk "$run_root" | awk '{print $1}') <= ${SERPY_UI_DISK_KIB:-8388608} )) || { stop_group; exit 75; }
  (( SECONDS - started <= ${SERPY_UI_WALL_SECONDS:-900} )) || { stop_group; exit 75; }
done
if wait "$owned_pgid"; then run_status=0; else run_status=$?; fi
owned_pgid=""
exit "$run_status"
