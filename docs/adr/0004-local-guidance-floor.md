# ADR 0004: Local guidance capability floor

- Status: provisionally accepted for the installed internal baseline
- Date: 2026-08-16

## Decision

On macOS 26, explicitly invoked guidance opens a transient, back-and-forth
conversation. Each submitted question captures one remembered frontmost
non-product window with ScreenCaptureKit, extracts visible text with Vision,
and sends that transient text context plus recent in-memory turns to Apple
Foundation Models on device. The initial plan returns prose only; no coordinate
cue is shown below the confidence gate.

## Safety properties

- Screen access is not requested at startup or for dictation.
- Opening the AI Guide does not capture. Capture happens only after the user
  submits a message; Control-Option-G opens the conversation window.
- Screenshots are held in memory and are not written to disk.
- Conversation turns remain in memory only and are not written to history or
  logs.
- The guidance layer has no click, keyboard, shell, browser, or automation
  capability.
- If Apple Intelligence is unavailable, dictation remains operational and the
  UI reports the limitation.
