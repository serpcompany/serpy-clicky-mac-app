#!/usr/bin/env bash

set -euo pipefail

mode="${1:-run}"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
derived_path="${root_dir}/.debug-derived"
app_path="${derived_path}/Build/Products/Debug/SERPy.app"
app_binary="${app_path}/Contents/MacOS/SERPy"
bundle_id="com.serpcompany.guidecompanion.internal"

cd "${root_dir}"
pkill -x SERPy >/dev/null 2>&1 || true

build_app() {
  xcodegen generate
  build_arguments=(
    -project GuideCompanion.xcodeproj
    -scheme GuideCompanion
    -configuration Debug
    -derivedDataPath "${derived_path}"
    -destination 'platform=macOS,arch=arm64'
    build
  )
  if [[ -n "${SENTRY_DSN:-}" ]]; then
    build_arguments+=(
      "SENTRY_DSN=${SENTRY_DSN}"
      "SENTRY_ENVIRONMENT=${SENTRY_ENVIRONMENT:-development}"
    )
  fi
  xcodebuild "${build_arguments[@]}"
}

open_app() {
  /usr/bin/open -n "${app_path}"
}

case "${mode}" in
  run)
    build_app
    open_app
    ;;
  --debug|debug)
    build_app
    lldb -- "${app_binary}"
    ;;
  --logs|logs)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate 'process == "SERPy"'
    ;;
  --telemetry|telemetry)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"${bundle_id}\" OR subsystem == \"${bundle_id}.internal\""
    ;;
  --verify|verify)
    build_app
    open_app
    sleep 1
    pgrep -x SERPy >/dev/null
    ;;
  --golden-malformed)
    xcodegen generate
    xcodebuild \
      -project GuideCompanion.xcodeproj \
      -scheme GuideCompanion \
      -destination 'platform=macOS,arch=arm64' \
      -only-testing:GuideCompanionUITests/GuideCompanionUITests/testMalformedGuidanceFixturePresentsTheHandledFailure \
      test
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--golden-malformed]" >&2
    exit 2
    ;;
esac
