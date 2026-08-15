# Implementation Issue Plan

Create these issues only after Phase 0 is authorized. Keep each issue small
enough to verify independently and link its acceptance rows.

## Epic 0 — Prove Risky Seams

### 0.1 Local transcription benchmark

- Compare Apple Speech, WhisperKit, and FluidAudio/Parakeet on the owner's Mac.
- Run identical prerecorded and live speech fixtures.
- Measure latency, memory, model size, accuracy, cancellation, and offline state.
- Output: ADR 0002 and an evidence table; no production integration.

Acceptance rows informed: A3, A4, A9.

### 0.2 Focused-field insertion matrix

- Prototype Accessibility insertion and clipboard-preserving paste.
- Exercise caret, selection replacement, multiline, undo, cancellation, and
  target-changing-during-recording behavior.
- Output: ADR 0003 and per-application results.

Acceptance rows informed: A5–A8.

### 0.3 Nonintrusive overlay lifecycle

- Prototype nonactivating cursor and status overlays.
- Test menu-bar collision, click-through, display edges, multiple displays,
  Spaces, full-screen apps, and Reduce Motion.
- Output: overlay rules and geometry fixtures.

Acceptance rows informed: B1–B8.

### 0.4 Local screen-guidance capability

- Capture an explicitly selected window.
- Extract Accessibility structure and Vision OCR.
- Compare available local language-model routes using a fixed scenario corpus.
- Validate whether useful guidance is possible without raw-image reasoning.
- Output: ADR 0004 and the supported guidance boundary.

Acceptance rows informed: C1–C9.

### 0.5 Stable identity and TCC probe

- Reserve an internal bundle namespace owned by the user.
- Sign one minimal probe consistently.
- Record Microphone, Accessibility, and Screen Recording behavior across rebuild
  and relaunch without resetting unrelated applications.
- Output: development signing/TCC runbook.

Acceptance rows informed: A1, A2, C1, D3.

## Epic 1 — Dictation Vertical Slice

### 1.1 Establish core state machines and failure taxonomy

- Implement permission and dictation state machines in GuideCore.
- Add exhaustive transition and failure-injection tests.
- No macOS or model dependencies.

### 1.2 Build permission coordinator and onboarding shell

- Explain permissions, request on intent, resume after relaunch, and present
  recovery actions.
- Microphone and Accessibility only.

Acceptance rows: A1, A2.

### 1.3 Build local model manager

- Versioned manifest, disk-space preflight, download progress, cancellation,
  checksum verification, atomic install, rollback, and removal.

Acceptance row: A3.

### 1.4 Build push-to-talk and recording overlay

- Configurable shortcut, press/release semantics, escape cancellation, input
  device status, recording duration, and clear state presentation.

Acceptance rows: A4, A7.

### 1.5 Connect selected local transcription adapter

- Stream audio, produce partial/final results, enforce offline/no-key behavior,
  and expose stage-specific failures.

Acceptance rows: A4, A9.

### 1.6 Build safe text insertion chain

- Validate focused target, insert or replace selection, preserve clipboard,
  make insertion undo-friendly, and never submit automatically.

Acceptance rows: A5–A8.

### 1.7 Dictation installed-artifact acceptance

- Package the stable signed build and run the complete compatibility matrix
  offline from a clean preference and permission state.

Acceptance rows: A1–A9.

## Epic 2 — Companion

### 2.1 Build companion visibility state machine

- Enumerate every hide reason, blocker, and return policy.
- Add lifecycle and persistence tests.

Acceptance rows: B1–B4.

### 2.2 Build cursor and caption overlay

- Implement deterministic geometry, multi-display support, hit-testing rules,
  edge flipping, animation policy, and accessibility semantics.

Acceptance rows: B5, B6, B8.

### 2.3 Build normal Settings and menu-bar surfaces

- Settings uses normal macOS stacking/Spaces behavior.
- Menu-bar UI requires an explicit click and never hover-expands over status
  items.

Acceptance rows: B5, B7.

### 2.4 Companion installed-artifact acceptance

- Run persistence, app-switch, idle, failure, crowded-menu, and multi-display
  journeys against the exact signed app.

Acceptance rows: B1–B8.

## Epic 3 — Local Screen Guidance

### 3.1 Add on-demand screen-permission journey

- Keep screen access out of first-launch dictation onboarding.
- Explain scope, use system selection where appropriate, and recover after
  permission changes/relaunch.

Acceptance rows: C1, C2.

### 3.2 Build transient context extraction

- Capture one request, exclude overlays, generate AX/OCR structure, then release
  source buffers without persistence.

Acceptance rows: C3, C4.

### 3.3 Connect selected local guidance adapter

- Transform structured context and the question into a typed GuidancePlan.
- Keep model availability/failure isolated from dictation.

Acceptance rows: C5, C9.

### 3.4 Validate and present guidance cues

- Bounds-check, reconcile with source regions, confidence-gate, expire, and
  present captions/cursor cues without input events.

Acceptance rows: C6–C8.

### 3.5 Guidance installed-artifact acceptance

- Run the fixed scenario corpus and HIL journeys with networking disabled.

Acceptance rows: C1–C9.

## Epic 4 — Internal Product Baseline

### 4.1 Original identity and asset audit

- Replace codename placeholders with owner-approved original identity.
- Verify bundle IDs, paths, defaults, logs, manifests, and assets.

Acceptance row: D6.

### 4.2 Release pipeline

- Archive, Developer ID sign, notarize, staple, package DMG, checksum, and emit
  a redacted build manifest.

Acceptance rows: D1, D2.

### 4.3 Privacy and diagnostics audit

- Prove transient content handling and redacted diagnostics using seeded private
  fixtures.

Acceptance rows: D4, D5.

### 4.4 Fresh downloaded-install HIL

- Download over approved HTTPS, install through Finder, complete A/B/C journeys,
  quit/relaunch, and document uninstall.

Acceptance rows: D1–D6 and final product gate.
