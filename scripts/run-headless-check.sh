#!/bin/zsh
set -euo pipefail

check_name=${1:-all}
case "$check_name" in
  core-tests|app-build|all) ;;
  *) print -u2 "unknown check: $check_name"; exit 64 ;;
esac

if [[ -n ${SERPY_HARNESS_ROOT:-} ]]; then
  run_root=$SERPY_HARNESS_ROOT
  case "$run_root" in
    /tmp/serpy-headless.*|${TMPDIR:-/tmp}/serpy-headless.*) ;;
    *) print -u2 "SERPY_HARNESS_ROOT must be an owned serpy-headless temp path"; exit 64 ;;
  esac
  mkdir -p "$run_root"
else
  run_root=$(mktemp -d "${TMPDIR:-/tmp}/serpy-headless.XXXXXX")
fi

cleanup() {
  local launch_services=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister
  local built_app
  for built_app in \
    "$run_root/derived-data/Build/Products/Debug/SERPy.app" \
    "$run_root/derived-data-golden/Build/Products/Debug/serpyGoldenHost.app"; do
    if [[ -d "$built_app" ]]; then
      "$launch_services" -u "$built_app" 2>/dev/null || true
    fi
  done
  find "$run_root" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM HUP

kill_owned_tree() {
  local owned_pid=$1
  local child
  for child in $(pgrep -P "$owned_pid" 2>/dev/null || true); do
    kill_owned_tree "$child"
  done
  kill -TERM "$owned_pid" 2>/dev/null || true
}

run_bounded() {
  local started_at=$SECONDS
  "$@" &
  local owned_pid=$!
  while kill -0 "$owned_pid" 2>/dev/null; do
    sleep 2
    local used_kib=$(du -sk "$run_root" | awk '{print $1}')
    if (( used_kib > 8388608 )); then
      print -u2 "disk budget exceeded: ${used_kib} KiB"
      kill_owned_tree "$owned_pid"
      wait "$owned_pid" 2>/dev/null || true
      return 75
    fi
    if (( SECONDS - started_at > 1800 )); then
      print -u2 "wall-clock budget exceeded: 1800 seconds"
      kill_owned_tree "$owned_pid"
      wait "$owned_pid" 2>/dev/null || true
      return 75
    fi
  done
  wait "$owned_pid"
}

if [[ ${SERPY_INJECT_FAILURE:-} == "$check_name" || (${SERPY_INJECT_FAILURE:-} == all && "$check_name" == all) ]]; then
  print -u2 "deliberate injected failure: $check_name"
  exit 86
fi

run_core_tests() {
  swift test \
    --package-path Packages/GuideModules \
    --scratch-path "$run_root/swiftpm" \
    --disable-automatic-resolution
}

run_app_build() {
  xcodebuild build \
    -project GuideCompanion.xcodeproj \
    -scheme GuideCompanion \
    -configuration Debug \
    -derivedDataPath "$run_root/derived-data" \
    -clonedSourcePackagesDirPath "$run_root/source-packages" \
    -disableAutomaticPackageResolution \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    REGISTER_APP_WITH_LAUNCH_SERVICES=NO
  xcodebuild build-for-testing \
    -project GuideCompanion.xcodeproj \
    -scheme GuideCompanionGoldenHost \
    -testPlan GuideCompanionGolden \
    -configuration Debug \
    -derivedDataPath "$run_root/derived-data-golden" \
    -clonedSourcePackagesDirPath "$run_root/source-packages-golden" \
    -disableAutomaticPackageResolution \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    REGISTER_APP_WITH_LAUNCH_SERVICES=NO
}

case "$check_name" in
  core-tests) run_bounded run_core_tests ;;
  app-build) run_bounded run_app_build ;;
  all) run_bounded run_core_tests; run_bounded run_app_build ;;
esac

used_kib=$(du -sk "$run_root" | awk '{print $1}')
if (( used_kib > 8388608 )); then
  print -u2 "disk budget exceeded: ${used_kib} KiB"
  exit 75
fi
