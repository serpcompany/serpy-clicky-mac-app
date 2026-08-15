# Installed Product Evidence

Status: installed release verified; live spoken-dictation HIL pending

## Artifact

- Product: Guide Companion 0.1.0 (3)
- Bundle ID: `com.serpcompany.guidecompanion.internal`
- Team: tester-owned Developer ID team `847HR8U8D9`
- Source commit: `ab01c727ea5d590bea8ce58d1f285cc1e0cc644c`
- DMG: `dist/Guide-Companion-0.1.0-3.dmg`
- SHA-256: `b0d9f64e83dc99c84bee17f91415942896b14fd12a27044a0c15b8473faf4c54`
- Notarization: accepted, submission `6fb27bcc-6c75-4724-86c2-c069e10667ac`
- Stapling: passed and validated
- Gatekeeper: DMG and mounted app accepted as Notarized Developer ID

## Test machine

- Mac: MacBook Pro `Mac15,9`, Apple M3 Max, 128 GB
- OS: macOS 26.5.2 (25F84)
- Xcode: 26.0 (17A324)
- Architecture: arm64

## Mechanical verification

- Core and speech-lifecycle tests: 11 passing on 2026-08-16
- Unsigned Debug build: passed
- Apple Development interactive build: passed
- Developer ID Release build: passed
- Hardened Runtime and secure timestamp: passed
- Release `get-task-allow` absent: passed
- Package checksum validation: passed
- Mounted bundle ID and build-number validation: passed

## Installed human journeys

- Finder DMG mount and copy to Applications: passed for build 3; Finder identified it as newer than build 2
- Launch without Xcode or Terminal: passed from `/Applications/Guide Companion.app`
- Microphone and Speech Recognition: granted and reported ready on exact installed build
- Accessibility permission: granted and retained after refresh/relaunch
- Accessibility insertion into TextEdit: pending one live spoken phrase from the tester
- Companion: enabled, visibly rendered after app switching, Settings closure, and relaunch
- Menu-bar noninterference: implementation clamps to `visibleFrame`; crowded-menu HIL remains pending
- Explicit one-window screen guidance: permission requested only after activation; local capture/OCR/model path completed and reported ready again on exact installed build 3
- Quit/relaunch without permission loop: passed; all granted permissions remained granted
- Early-final speech result lifecycle: regression-tested so a pause before hotkey release cannot discard the phrase
- Installer collision prevention: volume name includes the build number

## Remaining human check

With an empty TextEdit document focused, hold Control–Option–Space, speak one
sentence, then release. Acceptance requires observing the sentence in the same
field with no cloud/API configuration.
