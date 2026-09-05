# Build 46 internal test candidate

2026-09-05, M3. **Not V1-ready; acceptance remains red.**

## Exact artifact

- Source: `293c5ff` (clean source at build).
- Version/build: `0.1.0 (46)`.
- DMG: `SERPy-0.1.0-46.dmg`.
- DMG SHA-256: `3ffdb805c9da71e4c068ddd235f5fc0a97bbf45b16c62402340e492b770133f5`.
- Installed executable SHA-256: `a644565eae75761a2a7f7d765d89a86811b798902e845e92c0c27850cff14a15`.
- Developer ID signed, notarized, stapled; `verify-release.sh` accepted the DMG
  and mounted app. Gatekeeper accepted the installed `/Applications/SERPy.app`.
- Replaced build 44 recoverably at `/private/tmp/SERPy-build44-before46.app`.

## Observed and tested

- Launched the exact installed app with computer use. Setup showed Microphone,
  Speech Recognition, Accessibility, and Screen Recording Granted, local Speech
  Ready, and shortcut Registered. Guidance showed On-device selected and the
  existing held Control–Option shortcut. This does not prove microphone audio,
  insertion, speech output, or held-key event delivery.
- Internal diagnostics explicitly disabled at build; bundled DSN is empty.
  The rejected build 45 telemetry configuration is not carried forward.
- Local generated output now uses Apple's typed schema; local points resolve
  only from captured evidence IDs. The full core lane passed after the pointing
  regression failed before the fix. See `evidence/local-guide-pointing.md`.
- The reporting-off release command initially failed on macOS Bash's empty
  array expansion under `set -u`. Corrected expansion was checked with zero
  arguments and two arguments (including a space), then the real release build
  passed. No signing identity or permission domain changed.

## Remaining failures

An agent-run on-device model probe used only synthetic Preferences labels and
the actual typed schema, not microphone or screen content. It selected valid
pointing IDs but inserted an unnecessary General action before Appearance and
used evidence IDs instead of literal UI text as completion labels. This is a
model quality failure, not a passing walkthrough. The probe's system instruction
requested two steps; this also highlights that answer-only and walkthrough
contracts need to be distinguished rather than forcing extra actions.

Chrome menu-bar evidence, completion semantics, the reference black edge
surface, full Dictation acceptance, real Guide voice/click-through acceptance,
and the stored-event telemetry privacy check are still unresolved. No live
OpenAI call, public binary upload, or V1 completion claim was made.
