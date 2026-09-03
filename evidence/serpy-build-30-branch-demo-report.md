# SERPy build 30 branch demo report

Date: 2026-09-04

Branch: `feat/6-heyclicky-talk-parity`

Allowed claim after owner HIL only: **Reconstructed: bounded ambient Talk
journey.** This report does not claim full HeyClicky parity.

## Implemented slice

- One public `GuideTurnCoordinator` owns the whole active turn task while the
  separate in-memory conversation survives between turns.
- Capture, local transcription, local generation, local speech, and overlay
  presentation are injected only at system boundaries.
- Invocation locks immutable PID, exact window ID, app name, window title, and
  frame before SERPy presents or requests Screen Recording permission.
- ScreenCaptureKit resolves only that PID/window-ID pair and fails if it
  disappears; it never falls back to another window in the same process.
- Vision OCR runs on a dedicated non-main queue.
- Listening presentation occurs before capture work starts.
- Escape cancellation stops owned capture/generation work, microphone, speech,
  and response presentation during listening, capture, thinking, or speaking.
- ChatGPT and unique-phrase OCR fixtures cover prompt construction and false
  visibility contradiction recovery without using Foundation Models output as
  a deterministic oracle.
- The model is instructed to answer within 55 words. Complete unexpected longer
  answers still reach conversation, ambient presentation, and TTS unchanged;
  the bubble remains stationary and edge-safe while readable.
- No upstream source or asset was imported. No cloud provider, account, agent,
  new permission, or persistence path was added.

## TDD record

Each cycle tested a public seam and faked only system/provider boundaries.

1. Coordinator/order/conversation RED: focused test failed because
   `GuideTurnCoordinator` and its boundary protocols did not exist. GREEN:
   `swift test --package-path Packages/GuideModules --filter GuideTurnCoordinatorTests/testAmbientTurnLocksTargetBeforeListeningAndAnswersWithFreshContext`
   passed.
2. Exact-window target RED: focused policy suite failed because
   `ExactWindowTargetPolicy` did not exist. GREEN:
   `swift test --package-path Packages/GuideModules --filter ExactWindowTargetPolicyTests`
   passed both same-PID and disappearance cases.
3. Capture/OCR RED: public raster, catalog/capture, and recognizer seams did not
   exist. GREEN: the production ScreenCaptureKit provider now forms exact-ID
   capture requests through the tested resolver, service contracts cover exact
   descriptor/no-sibling behavior, and real Vision OCR reads a deterministic
   generated `ORCHID RIVER 731` image.
4. Listening cancellation RED: expected `cancelled → ready`, observed
   `listening → cancelled`. GREEN: focused cancellation test passed after a
   bounded 1.2-second cancelled presentation followed by preference restoration.
5. Capture cancellation RED: expected coordinator phase `capturing`, observed
   `transcribing`. GREEN: focused test passed after presenting capture as the
   truthful owned phase.
6. Thinking and speaking cancellation tests passed against the same minimal
   cancellation implementation and directly guard both later phases.
7. Grounding fixtures RED: focused tests failed because
   `GuidancePromptBuilder` did not exist. GREEN: ChatGPT plus `ORCHID RIVER 731`
   fixtures and contradiction recovery passed.
8. Answer/anchor RED: focused tests failed because the answer budget and
   stationary anchor policies did not exist. GREEN: both passed and were wired
   into coordinator/UI presentation.

## Mechanical verification

- `swift test --package-path Packages/GuideModules`: PASS, 50 XCTest and 26
  Swift Testing tests.
- `xcodegen generate`: PASS.
- `./scripts/build-release.sh`: PASS.
- `codesign --verify --deep --strict --verbose=4`: PASS.
- Version: `0.1.0 (30)`.
- Artifact:
  `$REPO_ROOT/.release-derived/Build/Products/Release/SERPy.app`
- Executable SHA-256:
  `09c79bd895c4ebeb2c92297d86f2b01e623184ab8b602f510c75a3142a3cabf8`
- Signing identity: Developer ID Application, team `847HR8U8D9`, secure
  timestamp present.
- Effective entitlement: audio input only; `get-task-allow` absent.
- Artifact architecture: arm64.
- `jq empty docs/app-replica/completion-manifest.json`: PASS.
- `git diff --check`: PASS.
- Source audit found no new guide persistence or network/provider code.

Independent read-only standards/spec reviews identified early cancellation
ownership release, lost stage-specific recovery, unbounded error visibility,
immediate cancellation overwrite, destructive answer truncation, a missing
model-provider seam, duplicate exact-window matching, and absolute user paths.
All were corrected and regression-tested before the final build. Production
ScreenCaptureKit selection now routes through the tested exact-window policy;
OS-owned capture behavior and installed identity proof remain red because an
`SCWindow` cannot be truthfully synthesized as proof of the system adapter.
Foundation Models availability now distinguishes pre-macOS-26 incompatibility
from an unavailable Apple Intelligence model through a deterministic policy.

## Deliberately unresolved

This task did not install or launch the artifact. Exact-artifact microphone,
screen capture, Foundation Models answer quality, audible speech, focus
retention, response readability, follow-up continuity, preference restoration,
and phase-by-phase cancellation remain red for owner HIL. Follow
`docs/hil/serpy-build-30-talk-demo.md`.

Pointing/drawing, whole-document and arbitrary visual understanding,
multi-display/negative-origin/Spaces/full-screen behavior, VoiceOver, Reduce
Motion, and the complete error matrix also remain red.
