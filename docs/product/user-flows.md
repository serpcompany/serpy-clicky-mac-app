# serpy user flows

This is the canonical map of what a person should be able to accomplish with
serpy. It reconstructs product intent from GitHub Issues, `PRODUCT.md`,
`ACCEPTANCE.md`, ADRs, and installed-app evidence. Tests verify these flows but
do not redefine them.

For Version 1 scope and execution order, read
`docs/product/version-1-stabilization.md`. Version 1 stabilizes existing
Dictation and Guide behavior; requested additions remain later work.

Last reconciled: 2026-09-04

## Status language

- **Accepted:** part of the current product contract.
- **Requested:** recorded in GitHub but not yet accepted into the product
  contract.
- **Deferred:** deliberately outside the current product.
- **Evidence pending:** implemented or mechanically tested, but required
  installed observation or owner acceptance remains red.

An open issue is not proof that a behavior is unimplemented, and a passing test
is not proof that the installed journey works.

## Flow index

| ID | User outcome | Contract status | Primary source |
| --- | --- | --- | --- |
| UF-01 | Use the existing permission setup without loops | Stabilization; onboarding redesign deferred | `PRODUCT.md`, A1–A3, #1 |
| UF-02 | Find, reopen, and quit the running app | Accepted; evidence pending | Journey B, B1–B9, #4, #7 |
| UF-03 | Dictate text into another application | Accepted; evidence pending | Journey A, A4–A9, #1 |
| UF-04 | Cancel dictation without changing the target | Accepted; evidence pending | A7, #7 |
| UF-05 | Recover text after failed or uncertain delivery | Accepted; default-policy change requested | A10–A12, D4, D7, #5 |
| UF-06 | Dictate using the selected keyboard language | Deferred until after Version 1 | #2 |
| UF-07 | Detect spoken language independently | Deferred until after Version 1 | #3 |
| UF-08 | Ask one grounded question about the current screen | Accepted; evidence pending | Journey C, C1–C17, #7 |
| UF-09 | Continue a multi-step walkthrough | Accepted; evidence pending | C18–C25, #7 |
| UF-10 | Cancel Guide work and keep the target usable | Accepted; evidence pending | C8, C16, C21, #7 |
| UF-11 | Explicitly opt into OpenAI multimodal Talk | Accepted for internal testing; evidence pending | ADR 0006, C18–C22, #7 |
| UF-12 | Turn a handled development failure into agent-readable evidence | Development pilot | ADR 0007, #8, #9 |

## Golden-test traceability

Issue [#13](https://github.com/serpcompany/serpy-clicky-mac-app/issues/13)
defines the enforcement harness. `core-tests` executes the named headless
contracts. `app-build` compiles both the production app and the UI-test bundle
without launching either. `golden-ui-tests` is the Xcode Cloud-only lane using
`GuideCompanionGolden.xctestplan`; it is not enabled or required until ten
consecutive isolated runs pass.

The `GT-*` fixture tests prove that the isolated runner, observable-state
assertions, and failure paths work. They do not replace the adjacent production
contract tests or installed evidence.

| Flow | Headless production contract IDs | Isolated XCUI ID | Installed evidence |
| --- | --- | --- | --- |
| UF-01 | `StateMachineTests/testPermissionCannotRequestBeforeExplanation`, `GT-UF01-001` | `GoldenPermissionsAndLifecycleUITests/test_GT_UF01_001_permissionDenialShowsOneRecoveryRoute` | **Red:** real macOS prompt and denial/relaunch loop not observed on a post-harness artifact |
| UF-02 | `ApplicationPresencePolicyTests/a running app stays regular when Settings opens or closes`, `SettingsWindowPresentationTests/testMenuSettingsActionActivatesApplicationBeforeOpeningWindow`, `GT-UF02-001` | `GoldenPermissionsAndLifecycleUITests/test_GT_UF02_001_launchesOneHarnessWindowWithoutIdleOverlay` | **Red:** Dock, Command-Tab, Quit, relaunch, and one production process/window not observed on a post-harness artifact |
| UF-03 | `RecordingCoordinatorTests/final transcript is preserved before delivery`, `DurableDictationSessionTests/multi-minute PCM input preserves sentinels across the one-minute boundary`, `PasteboardSnapshotTests/restores all items and representations while it owns the pasteboard`, `GT-UF03-001` | `GoldenDictationUITests/test_GT_UF03_001_dictationShowsPartialThenConfirmedDelivery` | **Red:** real microphone, focus, clipboard, and exact cross-app insertion require the installed lane |
| UF-04 | `RecordingCoordinatorTests/cancellation suppresses a late transcript and all delivery`, `RecordingCoordinatorTests/cancellation while insertion is pending prevents target mutation`, `GT-UF04-001` | `GoldenDictationUITests/test_GT_UF04_001_cancelSuppressesLateDictationResult` | **Red:** physical Escape timing against a real target requires the installed lane |
| UF-05 | `TranscriptHistoryStoreTests/persists before delivery and survives a new store instance`, `RecordingCoordinatorTests/an interrupted audio checkpoint becomes Last Dictation without automatic insertion`, `GT-UF05-001` | `GoldenDictationUITests/test_GT_UF05_001_recoveryExposesCopyRetryDelete` | **Red:** installed quit/relaunch recovery requires the installed lane |
| UF-08 | `GuideTurnCoordinatorTests/testAmbientTurnLocksTargetBeforeListeningAndAnswersWithFreshContext`, `GuideTurnCoordinatorTests/testCompleteAnswerReachesConversationAmbientPresentationAndSpeechWithoutTruncation`, `GT-UF08-001` | `GoldenGuideUITests/test_GT_UF08_001_questionReachesFollowUpReadyWithoutComposer` | **Red:** real shortcut, microphone, capture, answer, speech, and focus require the installed lane |
| UF-09 | `GuideProgressionPolicyTests/fresh request-scoped evidence advances, stays, or completes exactly`, `GuideTurnCoordinatorTests/testExplicitReinvocationUsesFreshCaptureAndShowsOnlyTheAdvancedStep`, `GT-UF09-001` | `GoldenGuideUITests/test_GT_UF09_001_walkthroughRequiresFreshEvidenceForEachStep` | **Red:** real Chrome walkthrough and click-through behavior require the installed lane |
| UF-10 | `GuideTurnCoordinatorTests/testCancellingWhileExactWindowCaptureIsPendingCannotProduceAnAnswer`, `GuideTurnCoordinatorTests/testCancellingWhileSpeakingStopsAudioAndDismissesTheReadableAnswer`, `GuideTurnCoordinatorTests/testCancellationAtReadyForFollowUpClearsPlanCueAndPendingProgressionIdempotently`, `GT-UF10-001` | `GoldenGuideUITests/test_GT_UF10_001_cancelSuppressesLateGuideOutput` | **Red:** phase-by-phase installed Escape and focus checks remain unobserved |
| UF-11 | `MultimodalTalkContractTests/testCloudTalkRequiresSelectionConsentAndCredential`, `OpenAIMultimodalAdapterTests/testCloudRouterRefusesTransmissionUntilSelectionDisclosureAndCredentialAreAllPresent`, `OpenAIMultimodalAdapterTests/testCancellingLiveBytesTransportStopsURLProtocolAndYieldsNoLateCompletion`, `GT-UF11-001` | `GoldenGuideUITests/test_GT_UF11_001_openAITalkUsesOnlyInMemoryCredentialAndFixtureResponse` | **Red:** a live request requires separate owner approval and the installed lane |
| UF-12 | `DiagnosticIncidentTests/testMalformedGuidanceFailureProducesOnlyAllowlistedClassification`, `SentryDiagnosticReporterTests/testHandledEventScrubberRemovesSDKAddedIdentityAndContext`, `GT-UF12-001` | `GoldenGuideUITests/test_GT_UF12_001_malformedPlanShowsTypedHandledFailure` | **Red:** real Sentry transport/retrieval requires a separately approved named run |

UF-06 and UF-07 are deferred. They intentionally have no golden test IDs.

## UF-01 — Install, launch, and understand permissions

**Starting state:** A fresh notarized build is installed normally with no prior
serpy preferences or permissions.

**Flow:**

1. The user launches serpy from Finder.
2. serpy explains why a permission is needed before macOS prompts for it.
3. Microphone is requested for dictation. Accessibility is requested only when
   insertion needs it. Screen Recording is requested only after Guide intent.
4. Denial produces one understandable recovery route rather than another prompt
   loop.
5. Relaunch preserves the truthful permission state.

**Must remain true:** Dictation setup does not require an assistant, account,
API key, Screen Recording, or network.

**Verification:** Headless permission state-machine tests plus a fresh installed
recording of macOS-owned prompts and denial/retry.

**Traceability:** [Issue #1](https://github.com/serpcompany/serpy-clicky-mac-app/issues/1),
Acceptance A1–A3, C1–C2, D3.

## UF-02 — Find, reopen, and quit the running app

**Starting state:** serpy is running and Settings may be closed.

**Flow:**

1. serpy remains visible in the Dock and Command-Tab.
2. Closing Settings leaves the application running.
3. Selecting serpy in the Dock foregrounds its one normal Settings window.
4. Dock Quit terminates the application.
5. Relaunch creates one app instance and one Settings window.

**Must remain true:** Idle serpy has no persistent cursor-following badge.
Transient surfaces do not turn Settings into a floating window.

**Unresolved request:** Issue #4 also asks for a setting that hides the Dock
icon. The accepted Journey B currently requires Dock presence for the complete
running lifetime. That optional setting needs a product decision before it can
become part of this flow.

**Verification:** Presence/window policy tests, XCUI launch/window tests, and
installed Dock/Command-Tab/quit observation.

**Traceability:** [Issue #4](https://github.com/serpcompany/serpy-clicky-mac-app/issues/4),
[Issue #7](https://github.com/serpcompany/serpy-clicky-mac-app/issues/7), B1–B9.

## UF-03 — Dictate into another application

**Starting state:** Required dictation permissions are granted and a supported
editable target is focused.

**Flow:**

1. The user invokes the configured dictation shortcut.
2. serpy acknowledges recording without activating itself.
3. The user speaks and invokes the stop action.
4. The completed transcript is persisted for crash recovery before delivery.
5. serpy inserts the exact text at the caret or replaces the selected text.
6. The destination is not submitted and the prior clipboard is restored if the
   paste fallback was used.
7. serpy reports confirmed, unconfirmed, or failed delivery truthfully.

**Must remain true:** No assistant/provider configuration can block this flow.
Ordinary dictation remains local.

**Verification:** State, speech, insertion, clipboard, and recovery tests;
installed TextEdit/Notes/browser/Slack/editor compatibility rows; offline run.

**Traceability:** [Issue #1](https://github.com/serpcompany/serpy-clicky-mac-app/issues/1),
[Issue #12](https://github.com/serpcompany/serpy-clicky-mac-app/issues/12),
Acceptance A4–A12. Issue #12 adds durable multi-minute audio checkpoints,
sub-minute recognition rollover on macOS 14–25, streaming finalized-prefix
accumulation on macOS 26, and recovery before insertion.

## UF-04 — Cancel dictation safely

**Starting state:** Dictation is listening or transcribing.

**Flow:** The user presses Escape. Capture/transcription stops, transient UI
clears, nothing is inserted, and a late callback cannot alter the target.

**Verification:** Deterministic state/integration tests plus installed shortcut
timing with a real focused target.

**Traceability:** Acceptance A7 and the cancellation requirements in
[Issue #7](https://github.com/serpcompany/serpy-clicky-mac-app/issues/7) and
[Issue #12](https://github.com/serpcompany/serpy-clicky-mac-app/issues/12).

## UF-05 — Recover failed or uncertain dictation

**Starting state:** A transcript completed but delivery failed, could not be
verified, or the app terminated before delivery.

**Flow:**

1. The newest Last Dictation survives relaunch within its bounded retention.
2. The user can Copy, Retry, or Delete it.
3. Optional transcript history and optional audio history have independent,
   visible controls.
4. Clear removes the transcript and associated audio.

**Current accepted default:** One bounded Last Dictation is retained; extended
history and audio history are separate opt-ins, with audio off by default.

**Later variant:** Issue #5 asks for both extended transcript and audio history
to default on for fresh installs. That policy change is outside Version 1.

**Traceability:** [Issue #5](https://github.com/serpcompany/serpy-clicky-mac-app/issues/5),
[Issue #12](https://github.com/serpcompany/serpy-clicky-mac-app/issues/12),
ADR 0005, A10–A12, D4, D7.

## UF-06 — Follow the selected keyboard language

**Status:** Deferred until after Version 1.

**Proposed outcome:** When the user selects a supported macOS input source,
dictation selects the matching local recognition language and reports an
actionable unsupported-language state when no matching model is available.

**Missing decisions:** Supported locale mapping, when selection is snapshotted,
mixed-language behavior, model availability, and fallback behavior.

**Traceability:** [Issue #2](https://github.com/serpcompany/serpy-clicky-mac-app/issues/2).

## UF-07 — Detect spoken language automatically

**Status:** Deferred improvement after UF-06 and Version 1 stabilization.

**Proposed outcome:** Dictation recognizes a supported spoken language without
depending on the currently selected keyboard language.

**Missing decisions:** Detection confidence, switching latency, code-switching,
offline model requirements, user override, and behavior when detection is
uncertain. This must not silently degrade the deterministic UF-06 selection.

**Traceability:** [Issue #3](https://github.com/serpcompany/serpy-clicky-mac-app/issues/3).

## UF-08 — Ask one grounded question about the current screen

**Starting state:** Dictation remains usable, Guide prerequisites are truthful,
and a target application window is frontmost.

**Flow:**

1. The user invokes Talk from the menu or holds the Guide chord while speaking.
2. serpy locks the exact PID, window ID, title, frame, and display.
3. Listening and live transcript appear without opening a typing composer.
4. One request-scoped capture produces structured evidence without persisting
   screenshot pixels or Guide content.
5. The selected provider returns a validated answer.
6. serpy shows a complete readable answer in the compact ambient surface and
   speaks sanitized text locally once.

**Failure behavior:** Every failure states its stage, cause, and recovery. Local
and OpenAI providers never silently substitute for one another.

**Verification:** Coordinator/provider/capture/layout contracts plus installed
physical shortcut, microphone, focus, OCR, answer, speech, and privacy checks.

**Traceability:** [Issue #7](https://github.com/serpcompany/serpy-clicky-mac-app/issues/7),
Acceptance C1–C17.

## UF-09 — Complete a multi-step walkthrough

**Starting state:** UF-08 returns a validated ordered plan containing at least
two steps.

**Flow:**

1. serpy presents only `Step 1 of n` and at most one validated cue.
2. The user performs the step; serpy does not click or type for them.
3. The user explicitly invokes Guide again.
4. A fresh request-scoped capture returns exactly one outcome: advance, stay
   with a reason, or complete.
5. The retained walkthrough does not silently restart, repeat, reuse stale
   coordinates, or claim success without evidence.

**Reference scenarios:** Chrome `File` → `New Window`, then a bounded Slack
conversation-finding flow or truthful unsupported result.

**Verification:** Provider plan fixtures, pure progression policy, coordinator,
cue projection, and speech ordering tests; installed Chrome/Slack walkthrough.

**Traceability:** [Issue #7](https://github.com/serpcompany/serpy-clicky-mac-app/issues/7),
C23–C25.

## UF-10 — Cancel Guide work and preserve the work surface

**Starting state:** Guide is listening, capturing, thinking, speaking, or ready
for follow-up.

**Flow:** Escape cancels owned work, generation and speech stop, all Guide
surfaces/cues clear, and no delayed response appears.

**Must remain true:** Ambient surfaces are nonactivating and click-through, the
target retains focus, the real pointer never moves, and the app performs no
autonomous action.

**Verification:** Blocking coordinator/provider fixtures plus installed
phase-by-phase Escape, focus, click-through, display-edge, Spaces, and full-screen
checks.

**Traceability:** [Issue #7](https://github.com/serpcompany/serpy-clicky-mac-app/issues/7),
C8, C16, C21–C22.

## UF-11 — Explicitly opt into OpenAI multimodal Talk

**Starting state:** Local Talk remains selected by default and no content has
been sent.

**Flow:**

1. The user deliberately selects OpenAI Talk.
2. serpy discloses the exact data and provider.
3. The user accepts, saves a tester-owned credential in Keychain, and performs
   a content-free provider verification.
4. During the 15-minute verification lifetime, one explicit Talk invocation may
   send only the question, bounded recent Talk text, and exact locked-window
   raster with response storage disabled.
5. Cancellation owns the request and stops late output.

**Must remain true:** Saved is not verified; expired or rejected credentials
block sending. OCR metadata is not duplicated into the request. Ordinary
dictation remains local.

**Verification:** Authorization/request/SSE/cancellation tests plus an
owner-controlled paid HIL for real answer quality, cost, disclosure, and audio.

**Traceability:** ADR 0006, [Issue #7](https://github.com/serpcompany/serpy-clicky-mac-app/issues/7),
C18–C22.

## UF-12 — Turn a development failure into agent-readable evidence

**Starting state:** A Debug build is explicitly configured for the development
Sentry pilot.

**Flow:**

1. A local or OpenAI provider produces malformed structured guidance.
2. serpy presents a visible error and recovery action.
3. A typed `guidance.plan.malformed` incident crosses the strict allowlist.
4. Sentry groups the event.
5. An authenticated Codex agent retrieves the Sentry issue without the owner
   copying diagnostics.

**Current boundary:** Only this handled event is admitted. Production/private
beta, crashes, tracing, profiling, replay, analytics, automatic GitHub creation,
automatic fixes, merge, packaging, and release remain outside this pilot.

**Verification:** Seeded-secret and reporter tests, real-coordinator fixture,
visible XCUI error/recovery, inspected envelope, HTTP 200, and fresh-agent MCP
retrieval.

**Traceability:** [Issue #8](https://github.com/serpcompany/serpy-clicky-mac-app/issues/8),
[Issue #9](https://github.com/serpcompany/serpy-clicky-mac-app/issues/9), ADR 0007.

## Unshaped aspirations from Issue #1

Issue #1 names replacing parts of Alfred, Rectangle, Xnapper, screenshot tools,
Keylume, and optionally Clipy as a broader success vision. Those names do not
yet specify user outcomes, permissions, safety rules, or acceptance criteria.
They remain aspirations rather than implementable flows. Each requires a
separate feature issue and product-boundary decision before entering this map.

## Maintenance rule

When an issue adds or changes user-visible behavior:

1. Update the affected flow or add one new flow.
2. Preserve conflicting requests as explicit variants until the owner decides.
3. Link the issue and name the verification layer.
4. Add a regression test when a deterministic seam exists.
5. Keep installed-only evidence red until the exact signed artifact is observed.
