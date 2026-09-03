# ADR 0004: Local guidance capability floor

- Status: provisionally accepted for the installed internal baseline
- Date: 2026-08-16

## Decision

On macOS 26, explicitly invoked guidance starts a transient, voice-first
conversation without opening a typing window. The first hotkey press captures
one remembered frontmost non-product window with ScreenCaptureKit and starts
local speech recognition; the second press submits the spoken question. Vision
extracts visible text and sends that transient text context plus recent
in-memory turns to Apple Foundation Models on device. The answer appears beside
the cursor and is spoken with the local system voice. The initial plan returns
prose only; no coordinate cue is shown below the confidence gate.

## Safety properties

- Screen access is not requested at startup or for dictation.
- Control-Option-G starts listening and captures request-scoped context; a
  second press finishes the question and Escape cancels.
- Screenshots are held in memory and are not written to disk.
- Conversation turns remain in memory only and are not written to history or
  logs.
- The normal-level transcript window is secondary inspection UI and contains
  no typing composer.
- The guidance layer has no click, keyboard, shell, browser, or automation
  capability.
- If Apple Intelligence is unavailable, dictation remains operational and the
  UI reports the limitation.
