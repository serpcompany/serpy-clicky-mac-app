# ADR 0004: Local guidance capability floor

- Status: provisionally accepted for the installed internal baseline
- Date: 2026-08-16

## Decision

On macOS 26, explicitly invoked guidance captures one frontmost non-product
window with ScreenCaptureKit, extracts visible text with Vision, and sends only
that transient text context to Apple Foundation Models on device. The initial
plan returns prose only; no coordinate cue is shown below the confidence gate.

## Safety properties

- Screen access is not requested at startup or for dictation.
- Capture happens only after `Guide Current Screen` or Control-Option-G.
- Screenshots are held in memory and are not written to disk.
- The guidance layer has no click, keyboard, shell, browser, or automation
  capability.
- If Apple Intelligence is unavailable, dictation remains operational and the
  UI reports the limitation.
