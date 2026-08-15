# Acceptance Ledger

Statuses are `unimplemented`, `implemented`, `unit-tested`, `integration-tested`,
`installed-observed`, or `accepted`. Only direct evidence can advance a row.

## A — Local Dictation

| ID | Journey | Required evidence | Status |
| --- | --- | --- | --- |
| A1 | Fresh install explains permissions before prompting | Installed recording | unimplemented |
| A2 | Declining permission does not trigger repeated prompts | Installed recording + state test | unimplemented |
| A3 | Model download shows size, progress, cancellation, and checksum result | Integration test + installed recording | unimplemented |
| A4 | Push-to-talk records and inserts into TextEdit | Offline installed recording | unimplemented |
| A5 | Dictation works in Notes, browser, Slack, and code editor | Compatibility matrix | unimplemented |
| A6 | Caret, selected-text replacement, multiline, punctuation, and undo work | Integration tests + observation | unimplemented |
| A7 | Cancellation inserts nothing | State and integration tests | unimplemented |
| A8 | Clipboard content is preserved during fallback insertion | Deterministic test | unimplemented |
| A9 | No API key, account, or network is required after model download | Network-disabled observation | unimplemented |

## B — Companion

| ID | Journey | Required evidence | Status |
| --- | --- | --- | --- |
| B1 | Enabling companion shows it immediately | Installed observation | unimplemented |
| B2 | It survives app switches, idle, settings closure, and failed requests | Lifecycle test + observation | unimplemented |
| B3 | It survives relaunch when enabled | Installed observation | unimplemented |
| B4 | Explicit disable hides it and persists | State test + observation | unimplemented |
| B5 | It never blocks menu-bar/status-item clicks | Crowded-menu HIL recording | unimplemented |
| B6 | It behaves correctly at display edges and on negative-origin displays | Geometry tests + multi-display HIL | unimplemented |
| B7 | Settings behaves as a normal non-floating window | App-switch/Spaces recording | unimplemented |
| B8 | Reduce Motion and accessibility labels are respected | Inspection + HIL | unimplemented |

## C — Screen Guidance

| ID | Journey | Required evidence | Status |
| --- | --- | --- | --- |
| C1 | Screen permission is requested only after guide activation | Fresh-install recording | unimplemented |
| C2 | User can identify what will be captured | Installed recording | unimplemented |
| C3 | Capture excludes the app's own overlays where possible | Image comparison | unimplemented |
| C4 | Accessibility/OCR context is produced without storing a screenshot | Integration test + file audit | unimplemented |
| C5 | Local engine returns a useful explanation | Scenario corpus + HIL | unimplemented |
| C6 | Point cues are bounds-checked and confidence-gated | Property/unit tests | unimplemented |
| C7 | Low confidence produces prose without misleading pointing | Deterministic test | unimplemented |
| C8 | The guide never clicks, types, executes, or submits | Capability audit + HIL | unimplemented |
| C9 | Dictation remains available when guidance is unavailable | Failure-injection test | unimplemented |

## D — Distribution and Privacy

| ID | Journey | Required evidence | Status |
| --- | --- | --- | --- |
| D1 | Developer ID signed, notarized, stapled DMG | Mechanical report | unimplemented |
| D2 | HTTPS download carries quarantine and passes Gatekeeper | Installed report | unimplemented |
| D3 | Quit/relaunch does not cause permission loops | Installed recording | unimplemented |
| D4 | No audio, screenshots, or transcript history is stored by default | Filesystem/log audit | unimplemented |
| D5 | Diagnostics redact captured and dictated content | Fixture tests + export audit | unimplemented |
| D6 | No borrowed product identity, keys, feeds, or release destinations remain | Provenance/identity audit | unimplemented |

## Compatibility Matrix

The initial matrix is TextEdit, Notes, Chrome or Safari, Slack, and one code
editor used by the owner. Additional applications become explicit rows rather
than implied support claims.
