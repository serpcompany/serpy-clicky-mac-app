# Dictation donor import map

- Date: 2026-09-04
- Scope: Issue #12 Gate A; Version 1 Dictation stabilization only
- Behavior oracle: installed Superwhisper 2.18.3 and its public product documentation
- Primary donor: [`Starmel/OpenSuperWhisper@bef6bc0421d0c010e8f2fb4288c0d74978c8b964`](https://github.com/Starmel/OpenSuperWhisper/tree/bef6bc0421d0c010e8f2fb4288c0d74978c8b964)
- Secondary donor: [`human37/open-wispr@7ab4e62e8f182f3ecc2116e1094a1eb4416a248f`](https://github.com/human37/open-wispr/tree/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f)
- Status: source map with controlling long-session addendum; no implementation
  or test authorization is implied

## Controlling long-session addendum

This section supersedes the initial coordinator/engine recommendation below.
The owner's later report added a decisive Version 1 failure: long Dictation
sessions sometimes lose or fail to save speech. Apple documents a one-minute
audio limit for the `SFSpeechRecognizer` API used by current serpy. Current
serpy creates one recognition task for the entire session, retains only the
latest formatted result, and has no task rollover or durable temporary audio
when audio history is disabled.

The primary Dictation donor is now
[`FrigadeHQ/yap@5f06bb1aa889abaa064b09a9bf33aff984dc1583`](https://github.com/FrigadeHQ/yap/tree/5f06bb1aa889abaa064b09a9bf33aff984dc1583),
an MIT native Swift macOS 26 app using `SpeechAnalyzer` and
`SpeechTranscriber`.

Adopt or adapt these pinned donor units before writing original replacements:

- `RecordingCoordinator` and `RecordingCoordinatorTests` as the public,
  donor-derived orchestration seam;
- `DictationSession` for capture-before-model-preparation ordering;
- `AudioBufferRelay` for bounded retention of audio captured before the
  transcriber is ready;
- `TranscriptionService` for `SpeechAnalyzer`, permanent accumulation of final
  segments, volatile partial display, and local model preparation; and
- `AudioCaptureService` for fresh-engine reconstruction after microphone/device
  changes.

This makes a dedicated coordinator appropriate because it is copied/adapted
from a tested working donor rather than invented from serpy in isolation.
`GuideAppModel` becomes presentation/integration glue around that donor-derived
Dictation boundary.

Yap is not sufficient unchanged. The serpy adaptation must retain or add:

1. Superwhisper's public durability contract: recoverable active audio saved at
   least every 10 seconds, plus a bounded stop tail;
2. explicit checkpoint/write failures instead of silent buffer loss;
3. raw temporary audio as the recovery source until the final transcript is
   durably preserved or the user cancels;
4. serpy's original focused-target capture and revalidation;
5. serpy's multi-item pasteboard preservation and truthful
   confirmed/unconfirmed/failed delivery model;
6. preserve-before-delivery ordering;
7. cancellation and late-result suppression through recording, transcribing,
   processing, and insertion; and
8. independence from Guide, Sentry, OpenAI, and Keychain.

The red feedback loop uses a multi-minute synthetic audio fixture with sentinel
phrases before, around, and after the one-minute boundary. Every sentinel must
appear exactly once and in order after forced task/error and recovery paths.

Sources:
[Apple `SFSpeechRecognizer`](https://developer.apple.com/documentation/speech/sfspeechrecognizer),
[Apple `SpeechAnalyzer`](https://developer.apple.com/documentation/speech/speechanalyzer),
[Superwhisper changelog](https://superwhisper.com/changelog), and
[Superwhisper troubleshooting](https://superwhisper.com/docs/common-issues/troubleshooting).

## Initial decision — superseded where the addendum conflicts

Do **not** import either donor as an application framework and do not introduce a
new `DictationSessionCoordinator` before a failing behavior test requires one.
Neither donor supplies the complete required workflow. OpenSuperWhisper has the
stronger serialized recording and final-word-tail implementation; open-wispr has
the clearest pure hold/toggle lifecycle and deterministic pasteboard adapter
tests. Serpy already has the stronger original-destination capture, bounded Last
Dictation store, and truthful delivery-state model.

Gate B should therefore preserve the current production path and make the
smallest donor-derived corrections behind existing public behavior:

1. keep `GlobalShortcutEventRouter`, `DictationActivationPolicy`, and
   `DictationStateMachine` as the shortcut/lifecycle seams;
2. make the existing speech, permission, insertion, and recovery dependencies
   injectable through small `GuideCore` protocols already named by
   `ARCHITECTURE.md`;
3. test the complete flow through the existing public `GuideAppModel` Dictation
   interface (`toggleDictationFromMenu`, shortcut callbacks, `cancelDictation`,
   `stop`, and observable phase/delivery/recovery state);
4. add a separate coordinator only if a red test proves that task ownership
   cannot be made correct locally without one.

This is less architecture than the earlier proposal: the model remains the
current orchestration module, while its platform adapters become replaceable for
headless behavior tests.

## Classification rules

- **Adopt**: the donor behavior and test contract can be carried over without
  changing the Version 1 product contract.
- **Adapt**: retain the donor algorithm or invariant, but fit it to serpy's
  current local engine, stable identity, target capture, recovery, privacy, and
  module direction.
- **Reject**: the donor behavior is weaker, changes scope, adds a dependency, or
  cannot meet the acceptance contract.

All source defects below are hypotheses until a focused Gate B test reproduces
them red. Donor UI/integration tests that launch applications, switch input
sources, access TCC, or use live audio are reference evidence only and must not
run in the routine local lane.

## Summary

| # | Behavior | Primary decision | Secondary decision | Proposed public behavior seam |
| --- | --- | --- | --- | --- |
| 1 | Shortcut down/up/toggle/Escape | Adapt timing; reject singleton | Adopt pure lifecycle cases; reject NSEvent monitor | `GlobalShortcutEventRouter.route`, `DictationActivationPolicy` |
| 2 | Immediate recording acknowledgement | Adapt start-before-AX order | Adapt recording-before-other work | Public model phase/presentation state after activation |
| 3 | Microphone selection/readiness | Adapt readiness/request separation | Adapt stable device UID resolution only if current behavior needs it | `PermissionChecking`, `SpeechTranscribing` availability |
| 4 | Audio start/stop/cancel/final tail | Adapt serialized start/stop and tail | Reject recorder replacement | `SpeechTranscribing.start/stop/cancel` |
| 5 | Existing local transcription engine | Reject engine replacement | Reject engine replacement | `SpeechTranscribing` contract around `AppleSpeechTranscriber` |
| 6 | Transcription cancellation/late results | Adapt owned-task and generation guards | Reject incomplete synchronous pipeline | Public model `cancelDictation`/`stop` plus observable outcome |
| 7 | Focused destination capture | Reject; no retained delivery target | Reject; no retained delivery target | `FocusedTextTargetReading.captureFocusedTarget` |
| 8 | Insert without submission | Adapt layout-aware paste only | Adapt injected paste action/order tests | `TextInserting.insert` returning `TextInsertionMethod` |
| 9 | Clipboard preservation/newer copy | Adapt ownership rule; reject one-item snapshot | Adopt adapter-driven tests and multi-item extension | `TextInserting.insert` with injected pasteboard/clock |
| 10 | Preserve before delivery/Last Dictation | Reject full-history store | Reject audio-recording store | Existing `TranscriptHistoryStore` through a `LastDictationStoring` seam |
| 11 | Confirmed/unconfirmed/failed delivery | Reject; no receipt model | Reject; no receipt model | Model delivery state plus `TranscriptHistoryStore.updateDelivery` |
| 12 | Quit/termination cleanup | Reject as incomplete | Adapt explicit recorder/monitor teardown, reject whole app delegate | Public model `stop` and adapter cancellation |
| 13 | Independence from Guide/Keychain/Sentry/OpenAI | Structural reference only | Structural reference only | Dictation dependency composition with no Guide/cloud requirement |

## Complete Gate A map

### 1. Global shortcut down/up/toggle/Escape

- **Current serpy production path:** `App/GuideCompanionApp.swift`
  `makeShortcutMonitor` constructs one `GlobalShortcutService`;
  `GlobalShortcutEventAdapter` normalizes CGEvents;
  `GlobalShortcutEventRouter.route` emits Dictation presses/releases;
  `GuideAppModel.hotKeyPressed` asks `DictationActivationPolicy` to start or
  finish. `GlobalShortcutService.route` forwards Escape to the shared cancel
  callback.
- **Current coverage:** `GlobalShortcutEventRouterTests`,
  `GlobalShortcutEventAdapterTests`, `DictationActivationPolicyTests`,
  `GlobalHotKeyConfigurationTests`, and the pure happy/cancel paths in
  `StateMachineTests`. Coverage does not connect a routed event to the complete
  Dictation workflow.
- **Evidenced gap:** Escape and shortcut callbacks cannot be exercised against
  controlled speech/insertion adapters because `GuideAppModel` constructs the
  real adapters. Current Dictation is toggle-based; adding a new hold mode is
  outside stabilization unless the current product already exposes it.
- **Primary donor:**
  [`ShortcutManager.handleKeyDown/handleKeyUp` and `.escape`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/ShortcutManager.swift#L56-L72),
  [start/hold timing](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/ShortcutManager.swift#L125-L224).
  No complete shortcut lifecycle test exists; its Escape route loses access to
  decoding after `activeVm` becomes `nil`.
- **Secondary donor:**
  [`RecordingLifecycle.keyDown/keyUp`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/Sources/OpenWisprLib/RecordingLifecycle.swift#L3-L47)
  with [`RecordingLifecycleTests`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/Tests/OpenWisprTests/RecordingLifecycleTests.swift#L4-L54).
- **Disposition:** Adapt OpenSuperWhisper's immediate-start ordering; adopt the
  secondary donor's pure toggle/hold cases only where they match current serpy.
  Reject both donor monitor implementations because serpy's CGEvent tap is the
  installed path that previously replaced failed NSEvent delivery.
- **Public seam:** existing `GlobalShortcutEventRouter.route` and
  `DictationActivationPolicy.shortcutAction/escapeAction`; public model state is
  the integration observation.
- **Minimal serpy glue:** inject/capture the existing shortcut callbacks in a
  model fixture; no new shortcut framework.
- **Import record:** if donor lifecycle code or tests are copied/derived, create
  `docs/imports/dictation-shortcut-lifecycle.md` naming both pinned paths,
  retained logic, modifications, and excluded donor preferences/singletons.
- **Verification:** Swift Testing unit tests; exact physical shortcut remains an
  installed-artifact check.
- **Caveat:** Neither donor's shortcut registration proves delivery on this Mac.

### 2. Immediate recording acknowledgement

- **Current serpy production path:** `GuideAppModel.startDictation` checks
  permissions, captures the focused target, starts `AppleSpeechTranscriber`,
  changes the state machine to `.recording`, and only then publishes
  `Listening…` through `CompanionPresentation`.
- **Current coverage:** state-machine transition tests only; no ordering or
  nonactivation assertion.
- **Evidenced gap:** synchronous target capture and speech startup precede the
  visible `.recording` acknowledgement, so a slow AX target can delay feedback.
- **Primary donor:**
  [`ShortcutManager.handleKeyDown`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/ShortcutManager.swift#L147-L193)
  starts recording before bounded AX anchor resolution;
  [`IndicatorWindowManager.prepare/presentWindow`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/Indicator/IndicatorWindowManager.swift#L15-L100)
  prepares first and later presents a nonactivating, click-through panel.
- **Secondary donor:** `AppDelegate.handleRecordingStart` publishes `.recording`
  before `AudioRecorder.startRecording` at
  [`AppDelegate.swift`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/Sources/OpenWisprLib/AppDelegate.swift#L274-L290),
  but has no ordering test.
- **Disposition:** Adapt the start-before-slow-placement invariant, not donor UI.
- **Public seam:** after a public Dictation activation, model `phase`, status,
  and presentation must acknowledge the attempt before a controlled slow target
  adapter resolves; presentation internals are not asserted.
- **Minimal serpy glue:** make target capture injectable/asynchronous or publish
  a truthful preparing/recording acknowledgement before slow AX work.
- **Import record:** `docs/imports/dictation-immediate-feedback.md` if donor
  ordering is derived.
- **Verification:** headless direct integration for ordering; installed focus and
  nonactivation observation.
- **Caveat:** the UI must not claim the microphone is recording before startup
  actually succeeds; a truthful compact `Preparing…` state is acceptable.

### 3. Microphone selection and readiness

- **Current serpy production path:** `PermissionService.snapshot` reads
  microphone/Speech/Accessibility state. `AppleSpeechTranscriber` uses the
  current/default AVAudioEngine input and reports whether an on-device
  recognizer is available. Version 1 adds no microphone picker.
- **Current coverage:** `PermissionCallbackBridgeTests` covers only callback
  actor isolation; `SpeechCompletionGateTests` does not cover readiness.
- **Evidenced gap:** no deterministic test proves startup reads permission state
  without requesting it, or that missing/unusable audio input produces the
  required staged failure.
- **Primary donor:**
  [`MicrophoneService.getActiveMicrophone/selectMicrophone`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/MicrophoneService.swift)
  and the separation between
  [`PermissionsManager.checkAllPermissions`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/PermissionsManager.swift#L117-L160)
  and explicit request methods. `NoMicrophoneGuardTests` cover truthful state.
- **Secondary donor:**
  [`AudioDeviceManager.resolveConfiguredDeviceID`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/Sources/OpenWisprLib/AudioDeviceManager.swift#L74-L82)
  with [`AudioDeviceManagerTests`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/Tests/OpenWisprTests/AudioDeviceManagerTests.swift#L4-L26).
- **Disposition:** Adapt the read-versus-request contract. Reject new device
  selection UI and donor system-default switching as out of scope. Adopt UID
  resolution only if a current serpy selection already needs stabilization.
- **Public seam:** `PermissionChecking.snapshot` and
  `SpeechTranscribing.isOnDeviceAvailable/availabilityDescription`.
- **Minimal serpy glue:** make current concrete readiness providers conform to
  small `GuideCore` protocols.
- **Import record:** only required if donor resolution/guard code is derived;
  name CoreAudio dependencies and omit donor settings/identity.
- **Verification:** headless adapter contracts; real TCC and microphone remain
  installed checks.
- **Caveat:** donor microphone tests query host devices and are not routine
  headless tests.

### 4. Audio start, stop, cancellation, and final-word tail

- **Current serpy production path:** `AppleSpeechTranscriber.start` installs an
  AVAudioEngine tap and begins streaming recognition. `stop` immediately stops
  capture, calls `endAudio`, and waits up to five seconds for a final result;
  `cancel` tears down the request/task/tap.
- **Current coverage:** `SpeechCompletionGateTests` preserves a final result
  received before stop. No test covers rapid start/stop serialization, audio
  captured at release, or cancellation during stop.
- **Evidenced gap:** stopping capture immediately at shortcut release may clip
  the final word; start/stop/cancel mutations are MainActor-confined but no test
  proves a stop cannot overtake startup.
- **Primary donor:**
  [`AudioRecorder.workQueue` and `stopTailDuration`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/AudioRecorder.swift#L14-L28),
  [`startRecording`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/AudioRecorder.swift#L143-L213),
  and [`stopRecording/cancelRecording`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/AudioRecorder.swift#L215-L273).
  It serializes mutations and captures a 0.25-second tail, but has no tail test
  and cancellation cannot reach the detached recorder during that tail window.
- **Secondary donor:**
  [`AudioRecorder.startRecording/stopRecording/teardown`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/Sources/OpenWisprLib/AudioRecorder.swift#L26-L117).
- **Disposition:** Adapt OpenSuperWhisper's serialized lifecycle and bounded tail
  after first reproducing final-word loss. Reject replacing streaming Apple
  Speech with either donor's file-first recorder.
- **Public seam:** `SpeechTranscribing.start`, `stop`, and `cancel`, with a
  controllable clock/audio-source adapter under `AppleSpeechTranscriber`.
- **Minimal serpy glue:** preserve the existing engine and extend only its stop
  lifecycle; make the tail cancellable.
- **Import record:** `docs/imports/dictation-recording-tail.md`, including exact
  donor constants/algorithms and serpy cancellation changes.
- **Verification:** deterministic lifecycle tests, an audio fixture contract,
  then installed spoken final-word observation.
- **Caveat:** a copied `0.25` constant without a failing fixture is not evidence.

### 5. Existing local transcription engine

- **Current serpy production path:** `AppleSpeechTranscriber` requires
  `SFSpeechAudioBufferRecognitionRequest.requiresOnDeviceRecognition = true`,
  streams partials, and returns the final text locally.
- **Current coverage:** only completion timing and callback isolation helpers;
  local/offline behavior remains installed evidence.
- **Evidenced gap:** the engine is concrete and therefore blocks a direct
  workflow test. No source finding justifies replacing it in Version 1.
- **Primary donor:**
  [`TranscriptionEngine`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/Engines/TranscriptionEngine.swift#L4-L12)
  with Whisper/FluidAudio implementations and conversion/VAD tests.
- **Secondary donor:**
  [`Transcriber.transcribe`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/Sources/OpenWisprLib/Transcriber.swift#L3-L55)
  shells out to whisper.cpp; its tests cover arguments/marker cleanup, not the
  current Apple Speech engine.
- **Disposition:** Reject engine replacement and dependencies. Adapt only the
  donors' small cancellable engine interface shape.
- **Public seam:** `SpeechTranscribing`; production adapter remains
  `AppleSpeechTranscriber`.
- **Minimal serpy glue:** protocol conformance and controlled in-memory adapter.
- **Import record:** not required for original protocol glue; required if donor
  interface code/comments are substantially derived.
- **Verification:** direct integration with a deterministic transcriber; installed
  offline Speech observation.
- **Caveat:** OpenSuperWhisper's FluidAudio path may download models and is not
  allowed in routine work.

### 6. Transcription cancellation and late-result suppression

- **Current serpy production path:** `GuideAppModel.finishDictation` creates an
  unretained `Task`; `cancelDictation` calls only `transcriber.cancel`; `stop`
  also lacks a handle for the finish/delivery task.
- **Current coverage:** pure state cancellation proves only that a subsequent
  state-machine insertion transition is invalid. It does not observe adapter
  calls or late async work.
- **Evidenced gap:** a final result may win the race with `cancel`, after which
  persistence/insertion can continue because the owning task is not stored or
  cancelled. Cancellation while `.inserting` cannot stop that task.
- **Primary donor:**
  [`TranscriptionService.cancelTranscription/transcribeAudio`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/TranscriptionService.swift#L15-L177)
  and [`TranscriptionQueue` cancellation ID and post-await guards](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/TranscriptionQueue.swift#L41-L55).
  Its indicator path still launches unretained work, so it is not a complete
  solution.
- **Secondary donor:** `open-wispr` has no cancellable transcription task; its
  [`AppDelegate.handleRecordingStop`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/Sources/OpenWisprLib/AppDelegate.swift#L293-L341)
  dispatches unowned work and is rejected.
- **Disposition:** Adapt owned `Task` plus generation/session guards from the
  primary donor. Reject either donor's whole orchestration path.
- **Public seam:** public model `cancelDictation`/`stop`, observed through phase,
  delivery state, recovery, and a controlled `TextInserting` adapter.
- **Minimal serpy glue:** retain the finish task, cancel it on Escape/stop, and
  guard every post-await mutation with the active attempt identity.
- **Import record:** `docs/imports/dictation-task-cancellation.md` if donor guard
  structure is derived.
- **Verification:** Swift Testing with a blocking transcriber and insertion
  adapter; no target mutation after cancellation.
- **Caveat:** cancellation after a paste event has already been posted cannot
  undo the destination; the test must establish the last cancellable point.

### 7. Focused destination capture

- **Current serpy production path:** `TextInsertionService.captureFocusedTarget`
  captures the frontmost PID, bundle ID, and focused AX element before recording;
  `insert` revalidates the PID before and after paste.
- **Current coverage:** no deterministic capture/revalidation contract. Installed
  historical evidence exists but does not satisfy current Version 1 acceptance.
- **Evidenced gap:** `FocusedTextTarget` has a fileprivate initializer and the
  concrete service cannot be substituted, preventing controlled focus-switch
  workflow tests.
- **Primary donor:** `FocusUtils.getFocusedElement` is private and used for
  indicator placement only at
  [`FocusUtils.swift`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/Utils/FocusUtils.swift#L23-L47).
  No destination is retained for delivery.
- **Secondary donor:** `TextInserter` pastes into the then-current application;
  no target is captured.
- **Disposition:** Reject both donor paths. Keep serpy's stronger behavior.
- **Public seam:** `FocusedTextTargetReading.captureFocusedTarget`, returning an
  opaque target accepted by `TextInserting` without exposing AX types to Core.
- **Minimal serpy glue:** protocol/type erasure around the existing target, not a
  new focus algorithm.
- **Import record:** none; this remains serpy code.
- **Verification:** headless controlled target identity/revalidation contract;
  installed TextEdit/Chrome focus observation.
- **Caveat:** a fake target test cannot prove AX support in a real application.

### 8. Text insertion without submission

- **Current serpy production path:** `TextInsertionService.insert` performs
  focus-verified Command-V first and then verified Accessibility fallbacks. It
  never posts Return.
- **Current coverage:** `TextValueReplacementTests` checks selected UTF-16 range
  and caret. No deterministic test covers full paste event ordering or absence
  of unrelated key events.
- **Evidenced gap:** the paste key is hard-coded to virtual key 9, and delivery
  confirmation only checks that the value changed rather than matching the
  expected resulting text.
- **Primary donor:**
  [`ClipboardUtil.sendCmdV`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/Utils/ClipboardUtil.swift#L64-L96)
  resolves layout-aware Cmd-V. Its paste integration tests launch TextEdit and
  change system input sources and are excluded from the local lane.
- **Secondary donor:**
  [`TextInserter`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/Sources/OpenWisprLib/TextInserter.swift#L26-L84)
  injects the paste action and resolves the current layout; its
  [`testInsertWritesTranscriptionBeforePastingAndSchedulesRestore`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/Tests/OpenWisprTests/TextInserterTests.swift#L12-L31)
  checks order headlessly.
- **Disposition:** Adapt layout-aware key resolution and adopt the secondary
  donor's injected paste-action/order test. Keep serpy target revalidation and
  delivery result types.
- **Public seam:** `TextInserting.insert(_:into:) -> TextInsertionMethod`.
- **Minimal serpy glue:** inject pasteboard, paste action, and delay/clock into
  the existing service; assert no Return event exists.
- **Import record:** `docs/imports/dictation-layout-aware-paste.md`, naming which
  donor resolver/test is used and excluding donor app settings.
- **Verification:** headless adapter contract plus installed TextEdit/Chrome.
- **Caveat:** keyboard-layout support is for the paste command, not the deferred
  spoken-language features in Issues #2/#3.

### 9. Pasteboard preservation and newer-copy protection

- **Current serpy production path:** `PasteboardSnapshot` captures every item and
  representation, and `restoreIfUnchanged` restores only when `changeCount`
  proves ownership. `TextInsertionService.paste` restores on its normal explicit
  paths.
- **Current coverage:** `PasteboardSnapshotTests` covers multiple
  representations/items and newer user clipboard takeover.
- **Evidenced gap:** after placing transcript text on the pasteboard, throwing
  sleeps can exit before restoration; restoration is not guaranteed by an owned
  transaction/cleanup scope. Storage failure also calls `copyTranscript`, which
  overwrites the previous clipboard before insertion begins.
- **Primary donor:**
  [`ClipboardUtil.insertText/restoreIfUnchanged`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/Utils/ClipboardUtil.swift#L29-L62)
  and [snapshot/restore](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/Utils/ClipboardUtil.swift#L164-L198),
  with [`ClipboardRestoreTests`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisperTests/StorageAndLanguageSettingsTests.swift#L133-L183).
  It preserves board-level types but not multiple pasteboard items.
- **Secondary donor:** `TextInserter` uses the same ownership rule, with
  deterministic restore and newer-copy tests at
  [`TextInserterTests.swift`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/Tests/OpenWisprTests/TextInserterTests.swift#L33-L69).
- **Disposition:** Adopt the adapter-driven deterministic test shape and
  ownership rule; adapt it to retain serpy's stronger multi-item snapshot and
  guarantee cleanup on errors/cancellation. Reject either weaker snapshot.
- **Public seam:** the public `TextInserting.insert` behavior, not private
  `PasteboardSnapshot` internals.
- **Minimal serpy glue:** injected pasteboard/clock and an owned restoration
  transaction covering every exit.
- **Import record:** `docs/imports/dictation-pasteboard-transaction.md` if donor
  scheduler/test code is derived.
- **Verification:** Swift Testing with an in-memory pasteboard; one installed
  system-pasteboard observation.
- **Caveat:** `changeCount` proves ownership, not successful paste.

### 10. Preserve-before-delivery and Last Dictation recovery

- **Current serpy production path:** `GuideAppModel.finishDictation` calls
  `TranscriptHistoryStore.preserve` before `TextInsertionService.insert`.
  `loadTranscriptHistory`, Copy, Retry, and Delete expose the newest bounded
  recovery. Default retention is one record, 10 minutes confirmed or 24 hours
  unconfirmed/failed.
- **Current coverage:** `TranscriptHistoryStoreTests` covers ordering primitives,
  reload, states, bounds, retention, permissions, audio cleanup, and migration;
  `EphemeralTranscriptRecoveryTests` covers in-memory preservation. No integration
  test proves the model awaits persistence before insertion or wires every
  recovery action correctly.
- **Evidenced gap:** the store and insertion services are concrete, so failure
  ordering cannot be forced. On storage failure the model automatically replaces
  the clipboard, conflicting with the Version 1 preservation rule.
- **Primary donor:** OpenSuperWhisper's
  [`RecordingStore`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/Models/Recording.swift#L72-L205)
  is full-history GRDB storage. The indicator starts an async add and then pastes
  at [`IndicatorWindow.swift`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/Indicator/IndicatorWindow.swift#L176-L197),
  so durable preserve-before-delivery is not guaranteed.
- **Secondary donor:** `RecordingStore` stores/prunes audio files only and has no
  Last Dictation delivery record.
- **Disposition:** Reject both. Keep serpy's accepted bounded recovery.
- **Public seam:** existing `TranscriptHistoryStore` through a small
  `LastDictationStoring` interface, observed through model recovery state/actions.
- **Minimal serpy glue:** inject the store and remove automatic clipboard
  replacement on storage failure while retaining visible in-memory recovery.
- **Import record:** none unless donor code is unexpectedly used.
- **Verification:** headless direct integration with a blocking/failing store;
  installed relaunch/Copy/Retry/Delete check.
- **Caveat:** full donor history and changed defaults are post-Version 1.

### 11. Confirmed, unconfirmed, and failed delivery

- **Current serpy production path:** `TextInsertionMethod.isConfirmed` distinguishes
  observable Accessibility/paste results from `.pasteUnconfirmed`;
  `TranscriptHistoryStore.updateDelivery` persists the state; model UI preserves
  recovery for unconfirmed/failed results.
- **Current coverage:** confirmation enum assertions and store state updates.
  No workflow test proves the right state follows each delivery outcome.
- **Evidenced gap:** both paste and selected-text Accessibility confirmation use
  `valueAfter != valueBefore`, which does not prove the expected transcript
  appeared and may falsely confirm an unrelated concurrent edit.
- **Primary donor:** `ClipboardUtil.insertText` returns `Void` and has no receipt,
  target readback, or state persistence.
- **Secondary donor:** `TextInserter.insert` also returns `Void`.
- **Disposition:** Reject both donor delivery models. Keep and strengthen serpy's
  model with exact expected-result verification where the target exposes enough
  state; otherwise remain unconfirmed.
- **Public seam:** `TextInserting.insert` result plus model
  `lastInsertionMethod`, status, recovery, and stored delivery state.
- **Minimal serpy glue:** an independently computed expected value/readback
  contract for verifiable AX targets.
- **Import record:** none; serpy-specific behavior.
- **Verification:** headless success/unconfirmed/failure fixtures; installed
  TextEdit confirmed and Chrome truthful-result checks.
- **Caveat:** posting Cmd-V is never proof of delivery.

### 12. Quit and termination cleanup

- **Current serpy production path:** `GuideAppDelegate.applicationWillTerminate`
  calls `GuideAppModel.stop`; the model stops the shortcut monitor, cancels both
  transcribers/Guide work, stops speech, and hides the companion.
- **Current coverage:** `ApplicationPresencePolicyTests` covers only regular versus
  terminating presence. No test proves all Dictation work is owned and cancelled.
- **Evidenced gap:** the finish/insertion task, delayed manual/retry tasks, and
  scheduled reset tasks are mostly not retained, so `stop` cannot cancel or await
  them. `started` is not reset, which prevents restarting the same model instance.
- **Primary donor:** `IndicatorViewModel.cleanup` clears local timers and
  subscriptions, while `AudioRecorder` removes old temporary recordings at init;
  no `applicationWillTerminate` performs global task cleanup.
- **Secondary donor:**
  [`AudioRecorder.teardown`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/Sources/OpenWisprLib/AudioRecorder.swift#L26-L41)
  and [`HotkeyManager.stop`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/Sources/OpenWisprLib/HotkeyManager.swift#L28-L33)
  are explicit, but its app delegate does not call full teardown on termination.
- **Disposition:** Adapt explicit adapter teardown; reject both donor application
  lifecycle implementations as complete solutions.
- **Public seam:** public `GuideAppModel.stop` followed by observable inactive
  phase and adapter cancellation/termination state.
- **Minimal serpy glue:** retain every Dictation-owned task and cancel it in one
  stop path; reset lifecycle state only if current restart behavior requires it.
- **Import record:** required only for substantially derived teardown code.
- **Verification:** headless task/adapter teardown test; one exact installed
  quit/relaunch/process observation.
- **Caveat:** headless task cancellation does not prove macOS process uniqueness.

### 13. Independence from Guide, Keychain, Sentry, and OpenAI

- **Current serpy production path:** Dictation methods do not call a guidance
  provider, but `GuideAppModel` requires Guide/Talk objects and constructs real
  permission, speech, insertion, history, and presentation objects internally.
  `GuideAppComposition` constructs Sentry configuration, Keychain, and OpenAI
  objects before the model exists; model initialization immediately reads the
  Talk credential.
- **Current coverage:** no combined regression. Talk tests inject a credential
  store and shortcut monitor, but cannot inject Dictation adapters.
- **Evidenced gap:** Dictation is logically independent but not structurally
  composable or testable without Guide/cloud objects. The earlier UI attempt
  reached the production Keychain merely by launching its test app.
- **Primary donor:**
  [`OpenSuperWhisperApp.init`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/OpenSuperWhisper/OpenSuperWhisperApp.swift#L54-L67)
  constructs only local shortcut/microphone/model units. The pinned manifest has
  no Guide, Sentry, OpenAI, or Keychain dependency, but it relies heavily on
  global singletons and FluidAudio may download models.
- **Secondary donor:** the pinned `open-wispr` app composes recorder, local
  transcriber, inserter, config, and status bar without Guide/cloud systems. This
  is structural evidence only, not a regression seam.
- **Disposition:** Adapt the donors' narrow local composition principle; reject
  their singleton application structures.
- **Public seam:** construct/exercise current model Dictation through injected
  `PermissionChecking`, `SpeechTranscribing`, `FocusedTextTargetReading`,
  `TextInserting`, and `LastDictationStoring` adapters while Guide failure is
  independently injected. Test composition must not construct production cloud
  adapters.
- **Minimal serpy glue:** separate Dictation dependency construction from
  optional Guide/Talk construction without changing product behavior.
- **Import record:** none for original composition glue; any copied donor
  structure must be recorded and stripped of identity/configuration.
- **Verification:** headless composition/direct-integration test with unavailable
  Guide and zero cloud/credential/telemetry capabilities; installed offline run.
- **Caveat:** the final isolated test-runtime composition belongs to Phase 4;
  Phase 1 should add only the independence needed to stabilize Dictation.

## Is a new coordinator necessary?

Not on current evidence.

Neither donor has a reusable coordinator that satisfies the required workflow:
OpenSuperWhisper splits orchestration between singleton managers and view models,
and open-wispr puts it in `AppDelegate`. Both contain cancellation/ownership gaps.
Copying either orchestration structure would regress serpy's destination and
recovery behavior.

The smallest Gate B starting point is to preserve `GuideAppModel` as the current
public orchestration interface, inject its four concrete Dictation dependencies
plus readiness behind the protocols already promised by `ARCHITECTURE.md`, and
retain/cancel the existing finish task. If the first vertical red test cannot be
made green without duplicating state or exposing platform details, stop and
propose a narrowly shaped coordinator from that evidence. Do not create it in
anticipation.

## Gate B vertical order recommended by this map

1. **Cancellation ownership:** blocking local transcriber; Escape/stop produces
   no persistence or insertion after a late result. Adapt primary-donor task and
   attempt guards.
2. **Preserve-before-delivery:** successful final transcript is durably preserved
   before the injected insertion adapter is invoked. Keep serpy storage.
3. **Truthful delivery:** exact confirmed, unconfirmed, and failed receipts update
   recovery correctly. Keep serpy state model.
4. **Clipboard transaction:** injected pasteboard/paste action proves write →
   paste → delayed restoration, all representations survive, newer copy wins,
   and error/cancellation restores when still owned. Adapt both donor test shapes.
5. **Final-word tail:** reproduce loss with an audio/clock fixture before adapting
   OpenSuperWhisper's serialized cancellable tail.
6. **Immediate feedback:** a blocked target-read fixture cannot delay truthful
   visible acknowledgement.
7. **Dictation independence:** failing/unavailable Guide configuration cannot
   block the complete injected Dictation flow.
8. **Termination:** `stop` cancels all owned Dictation work and leaves every
   adapter idle.
9. **Installed acceptance:** after source review and affected headless suites,
   verify one exact signed artifact in TextEdit and Chrome.

Each slice is one failing behavior test, the smallest donor-derived correction,
the donor test where applicable, and the corresponding serpy integration
assertion. No broad refactor is part of these cycles.

## License and import requirements

### OpenSuperWhisper

The pinned root [`LICENSE`](https://github.com/Starmel/OpenSuperWhisper/blob/bef6bc0421d0c010e8f2fb4288c0d74978c8b964/LICENSE)
is MIT, copyright 2024 OpenSuperWhisper. Copies or substantial portions must
retain its copyright and permission notice.

The root license does not automatically relicense dependencies. Relevant pinned
dependencies include MIT KeyboardShortcuts, GRDB, whisper.cpp, and
asian-autocorrect, plus Apache-2.0 FluidAudio. Serpy should not import these
dependencies for Phase 1; any exception must identify the exact lockfile and
license because the donor repository contains differing package-resolution
snapshots.

### open-wispr

The pinned root [`LICENSE`](https://github.com/human37/open-wispr/blob/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f/LICENSE)
is MIT, copyright 2026 human37. Copies or substantial portions must retain its
copyright and permission notice.

### Per-import record

Before committing any copied or derived implementation/test, create one focused
record under `docs/imports/` that names:

- upstream repository, exact commit, file, symbols/ranges, and donor tests;
- the full applicable MIT notice and any retained dependency license;
- whether the unit was adopted or adapted;
- every serpy-specific modification;
- dependencies retained and removed;
- regression tests protecting the behavior; and
- donor product identity, assets, preferences, bundle/signing data, credentials,
  hosted services, update feeds, analytics, and release destinations removed.

An idea or invariant independently reimplemented from the specification may not
constitute a code import, but the Gate B change should still cite this map in its
commit/issue evidence. Legal conclusions beyond the explicit license text are
not asserted here.

## Sources

- [Issue #12](https://github.com/serpcompany/serpy-clicky-mac-app/issues/12)
- [Superwhisper product](https://superwhisper.com/)
- [Superwhisper introduction](https://superwhisper.com/docs/get-started/introduction)
- [OpenSuperWhisper pinned source](https://github.com/Starmel/OpenSuperWhisper/tree/bef6bc0421d0c010e8f2fb4288c0d74978c8b964)
- [open-wispr pinned source](https://github.com/human37/open-wispr/tree/7ab4e62e8f182f3ecc2116e1094a1eb4416a248f)
