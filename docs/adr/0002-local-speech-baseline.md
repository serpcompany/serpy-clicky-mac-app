# ADR 0002: Local speech baseline

- Status: provisionally accepted for the installed internal baseline
- Date: 2026-08-16

## Decision

Use Apple Speech with `requiresOnDeviceRecognition = true` for the first
installed product. Keep transcription behind the GuideMac adapter so a later
WhisperKit or FluidAudio probe can replace it without changing UI or insertion.

## Why

- No API key, account, cloud provider, or bundled third-party model is needed.
- The signed app reports whether on-device recognition is supported before it
  arms dictation.
- It minimizes download and provenance risk for the first human journey.

## Limit

This decision is not an accuracy claim. It becomes final only after offline
microphone-to-TextEdit HIL on the exact installed build. If that fails,
WhisperKit is the next candidate; a remote fallback is not permitted.
