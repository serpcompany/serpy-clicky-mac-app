# Delivery Plan

Every phase produces an independently reviewable artifact. Later phases cannot
turn an earlier red acceptance row green by assertion.

## Phase 0 — Risk Probes and Decisions

Goal: prove the uncertain macOS seams before building product UI.

Disposable probes:

1. Record microphone audio and compare local transcription candidates.
2. Insert fixed and multiline text into TextEdit, Notes, a browser, Slack, and a
   code editor while preserving clipboard and selection behavior.
3. Show a nonactivating cursor overlay across multiple displays without
   intercepting unrelated clicks or covering the menu bar.
4. Capture one explicitly chosen window, extract Accessibility/OCR context, and
   obtain a two-turn local guidance conversation on the owner's Mac.
5. Package a minimal signed probe using the intended stable bundle namespace to
   characterize TCC behavior.

Deliverables:

- Measured comparison report.
- ADR 0002 selecting the first speech engine.
- ADR 0003 selecting insertion and fallback policy.
- ADR 0004 recording the local guidance capability floor.
- Updated minimum macOS decision if evidence requires it.

Done when every probe has measured results and no probe code has leaked into
production modules by copy/paste.

## Phase 1 — Dictation-Only Vertical Slice

Goal: make one complete, offline, no-key dictation journey excellent.

Build:

- Thin menu-bar shell and normal Settings window.
- Microphone/Accessibility onboarding state machine.
- Model download/readiness experience.
- Configurable push-to-talk shortcut.
- Recording status overlay.
- Local transcription and focused-field insertion.
- Cancellation, undo-friendly behavior, clipboard restoration, and actionable
  failures.

Done when the exact signed app passes Acceptance A1–A9 offline on the internal
test Mac after a fresh preference and permission reset.

## Phase 2 — Reliable Cursor Companion

Goal: provide a pleasant, persistent visual companion independent of guidance.

Build:

- Companion visibility state machine.
- Cursor-safe positioning, multi-display geometry, Reduce Motion behavior.
- Compact captions and explicit hide/show control.
- Instrumented hide reasons and return policies.
- Non-floating Settings behavior.

Done when Acceptance B1–B8 pass and the cursor never blocks menu-bar access.

## Phase 3 — Local Screen Guidance

Goal: hold an explicit back-and-forth conversation about the current screen and
point safely.

Build:

- On-demand Screen Recording onboarding.
- Request-scoped content selection and capture.
- Accessibility and OCR context extraction.
- Selected local guidance adapter.
- Transient multi-turn conversation state with a normal non-floating window.
- Structured guidance-plan validation.
- Caption, speech, and cursor pointing without autonomous action.

Done when Acceptance C1–C9 pass with networking disabled on the supported test
machine, or the owner explicitly approves a revised local-capability boundary.

## Phase 4 — Installed Product Baseline

Goal: prove the three journeys in a normal downloadable build.

Build:

- Product-owned identity and assets.
- Developer ID signing, notarization, stapling, DMG, checksum, and manifest.
- Clean install/relaunch/uninstall instructions.
- Local diagnostics export with automatic content redaction.

Done when a quarantined HTTPS download is installed through Finder, passes
Gatekeeper without a bypass, completes all required journeys, and relaunches
without permission loops.

## Phase 5 — Optional Expansion Gate

Only after the installed baseline passes should the owner decide whether to add:

- Wake word.
- Optional cloud providers.
- Rewriting/formatting modes.
- Tutorial ingestion and richer screen understanding.
- Autonomous agents or computer use.
- Accounts, sync, billing, updates, or additional platforms.

Each is a separate product and risk decision, not an automatic continuation.
