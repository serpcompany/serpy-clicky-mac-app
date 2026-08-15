# Installed Product Evidence

Status: installed release verified; live spoken-dictation HIL pending

## Artifact

- Product: Guide Companion 0.1.0 (14)
- Bundle ID: `com.serpcompany.guidecompanion.internal`
- Team: tester-owned Developer ID team `847HR8U8D9`
- Source commit: `2199ea8`
- DMG: `dist/Guide-Companion-0.1.0-14.dmg`
- SHA-256: `f91cccadfbee1c2088508e3b9fe189f7091eb496e42089f92fa07d17cb1991ff`
- Notarization: accepted, submission `739074b1-3f6a-404a-9296-5b94bf161d26`
- Stapling: passed and validated
- Gatekeeper: DMG and mounted app accepted as Notarized Developer ID

## Test machine

- Mac: MacBook Pro `Mac15,9`, Apple M3 Max, 128 GB
- OS: macOS 26.5.2 (25F84)
- Xcode: 26.0 (17A324)
- Architecture: arm64

## Mechanical verification

- Core, speech-lifecycle, callback-isolation, shortcut-collision/delivery, and text-replacement tests: 19 passing on 2026-08-16
- Unsigned Debug build: passed
- Apple Development interactive build: passed
- Developer ID Release build: passed
- Hardened Runtime and secure timestamp: passed
- Release `get-task-allow` absent: passed
- Package checksum validation: passed
- Mounted bundle ID and build-number validation: passed

## Installed human journeys

- DMG mount and copy to Applications: passed for build 14; the prior installed build was moved recoverably to Trash
- Launch without Xcode or Terminal: passed from `/Applications/Guide Companion.app`
- Setup now keeps permission state visible without relying on the prior long form's scroll position
- Microphone, Speech Recognition, Accessibility, and Screen Recording: granted and visibly reported on exact installed build
- Global shortcut registration: visibly reported as registered
- The owner observed that build 12's Control–Option–Space did nothing. The exact combination was independently found enabled in macOS as the “select next input source” system shortcut. Build 13 changes dictation to Control–Option–D without modifying the owner's system settings, and a regression test prevents returning to the two standard input-source combinations
- The owner then observed that build 13's Control–Option–D also did nothing, and installed diagnostics remained at zero attempts. This proved the Carbon registration result was a false-positive delivery signal rather than a remaining key collision
- Build 14 retains Carbon as a compatibility path and adds narrowly filtered local/global NSEvent monitors with press/release deduplication. An installed app-targeted Control–Option–D test advanced Attempts from 0 to 1, recorded the activation, and reached transcription; with no speech in that automated test, it correctly ended with “No speech could be transcribed.” Physical delivery while another app is frontmost remains the required HIL
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

With an empty TextEdit document physically focused, hold Control–Option–D,
speak one sentence, then release. Acceptance requires observing the sentence in
the same field with no cloud/API configuration. If it fails, Settings > Setup
now exposes attempt count, activation source, last stage, and a content-free
failure reason; its delayed manual test can separately bypass shortcut handling.
