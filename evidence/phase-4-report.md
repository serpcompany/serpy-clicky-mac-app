# Installed Product Evidence

Status: installed release verified; live spoken-dictation HIL pending

## Artifact

- Product: Guide Companion 0.1.0 (12)
- Bundle ID: `com.serpcompany.guidecompanion.internal`
- Team: tester-owned Developer ID team `847HR8U8D9`
- Source commit: `65a5b96`
- DMG: `dist/Guide-Companion-0.1.0-12.dmg`
- SHA-256: `a03964fb9f67988cc8e63cea8afcdb0ccfd349b43d342f68d94242891044ea8f`
- Notarization: accepted, submission `da2d06fc-1e91-4289-aeb0-8c174d7ccbaa`
- Stapling: passed and validated
- Gatekeeper: DMG and mounted app accepted as Notarized Developer ID

## Test machine

- Mac: MacBook Pro `Mac15,9`, Apple M3 Max, 128 GB
- OS: macOS 26.5.2 (25F84)
- Xcode: 26.0 (17A324)
- Architecture: arm64

## Mechanical verification

- Core, speech-lifecycle, callback-isolation, and text-replacement tests: 15 passing on 2026-08-16
- Unsigned Debug build: passed
- Apple Development interactive build: passed
- Developer ID Release build: passed
- Hardened Runtime and secure timestamp: passed
- Release `get-task-allow` absent: passed
- Package checksum validation: passed
- Mounted bundle ID and build-number validation: passed

## Installed human journeys

- Finder DMG mount and copy to Applications: passed for build 12; Finder replaced the older installed build
- Launch without Xcode or Terminal: passed from `/Applications/Guide Companion.app`
- Setup now keeps permission state visible without relying on the prior long form's scroll position
- Microphone, Speech Recognition, Accessibility, and Screen Recording: granted and visibly reported on exact installed build
- Global shortcut registration: visibly reported as registered
- Accessibility permission: granted and retained after refresh/relaunch
- Two Swift concurrency crashes were reproduced and fixed: the speech-permission callback and the audio-tap/result callbacks no longer enter main-actor code from TCC/audio queues
- Signed live-audio testing reached microphone recording and a speech callback without crashing; synthetic system speech did not produce a non-empty transcript
- Accessibility insertion into TextEdit: pending one physical frontmost-field test with a live spoken phrase from the tester
- Automated insertion diagnostics correctly rejected Finder's non-editable `AXList`; the desktop control harness could not make TextEdit the actual NSWorkspace-frontmost app, so that run is not insertion acceptance evidence
- Companion: enabled, visibly rendered after app switching, Settings closure, and relaunch
- Menu-bar noninterference: implementation clamps to `visibleFrame`; crowded-menu HIL remains pending
- Explicit one-window screen guidance: permission requested only after activation; local capture/OCR/model path completed and reported ready on an earlier installed build. User acceptance on build 12 remains pending
- Quit/relaunch without permission loop: passed; all granted permissions remained granted
- Early-final speech result lifecycle: regression-tested so a pause before hotkey release cannot discard the phrase
- Installer collision prevention: volume name includes the build number
- Network/storage audit: no network client code, network entitlement, transcript/screenshot file writer, or live app socket was found; diagnostics log stages and target metadata but not dictated text or field contents
- Superseded build artifacts were moved recoverably to the user Trash; `dist/` contains only build 12

## Remaining human check

With an empty TextEdit document physically focused, hold Control–Option–Space,
speak one sentence, then release. Acceptance requires observing the sentence in
the same field with no cloud/API configuration. If it fails, Settings > Setup
now exposes attempt count, activation source, last stage, and a content-free
failure reason; its delayed manual test can separately bypass shortcut handling.
