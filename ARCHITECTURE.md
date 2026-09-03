# Recommended Architecture

## Short Answer

- Build one native Swift/macOS application, not a platform or agent framework.
- Keep dictation and guidance as independent vertical features.
- Put macOS APIs and model vendors behind small protocols.
- Use explicit state machines for permissions, dictation, and companion
  visibility so UI and runtime state cannot silently diverge.
- Start with three local Swift targets plus the thin app target. Split further
  only when a boundary proves useful.

## System Picture

```mermaid
flowchart LR
    H["Global shortcut"] --> D["Dictation session"]
    M["Microphone"] --> D
    D --> STT["Local transcription adapter"]
    STT --> I["Focused-field insertion"]

    G["Guide shortcut or menu"] --> T["Transient guide conversation"]
    T --> C["Request-scoped context capture"]
    C --> X["Accessibility tree and OCR"]
    X --> A["Local guidance engine"]
    A --> P["Validated guidance plan"]
    P --> O["Cursor and caption overlay"]

    PM["Permission coordinator"] --> M
    PM --> I
    PM --> C
    S["App state and preferences"] --> D
    S --> O
```

The dictation path does not import or call the guidance engine.

## Repository Shape

```text
GuideCompanion/
├── App/                       # lifecycle and dependency composition only
├── Packages/GuideCore/        # domain types, protocols, state machines
│   ├── Sources/GuideCore/
│   └── Tests/GuideCoreTests/
├── Packages/GuideMac/         # macOS and model-provider adapters
│   ├── Sources/GuideMac/
│   └── Tests/GuideMacTests/
├── Packages/GuideUI/          # onboarding, settings, overlay, status UI
│   ├── Sources/GuideUI/
│   └── Tests/GuideUITests/
├── GuideCompanionUITests/     # signed-app and accessibility journeys
├── scripts/                   # build, package, verify; no credentials
├── docs/                      # decisions, threats, provenance
└── evidence/                  # exact-artifact verification reports
```

This is intentionally three local packages, not dozens of micro-modules.

## Module Ownership

| Module | Owns | Must not own |
| --- | --- | --- |
| GuideCore | Sessions, events, preferences schema, protocols, failure types | AppKit, SwiftUI, provider SDKs |
| GuideMac | Audio, hotkeys, Accessibility, screen capture, Vision/OCR, local model adapters, persistence | Product policy or views |
| GuideUI | Menu, onboarding, settings, overlays, status and recovery actions | Direct model/vendor calls |
| App | Construction, lifecycle, activation policy, dependency wiring | Feature algorithms |

Dependencies point inward: `App -> GuideUI/GuideMac -> GuideCore`. GuideCore
imports neither GuideMac nor GuideUI.

## Core State Machines

### Permission flow

```text
unknown -> explained -> userRequested -> granted
                    \-> denied -> recoveryAvailable
                               \-> unavailable
```

Invariants:

- No permission prompt without a preceding user action and explanation.
- Declining does not cause repeated prompts.
- Restart-required grants preserve and resume the current onboarding step.
- Microphone and Accessibility are sufficient for dictation; Screen Recording
  is not a startup requirement.

### Dictation session

```text
idle -> preparing -> recording -> transcribing -> inserting -> succeeded -> idle
                    |              |              |
                    +-----------> cancelled <-----+
                    +-----------> failed(stage, recovery)
```

The session snapshots the focused application and editable target when
recording starts, then validates the target again before insertion.

### Companion visibility

```text
disabled
enabledBlocked(reason)
enabledVisible
enabledTemporarilyHidden(reason, returnPolicy)
```

Invariant: when the persisted preference is enabled and no documented blocker
exists, every temporary hide path must return to `enabledVisible`.

### Guidance conversation and request

```text
conversation idle -> userTurn -> capturing -> understanding -> planning
                  -> guideTurn -> readyForFollowUp
                  -> failed(stage, recovery) -> readyForFollowUp
                  -> reset -> conversation idle
```

The recent conversation is held in memory and supplied with each new request.
It is not written to transcript history or logs. Each turn captures fresh
context; prior screen pixels are neither retained nor replayed.

The engine returns a structured `GuidancePlan`, not arbitrary overlay commands:

```text
GuidancePlan
  answer: String
  cues: [PointCue]
  confidence: Float
  sourceWindow: WindowIdentity
  expiresAt: Date
```

Coordinates are accepted only when they fall inside the captured window and can
be reconciled with an accessibility element, OCR region, or explicit confidence
threshold. Low-confidence responses provide prose without pointing.

## Important Protocol Seams

- `AudioCapturing`
- `SpeechTranscribing`
- `FocusedTextTargetReading`
- `TextInserting`
- `GlobalShortcutMonitoring`
- `PermissionChecking`
- `ScreenContextCapturing`
- `ScreenContextExtracting`
- `GuidanceGenerating`
- `OverlayPresenting`
- `ModelInstalling`

Each external dependency implements one of these seams. Product state refers to
capabilities and failures, never vendor names.

## Local Speech Strategy

Do not choose a permanent speech runtime from README claims. Phase 0 compares:

1. Apple on-device Speech as the zero-download fallback where genuinely local.
2. WhisperKit as an MIT-licensed, Swift-native Apple Silicon candidate.
3. FluidAudio/Parakeet, using OpenClicky's integration only as reference unless
   a narrowly reusable unit passes provenance and coupling review.

Measure cold start, first partial result, final-result latency, memory, model
size, English accuracy, punctuation, cancellation, offline behavior, and
failure recovery. Select through ADR 0002 after the probe.

## Text Insertion Strategy

Use a capability chain rather than one brittle technique:

1. Persist the completed transcript atomically before attempting delivery.
2. Use normal session-stream paste as the broad compatibility path.
3. Use Accessibility insertion or selected-value replacement only for targets
   whose resulting value can be observed and verified.
4. Preserve every clipboard item and representation; restore only while the
   pasteboard change count proves the app still owns its temporary contents.
5. Report a clear unsupported-target error when neither path is safe.

Posting paste events is not proof that insertion succeeded. Mark delivery
confirmed only when the destination can be read back; otherwise retain an
unconfirmed recovery item with Copy, Retry, and Delete. Never press Return,
submit forms, overwrite a newer clipboard change, or silently discard a
transcript.

## Screen Guidance Strategy

- Capture only after explicit activation.
- Open a normal, non-floating conversation window before capture; submitting a
  question is the capture action.
- Include recent in-memory turns so follow-up questions retain meaning.
- Prefer accessibility structure and Vision OCR over sending raw pixels into
  the reasoning layer.
- Use the system content-sharing picker where it improves user control.
- Treat Apple Foundation Models as one adapter, not a minimum-OS assumption.
- On systems without a capable local guidance model, dictation still works and
  guidance reports its exact limitation.
- No server provider is part of the first-product critical path.

## Storage and Privacy

- UserDefaults: small preferences and completed onboarding steps.
- Application Support: downloaded model manifests, checksums, redacted logs,
  and the bounded local transcript recovery store.
- Keychain: reserved for future secrets; core product requires none.
- By default, persist only the newest Last Dictation: 10 minutes after
  confirmed delivery or 24 hours after unconfirmed/failed delivery. Persist it
  atomically before delivery so a crash cannot erase the user's words.
- Full transcript history is opt-in, bounded to 25 entries and 30 days.
- Audio history is a separate opt-in and is never enabled implicitly.
- Transcript and audio files use owner-only permissions and are excluded from
  backups. Screenshots are never stored.
- No account, telemetry SDK, analytics identifier, or localhost control bridge.
- Logs contain session IDs, durations, stages, and error categories—not content.

## Release Shape

- Direct-download native macOS app.
- Stable downstream bundle ID and Developer ID identity from the first signed
  interactive build to avoid TCC churn.
- Hardened Runtime, notarized and stapled DMG.
- The proven packaging/evidence workflow may be adapted, but upstream product
  identity, appcast, keys, assets, and destinations must not be copied.
- Mac App Store sandboxing and automatic updates are separate later decisions.

## Rejected Initial Shapes

| Shape | Decision | Reason |
| --- | --- | --- |
| Fork OpenClicky wholesale | Reject | Broad coupled scope and inherited failure states |
| Reverse engineer HeyClicky implementation | Reject | Hidden internals and unnecessary clean-room risk |
| Local HTTP agent bridge | Defer | Adds attack surface without helping core journeys |
| One giant observable manager | Reject | Recreates the coupling already observed |
| Cloud-first assistant | Reject | Violates the no-key, offline core contract |
| Many tiny packages | Reject | More build and ownership overhead than this app needs |
