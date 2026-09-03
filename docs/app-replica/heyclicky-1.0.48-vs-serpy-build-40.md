# HeyClicky 1.0.48 versus SERPy build 40 checkpoint

Date: 2026-09-04

Claim: **Rebuilt invocation and ambient shell; owner Guide journey unresolved.**
This is not parity verification and not owner acceptance.

## Exact artifacts

| Fact | HeyClicky reference | SERPy candidate |
| --- | --- | --- |
| Installed path | `/Applications/HeyClicky.app` | `/Applications/SERPy.app` |
| Version/build | `1.0.48 (57)` | `0.1.0 (40)` |
| Executable SHA-256 | `c1a0863d44da3dda37bac5651809ff9ace3450518eab629f0544da1cb2035b01` | `97c5dd01c1b2a14598dccfa47a35f2f882df5ba78cb2e93ea441e5acdda25445` |
| Candidate commit | — | `e605a1a09f901a13e3c740118d2cd77870c4e225` |
| DMG | — | `dist/SERPy-0.1.0-40.dmg` |
| DMG SHA-256 | — | `faadec51b7246c06039f82b139392ed8018c88fa9e440a1ef9065ddf29089af1` |
| Notarization | accepted | accepted submission `9a21d77d-0026-4531-86b0-4ea09eaceecf`; DMG stapled |
| Gatekeeper | accepted | accepted, Notarized Developer ID |

The installed executable and retained Release executable hashes match exactly.
Strict nested code-sign verification passes. Stale LaunchServices registrations
were removed; the rejected installed build and generated debug/staging bundles
were moved to Trash and remain recoverable.

## Mechanical verification

- Swift package: 86 XCTest + 27 Swift Testing tests passed (113 total).
- Xcode UI: 2/2 passed (menu-bar launch and no-composer transcript window).
- Release: clean arm64 Developer ID build passed.
- DMG: signature, checksum, notarization, staple, mounted-app strict signature,
  Gatekeeper open, and Gatekeeper execute checks passed.
- Completion validator remains red by design.

## Installed observations

- Build 40 launches as the registered `/Applications/SERPy.app` menu-bar app.
- Guidance Settings is a normal window and exposes a working provider selector,
  persisted held-chord selector, truthful screen permission, and manual
  start/finish/cancel controls.
- Manual Start changed the installed state to listening; Escape returned it to
  ready without relaunch.
- Candidate screenshots:
  - `evidence/heyclicky-1.0.48-vs-serpy-build-40/candidate/guidance-settings.jpeg`
  - `evidence/heyclicky-1.0.48-vs-serpy-build-40/candidate/listening.jpeg`
  - `evidence/heyclicky-1.0.48-vs-serpy-build-40/candidate/ready.jpeg`
- The Computer Use driver refuses modifier-only keypresses, so it could not
  exercise the actual held Control–Option chord. The chord, focus retention,
  physical microphone transcript, answer, audible speech, follow-up, later
  cancellation phases, and spatial cue remain owner HIL.
- No live OpenAI/model request was made. OpenAI remained unselected.
- The Application Support audit found only the existing bounded dictation
  history file. No image/audio file and no controlled Guide phrase appeared in
  Application Support or preferences. Existing dictation content was not read
  or committed.

## Differential result

Build 40 fixes the pre-listening architecture failure in source: one injected
shortcut monitor, held/release Guide semantics, macOS tap re-enable, ordered
callback delivery, configurable persisted chord, conflict prevention, and no
Guide trigger key to leak into the work app. It also replaces the rejected
two-panel cursor-following Guide response with one target-display ambient
surface and exposes transcript/answer text to VoiceOver.

Those facts do not prove the owner-visible journey. The detailed ledger remains
`docs/app-replica/heyclicky-1.0.48-guide-parity-ledger.md`; passive reference
shape, answer quality, speech, follow-up, progressive drawing, audio recovery,
multi-display/Spaces/full-screen, and owner acceptance remain red.
