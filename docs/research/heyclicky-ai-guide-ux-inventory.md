# HeyClicky voice-guide UI/UX inventory

Status: reference research, not a parity claim  
Observed: 2026-09-04  
Scope: the voice-first Talk/computer-guide journey defined in
[`docs/app-replica/scope.md`](../app-replica/scope.md), excluding agents,
accounts, cloud architecture, product identity, and private implementation.

## Method and evidence limits

This inventory uses only first-party public evidence:

- [HeyClicky homepage and FAQ](https://www.heyclicky.com/),
  [trust page](https://www.heyclicky.com/trust), and
  [changelog](https://www.heyclicky.com/changelog).
- The six public videos embedded by HeyClicky on its homepage:
  [`heyclicky-draw.mp4`](https://www.heyclicky.com/assets/heyclicky-draw.mp4),
  [`usecase.mp4`](https://www.heyclicky.com/assets/usecase.mp4),
  [`it-draws-too-omg.mp4`](https://www.heyclicky.com/assets/it-draws-too-omg.mp4),
  [`daddyshome.mp4`](https://www.heyclicky.com/assets/daddyshome.mp4),
  [`nohandstricklol.mp4`](https://www.heyclicky.com/assets/nohandstricklol.mp4),
  and [`hello.mp4`](https://www.heyclicky.com/assets/hello.mp4).
- The older, public MIT-licensed [Clicky repository](https://github.com/farzaa/clicky),
  especially its [README](https://github.com/farzaa/clicky/blob/main/README.md),
  [`OverlayWindow.swift`](https://github.com/farzaa/clicky/blob/main/leanring-buddy/OverlayWindow.swift),
  [`CompanionResponseOverlay.swift`](https://github.com/farzaa/clicky/blob/main/leanring-buddy/CompanionResponseOverlay.swift),
  and [`CompanionManager.swift`](https://github.com/farzaa/clicky/blob/main/leanring-buddy/CompanionManager.swift).

The public videos are edited promotional recordings, often filming a laptop at
480×270 or 270×480. Their large white subtitles are video-editor captions, not
necessarily product UI. Timing below is therefore approximate. The current
HeyClicky binary was not downloaded, run, inspected, or decompiled; no account
or gated experience was used. Public Clicky source is architectural evidence
for the older open-source version, not proof of current HeyClicky behavior.

Labels used below:

- **Observed** — directly visible or stated in first-party material.
- **Source-confirmed (older Clicky)** — explicit in the public Clicky source.
- **Inference** — a product recommendation or interpretation, not an observed
  HeyClicky fact.

## The experience model

HeyClicky's public framing is deliberately not “open a chat window.” It says the
product lives on the Mac, the user presses a hotkey, asks aloud, and is walked
through what is on screen. The FAQ calls Talk “the conversation,” distinguishes
it from agents, and says screen access happens only when the hotkey is pressed.
The changelog is even more explicit: “there's no window and no buttons to click
around, it lives in your voice and your keyboard shortcut.”
([homepage FAQ](https://www.heyclicky.com/#faq),
[changelog v1.0.40](https://www.heyclicky.com/changelog))

The resulting UI model is ambient and layered:

1. A persistent buddy/cursor gives the product a visible home.
2. A hardware-notch surface communicates voice state without opening a normal
   window.
3. The current app remains the work surface.
4. Guidance appears spatially as speech, transient text, highlighting, pointing,
   or drawings on that work surface.
5. The next spoken turn continues the conversation.

This is the most important reference lesson for SERPy: the conversation should
feel like a mode layered over the user's current task, not like navigation into
another app.

## Observable journey inventory

### 1. Entry points and invocation

**Observed:** The default Talk interaction is invoked from a global hotkey. The
FAQ says “press the hotkey,” while current changelog entries identify
Control+Option as push-to-talk and Control pressed three times as the experimental
always-on mode. Current releases also allow held combinations or double-tap
shortcuts configured by the user.
([FAQ](https://www.heyclicky.com/#faq),
[v1.0.42](https://www.heyclicky.com/changelog),
[v1.0.48](https://www.heyclicky.com/changelog))

**Observed:** `usecase.mp4` 00:08–00:21 demonstrates always-on mode, says it is
activated by pressing Control three times, and then asks a question without
holding keys. The same changelog limits always-on mode to headphones and labels
it experimental.
([`usecase.mp4`](https://www.heyclicky.com/assets/usecase.mp4),
[v1.0.31](https://www.heyclicky.com/changelog))

**Observed:** As of v1.0.27, the menu-bar icon was removed and the hardware notch
became HeyClicky's only home. The notch can also expose actions such as adding a
skill, and update/error cards are reported there.
([v1.0.27](https://www.heyclicky.com/changelog),
[v1.0.33 and v1.0.48](https://www.heyclicky.com/changelog))

**SERPy now:** Build 27 exposes Voice Guide in a concise native menu and uses
Control–Option–G. This is platform-conventional and accessible, but it means the
menu is still a primary discovery surface while the reference product treats
the ambient surface/hotkey as primary.
([`MenuPanelView.swift`](../../Packages/GuideModules/Sources/GuideUI/MenuPanelView.swift),
[`PRODUCT.md`](../../PRODUCT.md))

### 2. Listening and live transcription

**Observed:** In `heyclicky-draw.mp4` around 00:17–00:23, invoking Talk expands a
black pill around the MacBook notch. It initially reads “Listening”; while the
question is spoken, the pill displays a short, live textual rendering of the
utterance. A colored audio/waveform treatment is visible at the pill's right
edge. The current app remains active beneath it.
([`heyclicky-draw.mp4`](https://www.heyclicky.com/assets/heyclicky-draw.mp4))

**Observed:** In `usecase.mp4` around 00:20–00:22, the always-on notch surface is
a slim black horizontal bar with “Always on” and a cyan/blue waveform indicator.
The user can keep speaking across successive questions without returning to a
window.
([`usecase.mp4`](https://www.heyclicky.com/assets/usecase.mp4))

**Source-confirmed (older Clicky):** The public implementation models voice as
idle, listening, processing, and responding; it publishes audio power and swaps
the cursor presentation between a triangle, waveform, spinner, and response.
([`CompanionManager.swift`](https://github.com/farzaa/clicky/blob/main/leanring-buddy/CompanionManager.swift),
[`OverlayWindow.swift`](https://github.com/farzaa/clicky/blob/main/leanring-buddy/OverlayWindow.swift))

**SERPy now:** The cursor bubble changes to a red waveform and expands to a
250×58 capsule. Partial transcript text is limited to two lines and the last 90
characters. This is truthful, but the fixed small geometry causes a long spoken
question or answer to feel cramped and truncated.
([`CompanionPanelController.swift`](../../Packages/GuideModules/Sources/GuideUI/CompanionPanelController.swift),
[`GuideAppModel.swift`](../../Packages/GuideModules/Sources/GuideUI/GuideAppModel.swift))

### 3. Screen-context indication

**Observed:** HeyClicky says it sees the screen only when the Talk hotkey is
pressed; raw screenshots are not stored, but the prompt and AI-generated
screenshot analysis are retained by current HeyClicky. Its trust page also says
the hotkey event notes open apps and the current browser domain.
([trust page](https://www.heyclicky.com/trust),
[FAQ](https://www.heyclicky.com/#faq))

**Observed:** `heyclicky-draw.mp4` 00:23–00:28 verbally describes taking a
screenshot and returning drawing coordinates. The video does not show a distinct
“screenshot taken” confirmation separate from the notch/cursor state.
([`heyclicky-draw.mp4`](https://www.heyclicky.com/assets/heyclicky-draw.mp4))

**SERPy now:** It begins request-scoped context capture when listening starts,
then captions “Reading this screen…” after the second hotkey. The optional
transcript window labels the captured app/window, but the normal ambient flow
does not identify that target by name.
([`GuideAppModel.swift`](../../Packages/GuideModules/Sources/GuideUI/GuideAppModel.swift),
[`GuideConversationWindowController.swift`](../../Packages/GuideModules/Sources/GuideUI/GuideConversationWindowController.swift))

### 4. Thinking and latency feedback

**Observed:** The official clips keep the user in place between question and
answer. A compact notch/cursor state remains the likely activity affordance, but
the low-resolution, edited videos do not establish exact current labels,
spinner geometry, or latency budgets. Changelog entries show that perceived
latency is treated as a first-class UX problem: session/network warm-up, model
routing for fast versus deep questions, and removal of narrated web lookups.
([v1.0.45–1.0.46](https://www.heyclicky.com/changelog))

**Source-confirmed (older Clicky):** The cursor changes to a processing spinner;
response streaming can begin before the entire answer is complete.
([`OverlayWindow.swift`](https://github.com/farzaa/clicky/blob/main/leanring-buddy/OverlayWindow.swift),
[`CompanionManager.swift`](https://github.com/farzaa/clicky/blob/main/leanring-buddy/CompanionManager.swift))

**SERPy now:** The cursor caption advances through “Understanding…,” “Reading
this screen…,” and “Thinking locally….” Those are accurate stages, but each is
presented in the same small capsule, with no elapsed-time or progressive fallback
for a slow local model.
([`GuideAppModel.swift`](../../Packages/GuideModules/Sources/GuideUI/GuideAppModel.swift))

### 5. Response display and spoken output

**Observed:** Talk answers aloud. The homepage describes an AI buddy that can
talk, and the public demonstrations are continuous spoken exchanges. Changelog
work includes adjustable voice speed, calmer speech, Bluetooth pre-roll, and a
muted-output fallback that copies the answer and presents an Unmute action in
the notch.
([homepage](https://www.heyclicky.com/),
[v1.0.45 and v1.0.48](https://www.heyclicky.com/changelog))

**Observed:** Guidance is spatial. In `heyclicky-draw.mp4` 00:28–00:54, red/pink
lines, squares, arrows, and compact labels appear on top of a paused YouTube
diagram as the spoken explanation progresses. In `usecase.mp4` 00:31–01:40,
successive drawings point out a route, a musical measure, parts of a triangle,
and a properties editor. The drawing builds in sync with speech rather than
appearing as one static result.
([`heyclicky-draw.mp4`](https://www.heyclicky.com/assets/heyclicky-draw.mp4),
[`usecase.mp4`](https://www.heyclicky.com/assets/usecase.mp4))

**Observed:** The current changelog says drawings became hand-drawn/
Excalidraw-like; highlights disappear after two seconds, while explanatory
polygons remain while speech plays and then clear. Walkthroughs can advance when
the user clicks the instructed target.
([v1.0.40](https://www.heyclicky.com/changelog),
[v1.0.31 and v1.0.26](https://www.heyclicky.com/changelog))

**Source-confirmed (older Clicky):** The public cursor overlay is click-through,
cross-space, and screen-level. Its buddy follows the pointer with spring motion,
can fly on a curved path toward a detected target, grows to roughly 1.3× during
flight, rotates toward travel, and presents a small blue speech bubble at the
destination. Its separate response bubble tracks the cursor at 60 fps, caps at
340 points wide, flips/clamps at screen edges, keeps the final text for six
seconds, then fades over 0.4 seconds.
([`OverlayWindow.swift`](https://github.com/farzaa/clicky/blob/main/leanring-buddy/OverlayWindow.swift),
[`CompanionResponseOverlay.swift`](https://github.com/farzaa/clicky/blob/main/leanring-buddy/CompanionResponseOverlay.swift))

**SERPy now:** The answer is spoken locally and placed wholesale into the same
250×58, two-line cursor capsule. A 55-word answer therefore cannot remain fully
readable there, even though the optional normal transcript window preserves the
in-memory turn.
([`LocalGuidanceService.swift`](../../Packages/GuideModules/Sources/GuideMac/LocalGuidanceService.swift),
[`CompanionPanelController.swift`](../../Packages/GuideModules/Sources/GuideUI/CompanionPanelController.swift),
[`GuideConversationWindowController.swift`](../../Packages/GuideModules/Sources/GuideUI/GuideConversationWindowController.swift))

### 6. Follow-up continuity

**Observed:** The FAQ defines Talk as a conversation. `heyclicky-draw.mp4`
01:59–02:09 says the user can “keep going” and ask about more steps.
`nohandstricklol.mp4` 00:03–01:40 demonstrates many voice turns without opening a
chat window, although much of that clip shows autonomous actions outside SERPy's
authorized scope. Changelog entries explicitly mention long conversations and
walkthrough context surviving “continue.”
([FAQ](https://www.heyclicky.com/#faq),
[`heyclicky-draw.mp4`](https://www.heyclicky.com/assets/heyclicky-draw.mp4),
[`nohandstricklol.mp4`](https://www.heyclicky.com/assets/nohandstricklol.mp4),
[v1.0.48](https://www.heyclicky.com/changelog))

**SERPy now:** Recent turns remain in memory, every follow-up captures fresh
context, and the user starts the next turn with the same hotkey. This is
functionally aligned, but there is no ambient visual cue distinguishing “ready
for a follow-up in this conversation” from ordinary idle/ready state.
([`GuideAppModel.swift`](../../Packages/GuideModules/Sources/GuideUI/GuideAppModel.swift),
[`ARCHITECTURE.md`](../../ARCHITECTURE.md))

### 7. Cancellation, permissions, and recovery

**Observed:** Current HeyClicky offers configurable hold/double-tap shortcuts,
hands-free stop, and cancel. Its onboarding is hands-on: users speak a first
hello, watch a drawing, circle something, draft a reply, and test dictation in a
real field. It reports microphone fallback in the notch rather than silently
remaining broken, and retains/copies a reply when audio output is muted.
([v1.0.34–1.0.40 and v1.0.48](https://www.heyclicky.com/changelog))

**Observed:** The older Clicky README lists Microphone, Accessibility, Screen
Recording, and Screen Content permissions and directs setup through its menu-bar
panel. It does not document an accessible error-state matrix.
([Clicky README](https://github.com/farzaa/clicky/blob/main/README.md))

**SERPy now:** A second Control–Option–G finishes the utterance; Escape cancels
only while listening. Missing microphone/speech/screen permission produces a
stage-specific message and directs the user to Settings. During model processing,
the shortcut is ignored and Escape does not cancel. The native menu contains a
visible Cancel Voice Question action only while listening.
([`GuideAppModel.swift`](../../Packages/GuideModules/Sources/GuideUI/GuideAppModel.swift),
[`GuidanceState.swift`](../../Packages/GuideModules/Sources/GuideCore/GuidanceState.swift),
[`MenuPanelView.swift`](../../Packages/GuideModules/Sources/GuideUI/MenuPanelView.swift))

### 8. Accessibility, geometry, motion, and privacy

**Observed:** First-party HeyClicky material supplies visible state text in the
notch and on-screen drawings, but publishes no VoiceOver, keyboard-focus,
contrast, Reduce Motion, or Switch Control evidence. The low-resolution videos
also do not prove behavior with a hidden/not-present hardware notch, multiple
display scales, or crowded menu bars.

**Source-confirmed (older Clicky):** Overlays ignore mouse events, appear across
Spaces and full-screen apps, and create one transparent overlay per display.
Response geometry flips at the right edge and moves above the pointer near the
bottom edge. The public source uses continuous spring/flight animation but does
not expose a Reduce Motion branch in the referenced overlay code.
([`OverlayWindow.swift`](https://github.com/farzaa/clicky/blob/main/leanring-buddy/OverlayWindow.swift),
[`CompanionResponseOverlay.swift`](https://github.com/farzaa/clicky/blob/main/leanring-buddy/CompanionResponseOverlay.swift))

**SERPy now:** The companion is a nonactivating, mouse-ignoring panel, clamped to
the current display's visible frame and updated at 30 fps. It joins all Spaces,
supports full-screen auxiliary placement, and has a combined accessibility
label. It checks Reduce Motion, but both branches currently set the panel frame
without animation, so the setting does not yet create a meaningful behavioral
difference.
([`CompanionPanelController.swift`](../../Packages/GuideModules/Sources/GuideUI/CompanionPanelController.swift))

**Privacy difference:** HeyClicky's current service is cloud-processed and keeps
prompts plus generated screenshot analysis; SERPy's product contract is local,
request-scoped, and keeps guide conversation only in memory until quit. SERPy
must preserve its stricter contract rather than reproduce HeyClicky's storage or
cloud behavior.
([HeyClicky trust page](https://www.heyclicky.com/trust),
[`PRODUCT.md`](../../PRODUCT.md),
[`ARCHITECTURE.md`](../../ARCHITECTURE.md))

## Prioritized SERPy UI/UX backlog

This backlog seeks behavioral clarity, not HeyClicky branding or pixel copying.
It stays inside SERPy's local, non-operating guide boundary.

### P0 — make a voice turn feel like one continuous ambient interaction

**Change:** Replace the single fixed caption treatment with a deterministic
presentation state model for ready → listening/live transcript → capturing →
thinking → speaking → ready-for-follow-up → error/cancelled. Keep the user's app
frontmost throughout and never open the transcript window automatically.

**Acceptance criteria:**

- Control–Option–G produces visible acknowledgement within 150 ms in an installed
  build, without activating SERPy.
- Every internal guide phase maps to one truthful, visually distinct presentation.
- The current question remains legible while listening without exposing only an
  unexplained trailing fragment.
- The spoken answer, cancellation, and failure always end in an explicit
  ready-for-follow-up or recovered state; no indefinite spinner is possible.
- The same interaction passes on a normal Space, another Space, and a full-screen
  app without intercepting a click.

### P0 — make answer text readable without becoming a chat window

**Change:** Give spoken answers an adaptive, edge-aware response bubble separate
from the tiny buddy status badge. Stream or chunk the answer in rhythm with local
speech, constrain it to a reasonable width/height, and keep the optional transcript
window as an explicit secondary action.

**Acceptance criteria:**

- A 55-word answer is readable in full over time and is never silently clipped to
  two lines.
- The bubble flips left/right and above/below to remain inside every display's
  visible frame, including near the menu bar, Dock, and screen corners.
- Status text does not overwrite response text; a new question cleanly dismisses
  or replaces the old answer.
- Finished text remains available long enough to reread, then dismisses without
  leaving a stale floating panel. Reduce Motion disables travel/scale effects but
  preserves state clarity.
- VoiceOver receives state changes and the answer once, without announcing every
  streaming token.

### P0 — show exactly what screen context will be used

**Change:** At invocation, briefly identify the captured app/window in the ambient
surface (for example, “Listening · Safari — Billing”) and show a separate compact
capture/read state. Do not reveal full window text.

**Acceptance criteria:**

- The label names the actual captured target in an installed multi-window test.
- Switching apps after invocation does not silently change the target.
- Permission denial names Screen Recording as the failed stage and offers one
  direct Settings recovery action.
- No screenshot, OCR content, question, or answer appears in logs or persists
  after quit.

### P1 — make conversation continuity visible and controllable

**Change:** Distinguish “ready for follow-up” from generic ready, and provide
small, discoverable controls for New Conversation and Replay/Show Last Answer
without requiring the transcript window.

**Acceptance criteria:**

- After an answer, the ambient surface says that another hotkey continues the
  same conversation.
- A spoken pronoun-based follow-up uses the prior turn and fresh screen context.
- New Conversation visibly clears only in-memory guide turns, not dictation
  recovery.
- Quit/relaunch starts with no prior guide conversation.

### P1 — recover gracefully from audio and long-running stages

**Change:** Make cancellation work during capture/thinking/speaking as well as
listening; expose elapsed-time-aware status and actionable recovery for mic loss,
no speech, local-model failure, and muted output.

**Acceptance criteria:**

- Escape cancels every active phase within one second and stops speech.
- Mic/device loss preserves any finalized in-memory words for an explicit Retry or
  Copy action during the current session, without default persistent history.
- Muted/failed speech keeps the complete answer visible and offers a user-initiated
  Copy action; it does not write the answer to the clipboard silently.
- Each error identifies stage, cause, and one recovery action, and the next turn
  works without relaunch when recovery is possible.

### P1 — add safe pointing before rich drawing

**Change:** Use SERPy's existing validated `PointCue` seam to animate the companion
to one high-confidence target and present one concise label. This is guidance,
not clicking.

**Acceptance criteria:**

- A cue is shown only when its coordinate reconciles with the captured window and
  an Accessibility/OCR region; low confidence remains prose-only.
- The companion travels without moving the real pointer or stealing focus; any
  user pointer movement immediately cancels travel.
- The target cue is click-through, edge-safe, multi-display-safe, and cleared when
  speech ends or a new turn begins.
- Manual-action completion is never inferred merely because the overlay was shown.

### P2 — progressive, ephemeral walkthrough drawings

**Change:** After single-point guidance is proven, add a small owned vocabulary of
arrows, outlines, paths, and labels rendered progressively with speech. Use SERPy's
own visual language; do not copy HeyClicky shapes, colors, text, motion, or assets.

**Acceptance criteria:**

- Each primitive is bounds-validated against the request's captured window.
- Shapes appear in the same semantic order as spoken steps and clear at speech end,
  cancellation, app/window change, or after a documented timeout.
- Overlays never intercept clicks or cover the menu-bar control region.
- Reduce Motion uses fades/static placement; increased contrast and VoiceOver have
  equivalent nonvisual descriptions.
- A real click on the instructed AX element—not elapsed time—may advance a
  walkthrough; unsupported apps are reported as unsupported.

### P2 — teach the interaction through doing

**Change:** Replace explanatory settings copy as the main onboarding mechanism with
a two-minute local tutorial: invoke by voice, observe live transcript, receive one
pointing cue, ask a follow-up, cancel once, and recover from one simulated
permission/error state.

**Acceptance criteria:**

- Every tutorial step requires the real user action and confirms the real state;
  a preview button cannot satisfy completion.
- Permission requests occur just in time and explain why before macOS prompts.
- The tutorial is replayable from Settings, skippable, and does not block normal
  operation after completion.
- VoiceOver and keyboard-only users can complete an equivalent path.

## What not to copy

- No HeyClicky name, mascot, notch artwork, colors, labels, audio, assets, or
  personality text.
- No always-listening microphone, cloud service, account memory, integrations,
  or agent/computer-control behavior; these are outside `PRODUCT.md`.
- No assumption that a hardware notch exists. SERPy needs a native, accessible
  fallback surface on every supported Mac/display.
- No older Clicky implementation code. The public repository is behavioral and
  architectural evidence only unless the separate provenance gate is completed.

## Unresolved questions and evidence gaps

1. The exact current push-to-talk release gesture is ambiguous across marketing,
   older source, and changelog entries: hold Control+Option, press/release, and
   user-configured double-tap are all represented.
2. Public videos do not clearly show the complete idle → listening → thinking →
   speaking animation at native resolution, nor exact durations/easing.
3. It is unclear whether current HeyClicky shows the complete live transcript in
   the notch, only the latest fragment, or an edited/demo-only rendering.
4. The exact current response-text placement is unclear; spoken output and drawings
   are well evidenced, but a readable Talk answer bubble is not consistently visible
   in the first-party clips.
5. No first-party evidence establishes VoiceOver order, focus behavior, contrast,
   Reduce Motion, keyboard-only controls, non-notch Macs, or display-scale behavior.
6. The clips do not establish interruption rules: speaking over the answer,
   cancelling during thinking, changing the frontmost window, sleeping the Mac, or
   disconnecting headphones.
7. `daddyshome.mp4` appears aspirational/cinematic and should not be treated as
   proof that every shown multi-display behavior ships.
8. The distinction among ephemeral highlighting, pointing, multi-step drawings,
   and action-detection needs a native-resolution observation of a current build.

## Recommended next observations

1. Ask the owner to record one consented, current HeyClicky Talk session at native
   resolution, scoped to a harmless test app: idle, first question, spoken answer,
   follow-up, Escape cancellation, and permission failure. Do not record unrelated
   windows or microphone audio unless explicitly requested.
2. Repeat with the pointer at all four screen corners, on a second display, and in
   a full-screen app to measure bubble geometry and focus behavior.
3. Run a VoiceOver/Reduce Motion pass and record labels/order separately; absence
   of public evidence must not be treated as reference behavior.
4. Capture a drawing walkthrough that includes one real manual click, then verify
   whether advancement is tied to the target AX element rather than a timer.
5. Convert those observations into explicit acceptance rows before implementation;
   keep any unobserved row red rather than claiming parity.
