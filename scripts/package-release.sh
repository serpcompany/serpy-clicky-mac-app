#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

skip_notarize=0
if [[ "${1:-}" == "--skip-notarize" ]]; then
  skip_notarize=1
elif [[ $# -gt 0 ]]; then
  echo "Usage: scripts/package-release.sh [--skip-notarize]" >&2
  exit 2
fi

team_id="${GUIDE_COMPANION_TEAM_ID:-847HR8U8D9}"
bundle_id="com.serpcompany.guidecompanion.internal"
app_source=".release-derived/Build/Products/Release/Guide Companion.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${app_source}/Contents/Info.plist")
build_number=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${app_source}/Contents/Info.plist")
actual_bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${app_source}/Contents/Info.plist")

[[ "${actual_bundle_id}" == "${bundle_id}" ]] || {
  echo "ERROR: Unexpected bundle identifier ${actual_bundle_id}." >&2
  exit 1
}

signing_hash=$(security find-identity -v -p codesigning \
  | sed -nE 's/^ *[0-9]+\) ([A-F0-9]{40}) "Developer ID Application: .+ \('"${team_id}"'\)"$/\1/p' \
  | head -1)
[[ -n "${signing_hash}" ]] || {
  echo "ERROR: No Developer ID Application identity found for team ${team_id}." >&2
  exit 1
}

package_root="build/guide-companion-package"
stage_dir="${package_root}/dmg-stage"
dist_dir="dist"
base_name="Guide-Companion-${version}-${build_number}"
dmg_path="${dist_dir}/${base_name}.dmg"
checksum_path="${dmg_path}.sha256"
manifest_path="${dist_dir}/${base_name}.manifest.json"

rm -rf "${package_root}"
rm -f "${dmg_path}" "${checksum_path}" "${manifest_path}"
mkdir -p "${stage_dir}" "${dist_dir}"

/usr/bin/ditto "${app_source}" "${stage_dir}/Guide Companion.app"
ln -s /Applications "${stage_dir}/Applications"

codesign --verify --deep --strict --verbose=2 "${stage_dir}/Guide Companion.app"

hdiutil create \
  -volname "Guide Companion ${version} (${build_number})" \
  -srcfolder "${stage_dir}" \
  -ov \
  -format UDZO \
  "${dmg_path}" >/dev/null

codesign --sign "${signing_hash}" --timestamp --force "${dmg_path}"
codesign --verify --verbose=2 "${dmg_path}"
hdiutil verify "${dmg_path}" >/dev/null

notarization_status="skipped"
if [[ "${skip_notarize}" -eq 0 ]]; then
  asc notarization submit \
    --file "${dmg_path}" \
    --wait \
    --timeout 1h \
    --output json \
    --pretty | tee "${package_root}/notarization-result.json"
  xcrun stapler staple "${dmg_path}"
  xcrun stapler validate "${dmg_path}"
  notarization_status="accepted-and-stapled"
fi

sha256=$(shasum -a 256 "${dmg_path}" | awk '{print $1}')
printf '%s  %s\n' "${sha256}" "$(basename "${dmg_path}")" > "${checksum_path}"
git_commit=$(git rev-parse HEAD)
architectures=$(lipo -archs "${app_source}/Contents/MacOS/Guide Companion")

cat > "${manifest_path}" <<EOF
{
  "artifact": "$(basename "${dmg_path}")",
  "sha256": "${sha256}",
  "gitCommit": "${git_commit}",
  "version": "${version}",
  "build": "${build_number}",
  "bundleIdentifier": "${bundle_id}",
  "teamIdentifier": "${team_id}",
  "architectures": "${architectures}",
  "signing": "Developer ID Application",
  "notarization": "${notarization_status}"
}
EOF

echo "DMG ready: ${dmg_path}"
echo "SHA-256: ${sha256}"
echo "Manifest: ${manifest_path}"
