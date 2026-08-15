# Installed Product Evidence

Status: installed release verified; live spoken-dictation HIL pending

## Artifact

- Product: Guide Companion 0.1.0 (2)
- Bundle ID: `com.serpcompany.guidecompanion.internal`
- Team: tester-owned Developer ID team `847HR8U8D9`
- Source commit: `8ce44bc5e1cd4e397bfa073a222adbf8539db7ae`
- DMG: `dist/Guide-Companion-0.1.0-2.dmg`
- SHA-256: `86774e8433a8b80de8c903d6c1fc370f7ca3c7375baaffac34640e8fff656612`
- Notarization: accepted, submission `8d3bdbe4-6ad6-43dd-b9ff-d9a887c49c9b`
- Stapling: passed and validated
- Gatekeeper: DMG and mounted app accepted as Notarized Developer ID

## Test machine

- Mac: MacBook Pro `Mac15,9`, Apple M3 Max, 128 GB
- OS: macOS 26.5.2 (25F84)
- Xcode: 26.0 (17A324)
- Architecture: arm64

## Mechanical verification

- Core state tests: 9 passing on 2026-08-16
- Unsigned Debug build: passed
- Apple Development interactive build: passed
- Developer ID Release build: passed
- Hardened Runtime and secure timestamp: passed
- Release `get-task-allow` absent: passed
- Package checksum validation: passed
- Mounted bundle ID and build-number validation: passed

## Installed human journeys

- Finder DMG mount and copy to Applications: passed for build 2; Finder identified it as newer than build 1
- Launch without Xcode or Terminal: passed from `/Applications/Guide Companion.app`
- Microphone and Speech Recognition: granted and reported ready on exact installed build
- Accessibility permission: granted and retained after refresh/relaunch
- Accessibility insertion into TextEdit: pending one live spoken phrase from the tester
- Companion: enabled, visibly rendered after app switching, Settings closure, and relaunch
- Menu-bar noninterference: implementation clamps to `visibleFrame`; crowded-menu HIL remains pending
- Explicit one-window screen guidance: permission requested only after activation; local capture/OCR/model path completed and reported ready
- Quit/relaunch without permission loop: passed; all granted permissions remained granted

## Remaining human check

With an empty TextEdit document focused, hold Control–Option–Space, speak one
sentence, then release. Acceptance requires observing the sentence in the same
field with no cloud/API configuration.
