# HeyClicky 1.0.47 versus SERPy 0.1.0 build 30

Date: 2026-09-04  
Audit type: fresh-context, adversarial, read-only, clean-room differential  
Candidate branch/commit: `feat/6-heyclicky-talk-parity` at
`792267e2130325590b64b2c92bc90ff0f3803f34`  
Owner finding under test: **SERPy does not operate like HeyClicky and its
responses are materially worse.**

## Verdict

The owner's finding is supported. SERPy build 30 is not a faithful
reconstruction of HeyClicky Talk. It implements a locally processed sequence
that resembles the nouns in the journey—hotkey, microphone, capture, answer,
speech, cursor overlay—but replaces the reference's interaction model and its
core intelligence/audio pipeline. Those substitutions are user-visible and
explain both the clunky operation and weaker answers.

The highest-impact deviation is not cosmetic. Current HeyClicky takes visual
screen context to routed cloud/frontier models and supports spatial output;
SERPy reduces a single window screenshot to a short OCR-only text prompt and
asks Apple's small on-device text model for a maximum-55-word answer. SERPy
does not pass pixels, OCR geometry, or a structured UI tree to its model. It
therefore cannot understand non-text visual state the way the reference claims
and demonstrates, and it cannot produce reference-like pointing or drawings.

No parity claim is justified. The repository completion manifest remains red,
and the owner's rejection invalidates the earlier build-30 demo claim as human
acceptance evidence.

## Clean-room boundary

HeyClicky was treated only as an installed behavioral oracle. This audit did
not inspect or decompile its executable, copy its assets or identity, inspect
saved credentials or conversation history, change account/subscription/app
settings, invoke Agent mode, or perform autonomous computer use. The only
prepared work surface was an unsaved TextEdit document containing
`ORCHID RIVER 731`.

The current HeyClicky implementation is private. Its observable behavior may
be reconstructed independently, but its private code, assets, protocols, and
identity may not be copied. The older `farzaa/clicky` repository is a separate
MIT-licensed historical codebase. Importing any of that code into SERPy still
requires the repository's `PROVENANCE.md` gate.

## Frozen artifacts and environment

| Fact | HeyClicky reference | SERPy candidate |
|---|---|---|
| Installed path | `/Applications/HeyClicky.app` | `/Applications/SERPy.app` |
| Bundle identifier | `com.humansongs.clicky` | `com.serpcompany.guidecompanion.internal` |
| Version/build | `1.0.47 (56)`, confirmed by Info.plist and About panel | `0.1.0 (30)`, confirmed by Info.plist |
| Executable SHA-256 | `ace4a861b346b6bbe6844f19fa3177f85c10f3ee14381c9267cf0b353a16472d` | `361dfe88af104c0f8f8c6c3b8ee49025581a4ffa111c6e99cbfb89970c6aeedc` |
| Architecture | universal `x86_64 + arm64` | `arm64` |
| Minimum macOS | 14.2 | 14.2; local guidance separately requires macOS 26 |
| Signature | Developer ID, team `2UDAY4J48G`, secure timestamp; strict verification passed | Developer ID, team `847HR8U8D9`, secure timestamp; strict verification passed |
| Gatekeeper at audit time | accepted; notarized Developer ID | **rejected; reported as unnotarized Developer ID** |
| Relevant entitlements | audio input, camera, network client, ScreenCaptureKit picker exception; App Sandbox off | audio input only |

Environment: macOS 26.5.2 (25F84), built-in 3456×2234 Retina display, Dark
appearance, `en_US` locale, language order `en-US`, `ja-US`. TCC database state
was not readable without broadening access, so current permission grants are
UNRESOLVED. No permission was requested or changed.

Evidence:

- [reference idle/notch](evidence/heyclicky-1.0.47-vs-serpy-build-30/reference/idle-notch.jpeg)
- [reference About panel](evidence/heyclicky-1.0.47-vs-serpy-build-30/reference/about.jpeg)
- [controlled TextEdit surface](evidence/heyclicky-1.0.47-vs-serpy-build-30/comparisons/controlled-textedit-orchid-river-731.jpeg)
- [reference idle accessibility](evidence/heyclicky-1.0.47-vs-serpy-build-30/accessibility/idle-reference.txt)
- [candidate capture limitation](evidence/heyclicky-1.0.47-vs-serpy-build-30/accessibility/idle-candidate.txt)

The computer-control service could read HeyClicky's passive notch and About
surfaces. It timed out reading SERPy's installed process twice. That capture
limitation leaves paired candidate screenshots unresolved; it must not be
misrepresented as proof about SERPy's end-user rendering.

## Evidence classes

### Directly observed from installed apps

- HeyClicky 1.0.47 exposes a compact, edge-attached notch surface and no
  conventional Talk window in its passive state.
- Its accessibility tree names an ambient `HeyClicky companion status` rather
  than a chat window.
- About confirms installed version `1.0.47 (56)`.
- The exact installed SERPy binary is build 30 and hash-matches the branch build
  recorded earlier, but Gatekeeper currently rejects it as unnotarized.
- The candidate's passive accessibility capture is unresolved due to tool
  timeouts.
- No live microphone journey was performed by the audit agent. The skill and
  task require voice/hotkey rows to stay unresolved when they require the
  human; synthetic speech is not a substitute.

### Current first-party HeyClicky claims

The current product site says Talk is an out-loud conversation: pressing the
hotkey gives HeyClicky request-scoped screen visibility, and it walks the user
through visible work with spoken and drawn guidance. It says Talk works with
anything visible on screen and retains basic text summaries for context. Source:
<https://www.heyclicky.com/>.

The changelog states that the current product has:

- whole-document understanding and deeper-model routing for detailed or
  screen-related questions in 1.0.47;
- a per-question router choosing fast versus frontier models, warmed sessions,
  faster response, and less robotic conversational speech;
- progressive/hand-drawn spatial annotations and multi-step walkthrough state;
- microphone failover, Bluetooth playback pre-roll, muted-output recovery,
  region rerouting, long-answer completion, and more robust cold-start voice;
- user-configurable held or double-tap shortcuts;
- a hands-on voice/drawing/dictation onboarding instead of explanatory UI.

The web changelog now lists 1.0.48, while the installed oracle is 1.0.47. Claims
introduced only in 1.0.48 are current product direction, not proof of installed
1.0.47 behavior. Source: <https://www.heyclicky.com/changelog>.

### Older MIT Clicky facts

The historical open-source README documents a menu-bar app with a transparent
cursor overlay, streaming microphone audio to AssemblyAI, sending transcript
plus screenshot to Claude over streaming SSE, ElevenLabs speech, and model
generated `[POINT:...]` spatial tags. Those APIs are proxied by a Cloudflare
Worker. This is source-confirmed for older Clicky, not proof of current private
HeyClicky internals. Source: <https://github.com/farzaa/clicky>.

### Candidate code facts

SERPy build 30:

1. Captures one invocation-time `SCWindow` and runs Vision
   `VNRecognizeTextRequest` over it.
2. Filters OCR blocks below confidence 0.45, keeps at most 120 blocks, then
   supplies at most 4,000 text characters to the model.
3. Discards OCR bounds when constructing the prompt. The model receives plain
   text plus app/window names, not screenshot pixels, visual layout, controls,
   color, icons, diagrams, or images.
4. Creates a new Apple Foundation Models text session for each answer. It
   includes only the last six messages, each truncated to 500 characters.
5. Instructs the model to answer in fewer than 55 words.
6. Returns every plan at confidence `0.70` and never supplies a point. The
   validator requires at least `0.75`. Pointing is therefore unreachable in the
   production path by construction.
7. Waits for the complete model answer before starting
   `AVSpeechSynthesizer`. There is no model-output streaming or synchronized
   spatial guidance.
8. Uses Apple on-device speech recognition for input and basic system speech
   for output. It has no voice-speed control, Bluetooth pre-roll, muted-output
   recovery, built-in-mic failover, or response router.
9. Presents a 350-point status capsule plus a separate 380-point response
   panel. The response panel's height is clamped to the usable screen height
   and is not scrollable; long content can still exceed its hosting frame even
   though the string is not programmatically truncated.
10. Automatically clears the answer and follow-up affordance after eight
    seconds and holds conversation only in memory until quit.

## Differential matrix: surface × state × interaction × persistence

`FAIL` means a verified architecture or observable contract differs from the
reference target. `UNRESOLVED` means the exact installed voice behavior was not
directly exercised.

| Surface/state | Interaction | Persistence | HeyClicky target | SERPy build 30 | Result |
|---|---|---|---|---|---|
| Entry/discovery | Held/double-tap configurable voice gesture | User shortcut setting | Voice/shortcut is the product; no Talk window | Fixed Control–Option–G toggle plus menu/settings explanation | **FAIL** |
| Passive home | No input | Across app lifetime | Compact notch/ambient buddy | Cursor companion preference plus conventional menu | **FAIL** |
| Invocation | Voice shortcut | Per turn | Immediate ambient acknowledgement on work surface | Source intends forced cursor companion and `Listening…`; owner reports the journey still does not behave like reference | **UNRESOLVED/FAIL owner** |
| Focus | Start/finish Talk | Per turn | Work app remains the surface | Candidate uses nonactivating panels by code | **UNRESOLVED** installed |
| Listening | Speak naturally | Per turn | Ambient voice state integrated with notch/buddy | Separate cursor capsule, app/window metadata and partial text | **FAIL** interaction/geometry |
| Live transcript | Speak/continue | Ephemeral | Exact installed 1.0.47 geometry unresolved; current product is voice-native | Last 180 characters, prefixed ellipsis on truncation, up to three lines | **UNRESOLVED** reference geometry |
| Capture target | Press Talk shortcut | Request-scoped | Sees visible screen; whole-document context available in 1.0.47 | One locked window; concurrent capture begins just after transcription starts | **FAIL** context scope |
| Visual understanding | Ask about non-text UI | Per request | Screenshot/visual understanding and spatial reasoning | OCR text only; no pixels or geometry reach the model | **FAIL—critical** |
| Thinking | Finish question | Per turn | Warmed/routed fast or deep model with conversational feedback | Single local text model; complete answer awaited | **FAIL—critical** |
| Grounding quality | Ask `What unique phrase is visible?` | Per turn | Expected direct, grounded answer | OCR fixture exists; real Foundation Models quality rejected by owner | **UNRESOLVED/FAIL owner** |
| Useful guidance | Ask how to perform a visible task | Per turn | Understands visual controls and explains/draws route | Cannot identify unlabeled visual controls from OCR-only prompt | **FAIL—critical** |
| Spoken response | Listen/interruption | Per turn | Conversational tuned voice; current reliability recovery | Basic `AVSpeechSynthesizer`, starts only after full answer | **FAIL** |
| Response text | Read answer | ~transient | Spatial/transient companion delivery | Separate 380-point material rectangle; clears after 8 seconds | **FAIL** presentation language |
| Long answer | Ask complex question | Until completion | 1.0.47 removed hard 60-second cutoff | Prompt asks for ≤55 words; non-scrollable clamped panel | **FAIL** |
| Pointing | Ask where a control is | Per turn | Cursor flies/highlights/draws with spatial model output | Production result cannot pass point threshold | **FAIL—absent** |
| Drawing/walkthrough | Ask for steps | Multi-step | Progressive annotations and retained walkthrough goal | No drawing renderer or walkthrough state | **FAIL—absent** |
| Follow-up | Ask pronoun/dependent second turn | Basic summaries retained by reference service | Long conversational context | Last six in-memory messages, 500 chars each; cleared on quit | **FAIL** continuity depth; live row unresolved |
| Cancel/interruption | Escape/shortcut during each phase | Per turn | Current exact installed semantics unresolved | Code cancels owned task, microphone, speech, overlays | **UNRESOLVED** installed |
| Companion-off override | Start Talk with persistent buddy off | Preference should survive | Talk UI appears when Talk is invoked | Policy intends temporary override without changing preference | **UNRESOLVED**; owner rejected prior demo |
| Mic failure | Disconnect/wedge input | Until recovery | Current product fails over to built-in mic and explains | Ends with recovery text; no device failover | **FAIL** |
| Muted/Bluetooth output | Start response muted/cold | Per response | Clipboard/unmute recovery and Bluetooth pre-roll | No preflight, retained-answer recovery, or pre-roll | **FAIL** |
| Provider/region failure | Network/provider error | Per turn | Reroutes and communicates failures | Local-only; avoids network class but has no alternate model | **DIFFERENT**, not parity |
| Menu/notch | Click ambient surface | Across lifetime | Notch is a primary surface | Native menu is primary configuration/action surface | **FAIL** |
| Cursor edge placement | Move pointer to edge | Ephemeral | Adaptive companion/drawings; exact geometry unresolved | Capsule and rectangular panel clamp around pointer | **UNRESOLVED** visual comparison |
| Motion | Move pointer during output | Ephemeral | Spring-like buddy/spatial motion in demos | 30 Hz hard tracking; response is deliberately stationary once visible | **FAIL** motion language |
| Post-turn cleanup | Complete/cancel | Per turn | Ambient surface returns without a chat window | Eight-second forced clear, then preference restoration | **UNRESOLVED** installed |
| Relaunch memory | Quit/reopen | Cross-launch | Basic text summaries retained; deletable with account | Guide conversation deleted on quit | **FAIL** persistence contract |

## Precise root causes

### Why it does not operate like HeyClicky

1. **Wrong interaction shell.** HeyClicky centers the voice gesture and
   ambient notch/buddy. SERPy centers a native menu, a fixed toggle shortcut,
   explicit phase labels, a target label, and two generic material panels.
2. **Turn-taking is mechanical.** SERPy requires a start/stop toggle, then
   serially exposes Reading/Thinking/Speaking. The reference is designed as a
   warmed conversational audio session with response streaming and coherent
   ambient feedback.
3. **No spatial output.** SERPy's only usable answer form is prose in a box plus
   system speech. HeyClicky's defining teaching behavior is pointing, drawing,
   highlighting, and multi-step walkthroughs on the work surface.
4. **Different timing model.** SERPy waits for a complete local response before
   speech and discards the visible answer after a fixed eight seconds. The
   reference optimizes first-response latency, streams output, and lets deep
   answers run to completion.
5. **Settings explain instead of onboarding by doing.** The reference's current
   onboarding has the user speak, draw, circle, reply, and dictate. SERPy uses
   Settings copy and manual test controls.

### Why response quality is worse

1. **The model is blind to images.** SERPy throws away the screenshot after
   OCR. It cannot reason over icons, spatial relationships, charts, canvases,
   selection state, or non-text controls.
2. **The prompt flattens evidence.** OCR bounds exist but are discarded. Even
   textual controls lose their positions and hierarchy.
3. **The reasoning model is materially smaller.** SERPy uses Apple's local
   text model for every request. HeyClicky publicly says it routes complex and
   screen-related requests to deeper/frontier models.
4. **Context is shallow.** SERPy carries only six truncated messages and one
   newly OCR'd window. The reference advertises basic retained summaries,
   whole-document context, and preserved walkthrough goals.
5. **The answer budget suppresses useful teaching.** The hard instruction to
   stay under 55 words conflicts with multi-step explanation. A complete string
   may survive technically, but the model is explicitly discouraged from
   producing a deep answer.
6. **Grounding retries treat a symptom.** SERPy retries false “I can't see the
   app” language, but it does not add missing visual evidence. It can force a
   confident-sounding answer without improving perception.

## What can be fixed while remaining local-only

These changes can substantially improve feel without changing privacy policy:

- match the reference's held/double-tap, configurable voice gesture;
- make the ambient buddy/notch the only primary Talk surface;
- stream partial transcription and local model tokens into one coherent
  surface; remove the redundant status-plus-answer rectangles;
- remove the fixed eight-second answer loss and add explicit replay/copy;
- add local audio-device failover, muted-output detection, interruption
  recovery, voice selection/speed, and Bluetooth pre-roll;
- preserve a bounded local conversational summary with explicit controls;
- add hands-on onboarding and truthful recovery flows;
- feed accessibility hierarchy plus OCR bounds into the local model;
- implement a deterministic, locally validated pointing/drawing renderer once
  a model can return grounded geometry.

Those changes will improve UX, but they will not deliver HeyClicky-level
screen understanding or answer quality with the current Apple text model.

## What requires a different intelligence architecture

Faithful visual guidance needs one of:

1. **Explicit cloud/provider Talk path (recommended):** send the request-scoped
   screenshot and conversation to a strong multimodal model, use model routing,
   stream response text/audio, and return structured spatial annotations. Keep
   ordinary dictation local. This requires an owner-approved change to
   `PRODUCT.md`, `AGENTS.md`, privacy disclosure, data-retention policy,
   credentials/billing boundaries, and threat model.
2. **Bundled/downloadable local multimodal path:** ship a capable vision-language
   model and inference runtime. This preserves local processing but adds major
   download size, memory/thermal pressure, hardware compatibility, model
   licensing, and substantially higher implementation risk. It must be
   benchmarked on the minimum supported Mac before commitment.

Changing only SwiftUI geometry or prompts will not close the quality gap.

## PASS/FAIL/UNRESOLVED parity ledger

| ID | Acceptance behavior | Status | Evidence/reason |
|---|---|---|---|
| P01 | Installed identities frozen and independently distinguishable | **PASS** | Info.plist, executable hashes, signatures, About panel |
| P02 | Controlled non-sensitive work surface prepared | **PASS** | TextEdit `ORCHID RIVER 731` screenshot/AX |
| P03 | Voice-first entry matches gesture and discoverability | **FAIL** | fixed SERPy toggle/menu versus reference voice/shortcut-first shell |
| P04 | No conventional Talk window; work app stays primary | **UNRESOLVED** | reference passive state observed; candidate live turn needs HIL |
| P05 | Immediate listening acknowledgement | **UNRESOLVED** | microphone/global shortcut requires HIL |
| P06 | Live transcription matches behavior and geometry | **UNRESOLVED** | no human voice run; exact reference geometry unknown |
| P07 | Request captures intended context | **FAIL** | SERPy captures one window and reduces it to OCR text |
| P08 | Visual/non-text screen understanding | **FAIL** | no screenshot pixels or hierarchy reach candidate model |
| P09 | Grounded answer usefulness/quality | **FAIL** | owner rejection plus architecture gap; paired HIL still required |
| P10 | Low-latency conversational turn-taking | **FAIL** | complete local answer before TTS; no response streaming/router |
| P11 | Natural spoken output and recovery | **FAIL** | basic system TTS; no reference-class recovery controls |
| P12 | Readable complete response at cursor/notch | **UNRESOLVED** | candidate installed capture unavailable; owner previously observed clunky UI |
| P13 | Spoken follow-up continuity | **FAIL** | shallow in-memory six-message window, no retained summary/walkthrough state |
| P14 | Escape/interruption at every stage | **UNRESOLVED** | source-tested only; installed journey not exercised |
| P15 | Talk overrides buddy-off without changing preference | **UNRESOLVED** | source policy exists; owner's last HIL rejected overall demo |
| P16 | Spatial pointing | **FAIL** | candidate always returns no point at confidence below threshold |
| P17 | Progressive drawing/walkthrough | **FAIL** | absent from candidate production path |
| P18 | Edge/multi-display/Spaces/full-screen placement | **UNRESOLVED** | no paired installed run |
| P19 | Mic/mute/Bluetooth/provider failure recovery | **FAIL** | reference-class fallbacks absent |
| P20 | Post-turn cleanup and persistence match | **FAIL** | fixed eight-second clear and quit-time context loss differ |
| P21 | Exact installed SERPy is distribution-ready | **FAIL** | Gatekeeper reports unnotarized Developer ID |

Overall: **2 PASS, 13 FAIL, 6 UNRESOLVED. Not parity-verified.**

## Exact minimal behavior spec for the next implementation agent

This is the smallest coherent next slice. It must be implemented vertically,
not as disconnected UI tweaks.

1. A user-configurable held shortcut begins Talk immediately; an optional
   double-tap enters hands-free mode. Release/second double-tap ends speech;
   Escape cancels at any stage.
2. The active work app remains frontmost. No Talk/chat/settings window opens.
   One compact nonactivating ambient surface acknowledges input within 150 ms.
3. The surface streams partial transcript without hiding the referenced UI.
   It expands only as needed and never occupies menu-bar controls.
4. Invocation locks the intended app/window, but context acquisition provides
   the reasoning engine with request-scoped screenshot pixels plus structured
   Accessibility/OCR text and coordinates. Data is labeled untrusted.
5. A multimodal reasoning provider accepts screenshot, structured screen
   context, current question, and bounded conversational summary. It streams a
   concise spoken answer and optional typed spatial actions (`point`,
   `highlight`, `path`, `label`) with normalized coordinates and confidence.
6. Speech begins from streamed sentence chunks rather than waiting for the
   entire answer. Visible response text builds in sync and remains recoverable
   until the user dismisses it or starts the next turn.
7. Spatial actions are independently validated against the locked display/window
   and confidence policy before rendering. Unsupported/low-confidence actions
   degrade to prose; they never guess a location.
8. Follow-up invocation reuses a bounded summary plus fresh screen context and
   visibly indicates that the conversation is continuing.
9. Disconnecting the mic fails over to built-in input where possible. Muted
   output preserves the answer with replay/copy recovery. Every error names the
   failed stage and one action.
10. Talk temporarily shows the ambient companion regardless of the persistent
    buddy preference and restores the exact preference after completion or
    cancellation.
11. Add an interactive first-run tutorial that exercises real voice,
    contextual answer, one validated point/highlight, follow-up, cancel, and
    recovery on a benign built-in practice surface.
12. Do not call this slice complete until the exact signed/notarized installed
    artifact passes paired reference/candidate HIL at matching screen geometry.

## Human-only steps needed

Use the exact installed paths and a screen recording cropped to TextEdit plus
the ambient UI. Do not show other apps, menu-bar private data, notifications,
or account surfaces.

1. Quit neither app and change no settings. With `ORCHID RIVER 731` visible in
   TextEdit, record the exact configured HeyClicky Talk shortcut, then the SERPy
   Control–Option–G journey separately.
2. For each app, say: **“What unique phrase is visible?”** Record timestamps for
   gesture, first visible acknowledgement, first transcript text, end of speech,
   thinking indication, first audible word, final audible word, and UI cleanup.
3. Score the exact answer on phrase accuracy, directness, useful next step,
   hallucination, naturalness, and whether any text is clipped.
4. Replace the text with `COBALT HARBOR 924`. Ask **“What changed?”** Record
   whether the answer uses the prior turn and fresh context.
5. Repeat at the four screen corners and once with the cursor beneath crowded
   menu-bar icons. Record overlap, clipping, focus theft, and movement.
6. With persistent companion/buddy visibility off, start Talk, finish, and
   cancel once. Verify temporary appearance and exact preference restoration.
7. Run Escape separately during listening, capture/reading, thinking, and
   speaking. Verify microphone/speech stop, no delayed answer appears, and the
   next turn works without relaunch.
8. Ask about one non-text icon in a benign test window. This must remain a FAIL
   for SERPy's current OCR-only engine unless it correctly grounds the icon.
9. Do not invoke HeyClicky Agent mode or allow any click/type action. Stop if a
   controlled TextEdit-only capture cannot be guaranteed.

## Architecture recommendation

**Change the Talk architecture; keep dictation local.** Continue to offer local
Apple Speech for no-cost dictation, but do not represent the current OCR plus
Apple text-model path as a HeyClicky-quality guide. For Talk, adopt an explicit,
opt-in, request-scoped cloud multimodal provider with streaming response/audio
and structured spatial output, or pause parity work while a capable local
multimodal model is benchmarked and proven on the minimum Mac.

The cloud route is the shortest credible path to the owner's stated quality
target. It is not currently authorized by the repository's local-only boundary,
so the next implementation must begin with an owner-approved product/privacy
ADR and policy change. Until that decision, local-only work should be limited
to interaction-shell, audio-recovery, and accessibility improvements and must
not be described as HeyClicky parity.
