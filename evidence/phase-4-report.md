# Installed Product Evidence

Status: installed release and acoustic cross-app dictation verified; owner-voice HIL pending

## Artifact

- Product: Guide Companion 0.1.0 (16)
- Bundle ID: `com.serpcompany.guidecompanion.internal`
- Team: tester-owned Developer ID team `847HR8U8D9`
- Source commit: `08045c5`
- DMG: `dist/Guide-Companion-0.1.0-16.dmg`
- SHA-256: `18189f2ff0cd36196391f20f133bf158eebf6973655e446811446a2d1ef97c73`
- Notarization: accepted, submission `8919b9ba-e29e-4752-bad5-a991b57648c9`
- Stapling: passed and validated
- Gatekeeper: DMG and mounted app accepted as Notarized Developer ID

## Test machine

- Mac: MacBook Pro `Mac15,9`, Apple M3 Max, 128 GB
- OS: macOS 26.5.2 (25F84)
- Xcode: 26.0 (17A324)
- Architecture: arm64

## Mechanical verification

- Core, speech-lifecycle, callback-isolation, shortcut-collision/delivery,
  text-replacement, and transcript-recovery tests: 21 passing on 2026-08-16
- Unsigned Debug build: passed
- Apple Development interactive build: passed
- Developer ID Release build: passed
- Hardened Runtime and secure timestamp: passed
- Release `get-task-allow` absent: passed
- Package checksum validation: passed
- Mounted bundle ID and build-number validation: passed

## Installed human journeys

- DMG mount and copy to Applications: passed for build 16; the prior installed build was moved recoverably to Trash
- Launch without Xcode or Terminal: passed from `/Applications/Guide Companion.app`
- Setup now keeps permission state visible without relying on the prior long form's scroll position
- Microphone, Speech Recognition, Accessibility, and Screen Recording: granted and visibly reported on exact installed build
- Global shortcut registration: visibly reported as registered
- The owner observed that build 12's Control–Option–Space did nothing. The exact combination was independently found enabled in macOS as the “select next input source” system shortcut. Build 13 changes dictation to Control–Option–D without modifying the owner's system settings, and a regression test prevents returning to the two standard input-source combinations
- The owner then observed that build 13's Control–Option–D also did nothing, and installed diagnostics remained at zero attempts. This proved the Carbon registration result was a false-positive delivery signal rather than a remaining key collision
- Build 14 retained Carbon and added NSEvent monitors. Its app-targeted local test reached transcription, but both the owner's physical test and an agent-run synthetic HID test with TextEdit verified frontmost left Attempts unchanged. That reproduced the exact system-wide failure without owner assistance
- A standalone CGEvent-tap probe observed both system-wide D key-down and key-up events with the expected modifier flags. Build 15 replaces the failed NSEvent delivery path with that verified, listen-only CGEvent tap while retaining Carbon as a compatibility path and deduplicating deliveries
- Exact installed/notarized build 15 end-to-end test: TextEdit was verified frontmost and empty; the harness posted Control–Option–D, audibly spoke “Guide Companion dictation test,” released the shortcut, and TextEdit contained “Guide companion dictation test.” This proves global activation, microphone capture, Apple on-device transcription, and Accessibility insertion on the packaged release
- Build 15 then reproduced the owner's cross-app failure in a controlled Chrome
  input: Chromium returned success for an Accessibility selected-text write while
  the field remained empty. Build 16 uses focus-verified session Command-V first,
  preserves every pasteboard representation, restores it only while it still
  owns the pasteboard, and accepts direct Accessibility fallback only after an
  observable value change.
- Exact installed/notarized build 16 acoustic checks passed in a local Chrome
  plain input, textarea, contenteditable surface, and an empty TextEdit document.
  Each run verified the intended app was frontmost, posted Control–Option–D,
  spoke a unique phrase, released the shortcut, and observed the transcript in
  the intended field.
- Build 16 preserves the last nonempty completed transcript in memory before
  delivery and exposes Retry, Copy, and Clear in the menu and Settings. The
  recovery slot is covered by tests and survives insertion failure, but is
  deliberately cleared when the app quits; crash/relaunch recovery is not yet
  claimed.
- Accessibility permission: granted and retained after refresh/relaunch
- Two Swift concurrency crashes were reproduced and fixed: the speech-permission callback and the audio-tap/result callbacks no longer enter main-actor code from TCC/audio queues
- Signed live-audio testing reached microphone recording and a speech callback without crashing; synthetic system speech did not produce a non-empty transcript
- Accessibility/paste insertion into TextEdit: automated acoustic journey passed;
  owner-voice usability confirmation remains pending
- Automated insertion diagnostics correctly rejected Finder's non-editable `AXList`; the desktop control harness could not make TextEdit the actual NSWorkspace-frontmost app, so that run is not insertion acceptance evidence
- Companion: enabled, visibly rendered after app switching, Settings closure, and relaunch
- Menu-bar noninterference: implementation clamps to `visibleFrame`; crowded-menu HIL remains pending
- Explicit one-window screen guidance: permission requested only after activation; local capture/OCR/model path completed and reported ready on an earlier installed build. User acceptance on build 12 remains pending
- Quit/relaunch without permission loop: passed; all granted permissions remained granted
- Early-final speech result lifecycle: regression-tested so a pause before hotkey release cannot discard the phrase
- Installer collision prevention: volume name includes the build number
- Network/storage audit: no network client code, network entitlement, transcript/screenshot file writer, or live app socket was found; diagnostics log stages and target metadata but not dictated text or field contents
- Superseded build artifacts were moved recoverably to the user Trash; `dist/` contains only build 16

## Remaining human check

The automated acoustic journey passes on the installed release. The remaining
owner check is to focus TextEdit, hold Control–Option–D, speak naturally, and
release. This is a human voice/usability confirmation rather than the first
functional proof of the pipeline.
