#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

dmg_path="${1:-dist/SERPy-0.1.0-19.dmg}"
[[ -f "${dmg_path}" ]] || {
  echo "ERROR: DMG not found: ${dmg_path}" >&2
  exit 1
}

checksum_path="${dmg_path}.sha256"
if [[ -f "${checksum_path}" ]]; then
  expected_sha=$(awk '{print $1}' "${checksum_path}")
  actual_sha=$(shasum -a 256 "${dmg_path}" | awk '{print $1}')
  [[ "${actual_sha}" == "${expected_sha}" ]] || {
    echo "ERROR: DMG SHA-256 does not match ${checksum_path}." >&2
    exit 1
  }
fi

mount_dir=$(mktemp -d -t serpy-mount.XXXXXX)
cleanup() {
  hdiutil detach "${mount_dir}" -quiet 2>/dev/null || true
  rmdir "${mount_dir}" 2>/dev/null || true
}
trap cleanup EXIT

hdiutil verify "${dmg_path}" >/dev/null
codesign --verify --verbose=2 "${dmg_path}"
xcrun stapler validate "${dmg_path}"
spctl --assess --type open --context context:primary-signature -vv "${dmg_path}"
hdiutil attach "${dmg_path}" -nobrowse -readonly -mountpoint "${mount_dir}" >/dev/null

mounted_app="${mount_dir}/SERPy.app"
codesign --verify --deep --strict --verbose=2 "${mounted_app}"
spctl --assess --type execute -vv "${mounted_app}"

actual_bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${mounted_app}/Contents/Info.plist")
[[ "${actual_bundle_id}" == "com.serpcompany.guidecompanion.internal" ]] || {
  echo "ERROR: Mounted app has unexpected bundle ID ${actual_bundle_id}." >&2
  exit 1
}

echo "Verified notarized DMG and mounted app: ${dmg_path}"
