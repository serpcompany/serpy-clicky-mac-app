# Installed Product Evidence

Status: build 18 installed; acoustic cross-app dictation and durable recovery verified; owner-voice HIL pending

## Artifact

- Product: Guide Companion 0.1.0 (18)
- Bundle ID: `com.serpcompany.guidecompanion.internal`
- Team: tester-owned Developer ID team `847HR8U8D9`
- Source commit: `01a016b`
- DMG: `dist/Guide-Companion-0.1.0-18.dmg`
- SHA-256: `3cc9f9749960621b3b28666fd662672e3debff6e69fadc0f013714fc9d4cd6f4`
- Notarization: accepted, submission `0353c2c5-7a33-444e-9c92-dbb8691b3732`
- Stapling: passed and validated
- Gatekeeper: DMG and mounted app accepted as Notarized Developer ID

## Test machine

- Mac: MacBook Pro `Mac15,9`, Apple M3 Max, 128 GB
- OS: macOS 26.5.2 (25F84)
- Xcode: 26.0 (17A324)
- Architecture: arm64

## Mechanical verification

- Core, speech-lifecycle, callback-isolation, shortcut-collision/delivery,
  text-replacement, pasteboard-ownership, and transcript-recovery tests: 31
  passing on 2026-08-16
- Unsigned Debug build: passed
- Apple Development interactive build: passed
- Developer ID Release build: passed
- Hardened Runtime and secure timestamp: passed
- Release `get-task-allow` absent: passed
- Package checksum validation: passed
- Mounted bundle ID and build-number validation: passed

## Installed human journeys

- DMG mount and copy to Applications: passed for build 18; prior installed builds were moved recoverably to Trash
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
- Build 17 introduced an atomic local Last Dictation written before delivery,
  explicit confirmed/unconfirmed/failed states, bounded expiry, Copy/Retry/Delete,
  optional 25-item text history, and a separate optional audio-history switch.
  A forced TextEdit destination switch produced a failed record that survived
  quit/relaunch; Copy recovered the exact text and Retry later inserted it.
- Installed build 17's optional audio test produced an owner-only `0600` WAV,
  linked it to the transcript, and removed the WAV when that entry was deleted.
  Both history settings were then restored to off.
- The initial VS Code run exposed a false-negative: the paste succeeded, but
  VS Code's AX editor kept returning its stable accessibility placeholder.
  Build 18 treats an unchanged or unreadable AX value as unconfirmed rather
  than failed or confirmed.
- Exact installed/notarized build 18 inserted an acoustic phrase into VS Code,
  labeled delivery `pasteUnconfirmed`, displayed `Saved — verify paste`, and
  retained Copy/Retry/Delete. The same unconfirmed record and exact transcript
  were visible after quitting and relaunching Guide Companion.
- Exact installed/notarized build 18 also produced a confirmed acoustic paste
  in TextEdit. Build 17 had already confirmed Chrome plain input and
  contenteditable targets through the same delivery implementation.
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
- Storage audit: the default is one atomic Last Dictation only, expiring after
  10 minutes when confirmed or 24 hours when failed/unconfirmed. The JSON and
  opt-in WAV use `0600`; their directory uses `0700`; no screenshot is stored.
  Full text history (25 items/30 days) and audio history are separate opt-ins.
  Diagnostics log stages and target metadata but not dictated text or field
  contents.
- Network audit: no network client code, network entitlement, paid API, account,
  or live app socket is part of dictation.
- Test transcripts/audio and temporary TextEdit/VS Code documents were cleared.
  History and audio settings are off. Superseded build 16/17 artifacts and apps
  were moved recoverably to the user Trash; `dist/` contains only build 18.

## Remaining human check

The automated acoustic journey passes on the installed release. The remaining
owner check is to focus TextEdit, hold Control–Option–D, speak naturally, and
release. This is a human voice/usability confirmation rather than the first
functional proof of the pipeline.
