#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

team_id="${GUIDE_COMPANION_TEAM_ID:-847HR8U8D9}"
derived_path="${GUIDE_COMPANION_DERIVED_PATH:-.release-derived}"
app_path="${derived_path}/Build/Products/Release/SERPy.app"

diagnostic_settings=()
if [[ "${SERPY_INTERNAL_DIAGNOSTICS:-0}" == "1" ]]; then
  [[ -n "${SENTRY_DSN:-}" ]] || {
    echo "ERROR: Internal diagnostics requires a runtime-supplied SENTRY_DSN." >&2
    exit 1
  }
  diagnostic_settings=(
    SWIFT_ACTIVE_COMPILATION_CONDITIONS=SERPY_INTERNAL_DIAGNOSTICS
    SENTRY_ENVIRONMENT=internal-test
    "SENTRY_DSN=${SENTRY_DSN}"
  )
fi

signing_hash=$(security find-identity -v -p codesigning \
  | sed -nE 's/^ *[0-9]+\) ([A-F0-9]{40}) "Developer ID Application: .+ \('"${team_id}"'\)"$/\1/p' \
  | head -1)

if [[ -z "${signing_hash}" ]]; then
  echo "ERROR: No Developer ID Application identity found for team ${team_id}." >&2
  exit 1
fi

xcodegen generate

xcodebuild \
  -project GuideCompanion.xcodeproj \
  -scheme GuideCompanion \
  -configuration Release \
  -derivedDataPath "${derived_path}" \
  -destination 'platform=macOS,arch=arm64' \
  clean build \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="${signing_hash}" \
  DEVELOPMENT_TEAM="${team_id}" \
  OTHER_CODE_SIGN_FLAGS=--timestamp \
  ${diagnostic_settings[@]+"${diagnostic_settings[@]}"}

codesign --verify --deep --strict --verbose=2 "${app_path}"

signature_info=$(codesign -dvvv "${app_path}" 2>&1)
grep -q 'Authority=Developer ID Application:' <<<"${signature_info}" || {
  echo "ERROR: Release app is not Developer ID signed." >&2
  exit 1
}
grep -q "TeamIdentifier=${team_id}" <<<"${signature_info}" || {
  echo "ERROR: Release app uses the wrong team." >&2
  exit 1
}
grep -q '^Timestamp=' <<<"${signature_info}" || {
  echo "ERROR: Release app has no secure timestamp." >&2
  exit 1
}

effective_entitlements=$(codesign -d --entitlements :- "${app_path}" 2>/dev/null)
if grep -q 'com.apple.security.get-task-allow' <<<"${effective_entitlements}"; then
  echo "ERROR: Release app contains the debug get-task-allow entitlement." >&2
  exit 1
fi
grep -q 'com.apple.security.device.audio-input' <<<"${effective_entitlements}" || {
  echo "ERROR: Release app is missing audio-input entitlement." >&2
  exit 1
}

echo "Release app ready: ${app_path}"
