# SERPy 0.1.0 Beta 1 release evidence

## Release identity

- Release: `SERPy 0.1.0 Beta 1`
- Git tag: `v0.1.0-beta.1`
- Source commit: `bf9356a7db64f5dc5c3066369e72e4eecc7ed004`
- App version: `0.1.0`
- Xcode build: `24`
- Bundle identifier: `com.serpcompany.guidecompanion.internal`
- Architecture: `arm64`
- Private release:
  `https://github.com/serpcompany/serpy-clicky-mac-app/releases/tag/v0.1.0-beta.1`

The annotated tag peels to the source commit above. The evidence commit that
adds this report intentionally follows the immutable release tag.

## Published artifacts

- `SERPy-0.1.0-24.dmg`
- `SERPy-0.1.0-24.dmg.sha256`
- `SERPy-0.1.0-24.manifest.json`
- DMG SHA-256:
  `60458067bda781030a576032ea92a3c54909d13914dc4447e69f9861e0f7e1f4`

The release was published as a GitHub prerelease, not a draft or public-product
claim. The repository and release are private.

## Mechanical verification

- Full Swift suite passed: 11 XCTest tests plus 26 Swift Testing tests.
- Developer ID Release build passed.
- Apple notarization was accepted under submission
  `5d860072-2c27-478e-8c24-024cb7d4c222`.
- Stapling and staple validation passed.
- Gatekeeper accepted the DMG and the mounted application.
- The release script verified the manifest commit and exact artifact checksum.
- All three assets were downloaded back from the private GitHub release into a
  temporary directory.
- The downloaded checksum file validated the downloaded DMG.
- The downloaded manifest checksum matched the downloaded DMG.
- The downloaded manifest commit matched the commit behind the annotated tag.

## Scope of this evidence

This proves source-to-artifact identity, signing, notarization, packaging, and
private release publication. It does not replace the still-open human and
application-compatibility observations in `ACCEPTANCE.md`, does not claim a
public release, and does not configure hosted signing or automatic updates.
