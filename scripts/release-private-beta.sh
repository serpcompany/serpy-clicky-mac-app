#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

repository="serpcompany/serpy-clicky-mac-app"
expected_origin="https://github.com/serpcompany/serpy-clicky-mac-app.git"

if [[ $# -ne 2 ]]; then
  echo "Usage: scripts/release-private-beta.sh <vX.Y.Z-beta.N> <release-notes.md>" >&2
  exit 2
fi

tag="$1"
notes_file="$2"

if [[ ! "${tag}" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)-beta\.([1-9][0-9]*)$ ]]; then
  echo "ERROR: Tag must match vX.Y.Z-beta.N." >&2
  exit 1
fi

version="${BASH_REMATCH[1]}"
beta_number="${BASH_REMATCH[2]}"
release_title="SERPy ${version} Beta ${beta_number}"

[[ -f "${notes_file}" ]] || {
  echo "ERROR: Release notes not found: ${notes_file}" >&2
  exit 1
}

[[ "$(git branch --show-current)" == "main" ]] || {
  echo "ERROR: Private beta releases must run from main." >&2
  exit 1
}

[[ -z "$(git status --porcelain)" ]] || {
  echo "ERROR: Working tree must be clean before release." >&2
  exit 1
}

[[ "$(git remote get-url origin)" == "${expected_origin}" ]] || {
  echo "ERROR: origin must be ${expected_origin}." >&2
  exit 1
}

repo_state=$(gh repo view "${repository}" --json visibility,isArchived --jq '.visibility + " " + (.isArchived | tostring)')
[[ "${repo_state}" == "PRIVATE false" ]] || {
  echo "ERROR: ${repository} must exist, remain private, and not be archived." >&2
  exit 1
}

git fetch origin main --tags
head_commit=$(git rev-parse HEAD)
[[ "${head_commit}" == "$(git rev-parse origin/main)" ]] || {
  echo "ERROR: Local main must exactly match origin/main before release." >&2
  exit 1
}

if git show-ref --verify --quiet "refs/tags/${tag}" ||
   git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
  echo "ERROR: Tag already exists: ${tag}" >&2
  exit 1
fi

if gh release view "${tag}" --repo "${repository}" >/dev/null 2>&1; then
  echo "ERROR: GitHub release already exists: ${tag}" >&2
  exit 1
fi

(cd Packages/GuideModules && swift test)
scripts/build-release.sh

app_path=".release-derived/Build/Products/Release/SERPy.app"
app_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${app_path}/Contents/Info.plist")
build_number=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${app_path}/Contents/Info.plist")
[[ "${app_version}" == "${version}" ]] || {
  echo "ERROR: Tag version ${version} does not match app version ${app_version}." >&2
  exit 1
}

scripts/package-release.sh

base_name="SERPy-${app_version}-${build_number}"
dmg_path="dist/${base_name}.dmg"
checksum_path="${dmg_path}.sha256"
manifest_path="dist/${base_name}.manifest.json"

scripts/verify-release.sh "${dmg_path}"

[[ "$(jq -r '.gitCommit' "${manifest_path}")" == "${head_commit}" ]] || {
  echo "ERROR: Manifest commit does not match the release commit." >&2
  exit 1
}
[[ "$(jq -r '.notarization' "${manifest_path}")" == "accepted-and-stapled" ]] || {
  echo "ERROR: Manifest does not prove accepted and stapled notarization." >&2
  exit 1
}
[[ "$(jq -r '.sha256' "${manifest_path}")" == "$(shasum -a 256 "${dmg_path}" | awk '{print $1}')" ]] || {
  echo "ERROR: Manifest checksum does not match the DMG." >&2
  exit 1
}

git tag -a "${tag}" "${head_commit}" -m "${release_title}"
git push origin "refs/tags/${tag}"

gh release create "${tag}" \
  "${dmg_path}#Notarized SERPy DMG" \
  "${checksum_path}#SHA-256 checksum" \
  "${manifest_path}#Release manifest" \
  --repo "${repository}" \
  --verify-tag \
  --draft \
  --prerelease \
  --latest=false \
  --title "${release_title}" \
  --notes-file "${notes_file}"

asset_count=$(gh release view "${tag}" --repo "${repository}" --json assets --jq '.assets | length')
[[ "${asset_count}" == "3" ]] || {
  echo "ERROR: Draft release does not contain all three assets; it remains a draft." >&2
  exit 1
}

gh release edit "${tag}" \
  --repo "${repository}" \
  --verify-tag \
  --draft=false \
  --prerelease \
  --latest=false

release_state=$(gh release view "${tag}" --repo "${repository}" --json isDraft,isPrerelease --jq '(.isDraft | tostring) + " " + (.isPrerelease | tostring)')
[[ "${release_state}" == "false true" ]] || {
  echo "ERROR: GitHub release state is not a published prerelease." >&2
  exit 1
}

gh release view "${tag}" --repo "${repository}" --json name,tagName,url,isPrerelease,assets
