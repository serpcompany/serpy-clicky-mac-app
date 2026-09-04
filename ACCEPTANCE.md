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
| B1 | Idle shows no persistent cursor-following badge | Policy test + installed observation | unit-tested |
| B2 | Dictation and Guide surfaces appear only while meaningful and clear deterministically | Lifecycle test + installed observation | unit-tested |
| B3 | The running app remains available through Dock and Command-Tab after Settings closes | Policy test + installed observation | unit-tested |
| B4 | Rejected persistent-companion controls are absent from menu and Settings | Source inspection + installed observation | implemented |
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
| C12 | Guide answers appear in the stable top-centered ambient surface and are spoken locally | Installed audio observation | implemented |
| C13 | Active guide turns force the companion visible without changing a disabled saved preference | Policy test + installed preference-off lifecycle | installed-observed |
| C14 | A streamed answer grows from its first delta while remaining edge/status-safe and click-through; the optional transcript window preserves overflow | Small→medium→maximum layout/interaction sequences + installed corner observation | unit-tested |
| C15 | Each turn locks PID, exact window ID, app/title, frame, and display before presentation and never falls back to a sibling window | Policy/adapter tests + installed same-app multi-window observation | unit-tested |
| C16 | Escape cancels the owned listening, capture, thinking, or speaking work and restores companion visibility idempotently | Coordinator tests + installed phase-by-phase observation | unit-tested |
| C17 | Listening acknowledgement precedes capture work and Vision OCR never blocks the main actor | Coordinator ordering + adapter contract test + installed latency observation | unit-tested |
| C18 | Cloud Talk is disabled by default and sends nothing without disclosure, explicit selection, credential, and unexpired content-free provider verification | Deterministic authorization, verification, and request-serialization tests | unit-tested |
| C19 | OpenAI Talk sends only the exact request-scoped raster, question, and bounded recent Talk context with response storage disabled | Request fixture + owner-controlled HIL | unit-tested |
| C20 | Structured output requires a non-empty answer plus optional point; Unicode-safe answer deltas remain ordered, complete text is preserved, and speech receives each complete sentence once | JSON-schema/SSE/grapheme-split and speech-queue tests + installed observation | unit-tested |
| C21 | Cloud cancellation terminates URLSession streaming, queued speech, and overlays without a delayed answer | Blocking URLProtocol + coordinator cancellation fixtures + installed observation | unit-tested |
| C22 | Spatial points are exact-screenshot-bound, confidence-gated, projected across the locked Quartz/AppKit display, and rendered as a window-bounded click-through cue without pointer movement/click | Validator/projector/coordinator tests + controlled one-point HIL | unit-tested |
| C23 | Provider-neutral responses retain ordered steps and show only the active validated cue as `Step n of m` | Local/OpenAI fixtures + coordinator test + installed Chrome/Slack walkthrough | unit-tested |
| C24 | Explicit reinvocation captures fresh context and returns advance, stay with reason, or complete without polling or autonomous action | Pure progression/coordinator tests + installed multi-turn walkthrough | unit-tested |
| C25 | Visible and spoken step text is sanitized, ordered, deduplicated, and cancellation clears queued/late output including ready-for-follow-up | Speech/coordinator tests + installed audio/cancellation observation | unit-tested |

The owner reported that the guidance journeys after the initial companion
checks did not work during first use. The C rows above describe implementation
or earlier bounded evidence only; none should be read as owner acceptance of
the current build.

Build 39 is explicitly rejected by the owner and is not a functional or UX
baseline. A fresh installed freeze reproduced a failed controlled
Control–Option–G invocation in TextEdit and Gatekeeper rejection of the
unnotarized app. Branch `codex/heyclicky-guide-rebuild` restarts from build 38,
uses one injected shortcut monitor with a persisted held Guide chord, and moves
active Guide states to one target-display ambient surface. These are source and
test facts only; C10 and all installed Guide rows remain red until a unique
signed artifact is installed, hash-matched, and exercised with physical voice,
focus, answer, speech, follow-up, cancellation, and point evidence.

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
non-lossy answer presentation. These are source and test results only. The branch
artifact is not installed, hash-matched, or owner-observed; its ambient journey,
audible output, focus retention, follow-up, and every cancellation phase remain
red until the HIL is completed against that exact artifact.

Build 34 adds an explicit, disabled-by-default OpenAI multimodal Talk adapter.
Authorization, exact-window raster construction, bounded context, Keychain
storage, content-free credential verification, SSE ordering, sentence-queue
delivery, immediate/coordinator/URLSession cancellation, spatial validation,
negative-origin projection, and click-through cue presentation are unit-tested
without a live provider call. The signed artifact,
provider access, answer quality, cost, disclosure comprehension, installed
streaming/audio behavior, and filesystem privacy audit remain red until
`docs/hil/serpy-build-34-openai-talk-demo.md` is completed by the owner.

Issue #7 source work on `codex/issue-7-guide-parity` removes `LSUIElement`,
defines regular lifetime presence, removes the rejected idle cursor badge,
makes Guide overlays click-through, adds ordered provider-neutral walkthrough
plans and explicit fresh-capture progression, presents one active `Step n of m`
cue, and sanitizes/deduplicates ordered speech. Build 42 installs the reviewed
source at commit `badc0b0a`, hash-matches the retained Release executable,
passes Gatekeeper as a notarized Developer ID app, runs as a foreground app
without `LSUIElement`, and presents one normal `SERPy Settings` window on launch
and Dock reopen. Package tests (129) and UI tests (2) pass. Physical voice,
work-app focus/hit testing, Chrome/Slack progression, audible output,
accessibility/motion, multi-display/Spaces/full-screen, device recovery, and
owner acceptance remain red.

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
