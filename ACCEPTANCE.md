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
| B4 | Explicit disable hides it and persists | State test + observation | installed-observed |
| B5 | It never blocks menu-bar/status-item clicks | Crowded-menu HIL recording | unimplemented |
| B6 | It behaves correctly at display edges and on negative-origin displays | Geometry tests + multi-display HIL | unit-tested |
| B7 | Settings behaves as a normal non-floating window | App-switch/Spaces recording | installed-observed |
| B8 | Reduce Motion and accessibility labels are respected | Inspection + HIL | implemented |
| B9 | Menu-bar content uses a native menu, remains fully visible, and routes detailed setup to Settings | Installed screenshot + accessibility inspection | implemented |

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
| C10 | Guide supports spoken contextual questions and spoken follow-ups without opening a typing window | State tests + installed multi-turn voice observation | installed-observed |
| C11 | Guide conversations and screenshots are not persisted after quit | Filesystem/log audit + relaunch observation | implemented |
| C12 | Guide answers are captioned by the cursor and spoken locally | Installed audio observation | implemented |
| C13 | Active guide turns force the companion visible without changing a disabled saved preference | Policy test + installed preference-off lifecycle | installed-observed |
| C14 | A 55-word guide answer is fully readable in an edge-safe bubble without covering guide status | Layout tests + installed corner observation | unit-tested |
| C15 | Each turn locks PID, exact window ID, app/title, and frame before presentation and never falls back to a sibling window | Policy/adapter tests + installed same-app multi-window observation | unit-tested |
| C16 | Escape cancels the owned listening, capture, thinking, or speaking work and restores companion visibility idempotently | Coordinator tests + installed phase-by-phase observation | unit-tested |
| C17 | Listening acknowledgement precedes capture work and Vision OCR never blocks the main actor | Coordinator ordering + adapter contract test + installed latency observation | unit-tested |

The owner reported that the guidance journeys after the initial companion
checks did not work during first use. The C rows above describe implementation
or earlier bounded evidence only; none should be read as owner acceptance of
the current build.

The 2026-09-04 ambient-guide P0 build 28 adds deterministic visibility,
edge-layout, and presentation-policy tests plus a signed Release build. The
installed preference-off lifecycle is observed. A 55-word answer at display
edges, target identity across multiple windows, Spaces/full-screen behavior,
spoken timing, and VoiceOver behavior remain red. See
`evidence/serpy-p0-ambient-guide-tdd-report.md`.

Build 29 rejects and retries local-model answers that falsely claim the
captured application is unavailable. ScreenCaptureKit and Foundation Models
were observed completing against ChatGPT, but the owner's original spoken
question still needs to be retried before this regression is installed-observed.

Issue #6 build 30 replaces the split legacy capture/answer tasks with one owned
guide-turn coordinator, exact-window targeting, cancellable system-boundary
adapters, off-main Vision OCR, controlled grounding fixtures, and stationary
bounded answer presentation. These are source and test results only. The branch
artifact is not installed, hash-matched, or owner-observed; its ambient journey,
audible output, focus retention, follow-up, and every cancellation phase remain
red until the HIL is completed against that exact artifact.

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
