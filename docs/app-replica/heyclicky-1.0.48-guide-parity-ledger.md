# HeyClicky 1.0.48 versus SERPy Guide parity ledger

Date frozen: 2026-09-04  
Reference: installed `/Applications/HeyClicky.app` `1.0.48 (57)`  
Rejected candidate: installed `/Applications/SERPy.app` `0.1.0 (39)`  
Replacement branch: `codex/heyclicky-guide-rebuild` from `ef12f96`

Statuses describe installed evidence, not source intent. `FAIL` means a directly
observed mismatch or an architecture that cannot produce the required behavior.
`UNRESOLVED` means the row was not safely exercised. `UNTESTED` means the new
replacement artifact does not exist yet.

## Frozen observations

| Row | Surface × state × interaction × persistence | Reference observation | Rejected build 39 observation | Status |
| --- | --- | --- | --- | --- |
| G01 | Passive ambient surface × idle × no input × app lifetime | Edge-attached black notch with one `HeyClicky companion status` AX element | 46×46 cursor badge with `SERPy is ready`; no notch relationship | **FAIL** |
| G02 | Guide entry × ready × global gesture × persisted shortcut | Hold Control–Option; release sends. Dedicated Change control is present | Fixed Control–Option–G toggle disclosed in Settings | **FAIL** |
| G03 | Guide entry × TextEdit frontmost × invoke × one turn | Must acknowledge without activating a Guide window | Controlled synthetic Control–Option–G delivered a control character to TextEdit; SERPy remained ready | **FAIL**; physical-key HIL still required |
| G04 | Work-surface focus × all active phases × invoke/cancel × one turn | Product behavior targets the current app as the work surface | Nonactivating panels exist in source; rejected installed journey not proven | **UNRESOLVED** |
| G05 | Ambient surface × listening × hold gesture × one turn | Compact listening state integrated with the top ambient surface | No installed listening state captured | **UNRESOLVED** |
| G06 | Ambient surface × live transcription × speak × ephemeral | Readable voice-native feedback; exact 1.0.48 geometry unresolved | No installed live transcript captured | **UNRESOLVED** |
| G07 | Capture × invocation target × begin turn × request-scoped | Current visible work is available to Talk | Build 39 source locks PID/window ID/frame; installed exact-window behavior unobserved | **UNRESOLVED** |
| G08 | Capture × self-overlay visible × capture × request-scoped | Own UI should not pollute reasoning context | Source attempts exclusions; no paired captured raster exists | **UNRESOLVED** |
| G09 | Thinking × request accepted × wait × one turn | Compact ambient progress with routed multimodal reasoning | Local is default; OpenAI is opt-in; no live paid call made | **UNRESOLVED** |
| G10 | Response × first text delta × stream × one turn | Answer should begin promptly and grow without a chat window | Streaming contract exists; installed growth not observed | **UNRESOLVED** |
| G11 | Response × complete text × read × until dismissed/next turn | Complete readable transient guidance | Build 39 uses a separate cursor-adjacent response panel; owner rejected the result | **FAIL owner** |
| G12 | Response × long answer × scroll/recover × one turn | Long answers complete without silent cutoff | Source supports overflow scroll; exact installed behavior unobserved | **UNRESOLVED** |
| G13 | Speech × streamed sentence × listen × one turn | Conversational ordered speech with failure recovery | Local system TTS queue is source-tested; installed audio unobserved | **UNRESOLVED** |
| G14 | Follow-up × ready × invoke second turn × conversation lifetime | Dependent spoken follow-up with fresh screen context | Bounded memory exists; no installed two-turn voice run | **UNRESOLVED** |
| G15 | Point cue × high confidence × answer × one turn | Spatial guidance on the visible target | Source has one normalized point/ring only; installed cue absent | **FAIL/unresolved** |
| G16 | Draw/walkthrough × multi-step × answer/progress × conversation | Progressive paths/outlines/labels synchronized with guidance | No production renderer or walkthrough state | **FAIL** |
| G17 | Escape × listening × cancel × one turn | Stops owned work and returns ambient UI | Source-tested only | **UNRESOLVED** |
| G18 | Escape × capture/thinking/speaking × cancel × one turn | Stops every phase; no delayed answer | Source-tested only | **UNRESOLVED** |
| G19 | Microphone × unavailable/disconnected × start/recover × until fixed | Truthful failure and reference-class failover behavior | No built-in-device failover; installed error unobserved | **FAIL** |
| G20 | Output × muted/Bluetooth cold × speak/recover × one answer | Preserve answer with audible recovery/pre-roll | No output preflight or Bluetooth pre-roll | **FAIL** |
| G21 | Provider × missing/invalid/expired credential × start × device setting | Clear block; never send or silently fall back | Deterministic authorization contracts exist; installed recovery unobserved | **UNRESOLVED** |
| G22 | Provider × network/stream failure × retry/recover × one turn | Compact truthful recovery | No live provider failure exercised | **UNRESOLVED** |
| G23 | Companion preference × off × active Talk × persisted preference | Talk surface appears transiently and off is restored | Source policy exists; owner rejected build-39 journey | **UNRESOLVED** |
| G24 | Menu/notch × ambient active × click other menu items × app lifetime | Must not obstruct system/menu controls | Reference notch is edge attached; candidate cursor follows pointer; crowded-menu test absent | **UNRESOLVED** |
| G25 | Geometry × screen corners/Dock/menu bar × move pointer × one turn | Adaptive, readable, non-obstructive | Unit geometry exists; paired installed observation absent | **UNRESOLVED** |
| G26 | Geometry × multiple/negative-origin displays × move/point × session | Correct display and coordinate mapping | Source tests only | **UNRESOLVED** |
| G27 | Spaces/full screen × active overlay × app switch × session | Companion follows permitted work surface without focus theft | Source collection behavior only | **UNRESOLVED** |
| G28 | Accessibility × all states × VoiceOver/Reduce Motion × setting lifetime | Exact reference accessibility remains unresolved | Labels/reduced motion source paths exist; installed HIL absent | **UNRESOLVED** |
| G29 | Settings × closed/open/reopen × menu/Command-comma × app lifetime | Normal Settings route exists; reference window is normal | Build 38 foreground/reopen was installed-observed; build 39 visual redesign is owner-rejected | **FAIL build 39 UX** |
| G30 | Privacy × completed/cancelled/error turn × quit/relaunch × device lifetime | Reference service persistence is a declared difference | SERPy promises ephemeral Guide content; final filesystem/log audit absent | **UNRESOLVED** |
| G31 | Distribution × reviewed package × install/launch × installed identity | Notarized Developer ID accepted | Build 39 strict signature passes but Gatekeeper rejects it as unnotarized | **FAIL** |
| G32 | Product identity × all surfaces × use × release lifetime | Behavioral oracle only | SERPy name, bundle, and owner assets remain distinct | **PASS boundary only** |

## Paired evidence inventory

- Reference passive notch: `evidence/heyclicky-1.0.48-vs-serpy-build-39/reference/passive-notch.jpeg`
- Reference shortcuts: `evidence/heyclicky-1.0.48-vs-serpy-build-39/reference/shortcuts.jpeg`
- Rejected candidate passive cursor: `evidence/heyclicky-1.0.48-vs-serpy-build-39/candidate/passive-cursor.jpeg`
- Rejected candidate Guide Settings: `evidence/heyclicky-1.0.48-vs-serpy-build-39/candidate/guide-settings.jpeg`
- Controlled TextEdit work surface: `evidence/heyclicky-1.0.48-vs-serpy-build-39/comparisons/controlled-textedit-orchid-river-731.jpeg`
- Sanitized AX captures are in the sibling `accessibility/` directory.

The Settings screenshot containing the reference account email was deliberately
not committed. Dynamic/private regions must be masked before future evidence is
stored.

## Accepted public test seams

Issue #6 and the owner request already name the public seams used for TDD:

1. one global-shortcut coordinator for registration, delivery, consumption,
   held/released/toggle semantics, and Escape cancellation;
2. `GuideTurnCoordinator` for state ownership, exact target lock, provider and
   speech ordering, cancellation, and conversation continuity;
3. `CompanionResponseLayoutPolicy` and spatial projector/validator contracts
   for safe geometry;
4. provider protocols and serialized request/event contracts at the local and
   OpenAI system boundaries;
5. `GuideTurnOverlayPresenting` for provider-neutral ambient presentation.

Tests must use these public interfaces. Installed UI, microphone, OS permission,
focus, speech audibility, and provider quality remain HIL evidence and cannot be
promoted by mocks.

## Next differential loop

The first replacement slice is the global held-shortcut path because the exact
installed build failed before listening began. After red→green tests and source
review, build a unique Developer ID artifact, remove stale LaunchServices
copies, install and hash-match it, then repeat G02–G06 with TextEdit frontmost.
Do not advance response/provider rows merely because shortcut invocation works.
