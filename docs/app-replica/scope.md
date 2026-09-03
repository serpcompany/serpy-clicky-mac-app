# Voice-first guide reference scope

## Authorization and target

- Owner request: change SERPy's AI Guide from a typed chat window to the
  voice-first interaction demonstrated and described by Clicky/HeyClicky.
- Candidate: SERPy for macOS, bundle
  `com.serpcompany.guidecompanion.internal`.
- Intended use: private internal product development and testing.
- Acceptance slice: invoke the guide, speak a question, combine the transcript
  with request-scoped computer context, answer through the cursor companion,
  speak the answer locally, and allow a spoken follow-up.

## Behavioral references

- HeyClicky FAQ, observed 2026-09-04:
  `https://www.heyclicky.com/`
  - Press the hotkey and ask out loud.
  - Talk is the conversation.
  - Screen access occurs when the hotkey is pressed.
- Clicky open-source README, observed 2026-09-04:
  `https://github.com/farzaa/clicky`
  - Describes push-to-talk audio, transcription, screenshot context, model
    response, and text-to-speech as the primary pipeline.
  - Repository is MIT licensed, but no source is imported into SERPy by this
    work.

## Evidence labels for issue #6

- **Current HeyClicky observed:** hotkey-driven spoken Talk, no conventional
  Talk window, request-time screen access, spoken conversational answers,
  follow-up continuity, and drawing/walkthrough guidance.
- **Older MIT Clicky source-confirmed:** click-through non-key overlays,
  waveform/processing/response states, screenshot plus recent conversation,
  local presentation of a completed response, and transient Talk visibility.
- **SERPy product criteria:** 150 ms acknowledgement, exact PID/window-ID
  target lock, compact target label, 55-word budget, local-only processing,
  cancellation ownership, redacted logs, and no persistence. These are quality
  requirements, not evidence that HeyClicky uses the same implementation.
- **Inference/unresolved:** exact current transcript geometry, capture timing,
  error language, non-notch behavior, accessibility, Reduce Motion, and timing
  budgets. Promotional material cannot close these rows.

## Clean-room differences

This is a bounded behavioral slice, not a complete-reference clone. SERPy keeps
its own product identity and independent implementation. It uses Apple
on-device speech, Apple Foundation Models, and local system speech rather than
Clicky's documented AssemblyAI, Claude, ElevenLabs, and Cloudflare Worker
stack. Agent execution, cloud services, accounts, and Clicky assets remain
outside the authorized SERPy product boundary.

No HeyClicky binary, private protocol, asset, account, or product identity is
copied. The official public descriptions are behavioral evidence only.

The branch implementation may only be described as **Reconstructed: bounded
ambient Talk journey** after the exact installed build passes the owner HIL.
Pointing/drawing, whole-document and arbitrary visual understanding,
multi-display/negative-origin/Spaces/full-screen behavior, and the full failure
matrix remain explicitly outside that claim.
