# Acceptance Ledger

Statuses are `unimplemented`, `implemented`, `unit-tested`, `integration-tested`,
`installed-observed`, or `accepted`. Only direct evidence can advance a row.

## A — Local Dictation

| ID | Journey | Required evidence | Status |
| --- | --- | --- | --- |
| A1 | Fresh install explains permissions before prompting | Installed recording | installed-observed |
| A2 | Declining permission does not trigger repeated prompts | Installed recording + state test | unimplemented |
| A3 | Model download shows size, progress, cancellation, and checksum result | Integration test + installed recording | unimplemented |
| A4 | Push-to-talk records and inserts into TextEdit | Offline installed recording | installed-observed |
| A5 | Dictation works in Notes, browser, Slack, and code editor | Compatibility matrix | implemented |
| A6 | Caret, selected-text replacement, multiline, punctuation, and undo work | Integration tests + observation | unimplemented |
| A7 | Cancellation inserts nothing | State and integration tests | unit-tested |
| A8 | Clipboard content is preserved during fallback insertion | Deterministic test | implemented |
| A9 | No API key, account, or network is required after model download | Network-disabled observation | implemented |
| A10 | Failed delivery retains Last Dictation with Retry, Copy, and Clear | State test + installed observation | installed-observed |
| A11 | Completed transcript survives crash/relaunch before delivery | Store test + installed crash/relaunch observation | installed-observed |
| A12 | Unverifiable paste is labeled unconfirmed and remains recoverable | Deterministic test + installed observation | installed-observed |

Build 15 visibly reports the four permission states and shortcut registration,
and its signed live-audio path records without the earlier callback crashes.
Build 12's Control–Option–Space collided with this Mac's enabled input-source
shortcut; build 13 uses Control–Option–D and regression-tests that the default
is not either standard macOS input-source combination.
Build 13 still received zero activations because Carbon registration did not
deliver events in the installed SwiftUI menu-bar lifecycle. Build 14's NSEvent
global monitor also failed with TextEdit frontmost. Build 15 uses a verified
listen-only CGEvent tap. On the installed notarized build, a synthetic global
shortcut plus an audible spoken phrase produced the expected on-device
transcript in an empty TextEdit field. Owner-voice confirmation remains pending.
Build 16 changes delivery to focus-verified session paste and verifies the
installed app acoustically in Chrome plain input, textarea, contenteditable,
and TextEdit targets. Build 18 replaces the memory-only recovery path with an
atomic local Last Dictation saved before delivery. Installed TextEdit and Chrome
targets report confirmed delivery. VS Code accepts the paste but exposes no
readable document value, so the app truthfully reports unconfirmed and retains
Copy/Retry/Delete; that record survived quit/relaunch. A5 remains partial:
Notes and Slack are not yet observed.

## B — Companion

| ID | Journey | Required evidence | Status |
| --- | --- | --- | --- |
| B1 | Enabling companion shows it immediately | Installed observation | installed-observed |
| B2 | It survives app switches, idle, settings closure, and failed requests | Lifecycle test + observation | installed-observed |
| B3 | It survives relaunch when enabled | Installed observation | installed-observed |
| B4 | Explicit disable hides it and persists | State test + observation | unit-tested |
| B5 | It never blocks menu-bar/status-item clicks | Crowded-menu HIL recording | unimplemented |
| B6 | It behaves correctly at display edges and on negative-origin displays | Geometry tests + multi-display HIL | unimplemented |
| B7 | Settings behaves as a normal non-floating window | App-switch/Spaces recording | installed-observed |
| B8 | Reduce Motion and accessibility labels are respected | Inspection + HIL | implemented |

## C — Screen Guidance

| ID | Journey | Required evidence | Status |
| --- | --- | --- | --- |
| C1 | Screen permission is requested only after guide activation | Fresh-install recording | installed-observed |
| C2 | User can identify what will be captured | Installed recording | installed-observed |
| C3 | Capture excludes the app's own overlays where possible | Image comparison | implemented |
| C4 | Accessibility/OCR context is produced without storing a screenshot | Integration test + file audit | integration-tested |
| C5 | Local engine returns a useful explanation | Scenario corpus + HIL | integration-tested |
| C6 | Point cues are bounds-checked and confidence-gated | Property/unit tests | unit-tested |
| C7 | Low confidence produces prose without misleading pointing | Deterministic test | unit-tested |
| C8 | The guide never clicks, types, executes, or submits | Capability audit + HIL | implemented |
| C9 | Dictation remains available when guidance is unavailable | Failure-injection test | unimplemented |
| C10 | Guide opens a conversation and supports contextual follow-up questions | State tests + installed multi-turn observation | installed-observed |
| C11 | Guide conversations and screenshots are not persisted after quit | Filesystem/log audit + relaunch observation | implemented |

The owner reported that the guidance journeys after the initial companion
checks did not work during first use. The C rows above describe implementation
or earlier bounded evidence only; none should be read as owner acceptance of
the current build.

## D — Distribution and Privacy

| ID | Journey | Required evidence | Status |
| --- | --- | --- | --- |
| D1 | Developer ID signed, notarized, stapled DMG | Mechanical report | accepted |
| D2 | HTTPS download carries quarantine and passes Gatekeeper | Installed report | unimplemented |
| D3 | Quit/relaunch does not cause permission loops | Installed recording | installed-observed |
| D4 | Default storage is one bounded Last Dictation; screenshots/audio are not stored | Filesystem/log audit | installed-observed |
| D5 | Diagnostics redact captured and dictated content | Fixture tests + export audit | implemented |
| D6 | No borrowed product identity, keys, feeds, or release destinations remain | Provenance/identity audit | implemented |
| D7 | Full transcript history and audio history require separate explicit opt-ins and Clear removes both | State/store tests + installed observation | installed-observed |

## Compatibility Matrix

The initial matrix is TextEdit, Notes, Chrome or Safari, Slack, and one code
editor used by the owner. Additional applications become explicit rows rather
than implied support claims.
