# Issue 13 golden-flow harness evidence

Date: 2026-09-05

Base: `9427f18e80120583fe815bbd1c701b5c09367fe5`

## Rejected first design

- `GuideCompanionGoldenHost` and `GuideTestSupport` were rejected by the owner.
  Their results proved only a replacement fixture application and do not count
  as end-to-end evidence for serpy.

## Current safety design

- XCUI targets the production `GuideCompanion` application.
- `AppRuntimeMode.uiTest` resolves in `GuideCompanionApp.init` before model
  composition.
- The real lifecycle, `GuideAppModel`, GuideUI views/controllers, routing,
  `RecordingCoordinator`, and `GuideTurnCoordinator` remain in the graph.
- Only external boundaries receive deterministic in-memory or ephemeral
  adapters. No production permission, microphone, Keychain, network, Sentry,
  global-shortcut, or persistent-history adapter is constructed.
- `AppRuntimeMode.uiTest` admits only deterministic fixtures and ephemeral
  storage; microphone, permission requests, Screen Recording, production
  Keychain, persistent user data, Sentry transport, network providers, and
  global shortcuts are forbidden.
- Routine local verification uses `swift test`, unsigned `xcodebuild build`,
  and unsigned `xcodebuild build-for-testing`. An explicitly authorized focused
  lane may execute one named real-app XCUI test.
- Xcode's temporary build products are explicitly unregistered from Launch
  Services before their one owned run root is removed.

## Red-capable evidence

- `ActualAppRuntimeCompositionTests` lock mode-before-composition and the
  production-capability exclusion contract.
- Injected `core-tests` and `app-build` failures each exit 86. The combined
  `all` path also stops immediately on an injected core failure (86) or
  completed-core cleanup failure (75), never enters app-build, and removes its
  owned temporary root. This locks the explicit fail-closed sequencing needed
  because zsh suppresses implicit `errexit` inside a function used as an `if`
  condition.
- The focused-XCUI runner self-test rejects full-suite and outside-evidence
  invocations, forces TERM-ignoring and leader-exit descendants through bounded
  TERM-to-KILL escalation, interrupts a live owned group, and runs a command
  that creates build-shaped output before exiting 65. It proves the original
  status is retained and no descendant or run directory survives. A separate
  timeout fixture seeds token-owned sessions in the Darwin user temp and the
  exact serpy xctrunner container temp when present; wrapper fallback cleanup
  removes those sessions while preserving unrelated sentinels. A disk-sampling
  fixture fails its first two `du` measurements during a live process, succeeds
  on the third, and preserves both budget enforcement and the child exit code.
  A behavioral fixture removes an approved XCTest temporary root before wrapper
  cleanup and proves cleanup returns the original command status without a hang
  or residue; this exercises the `realpath`-without-`cd` implementation.
- UI session-root tests keep bounded-runner build scratch separate from the
  XCTest-owned session in XCTest's writable canonical temporary directory.
  They reject matching-name roots elsewhere and symlinked parents; independent
  run and session UUID tokens bind the parent and direct-child root.
- Session provisioning tests cover the bounded local wrapper, the exact
  documented Xcode Cloud environment, and missing, malformed, or wrong-workflow
  environments. Only the verified cloud case may create and tear down its own
  XCTest session when a wrapper token is absent.
- Debug UI-test composition is owned by the App target, derives its audit from
  concrete adapter instances accepted by the deterministic-adapter factory,
  and is guarded by the model's runtime audit precondition. No fixture or
  provider object lives in the shipping GuideUI package.
- `GuideCompanionCompositionTests` compiles the exact App-owned composition
  sources into a non-shipping unit-test target, constructs the real test model
  headlessly, asserts the exact role-to-concrete-type allowlist and production
  denylist, and proves an injected production Keychain adapter makes the audit
  fail.
- The App composition contract also drives token-owned Dictation press/release,
  Guide press/release, and cancel signals through the deterministic shortcut
  monitor and asserts that the installed `GlobalShortcutCallbacks` receive them
  in order. Golden Guide XCUI contains a static guard against transcript-opening
  arguments and visible Talk/Finish controls. Shipping GuideUI contains no
  runtime-mode fixture bar; static source and Release-binary scans reject every
  former fixture-control string.
- Golden Dictation now enters through the same token-owned shortcut callback
  driver as Guide. UF-11 manipulates the real Settings provider, disclosure,
  credential, save, and verify controls individually; deterministic adapters
  replace only Keychain and provider I/O. UF-10 releases blocked adapter work
  after cancellation, waits for a late-return receipt, and proves no ambient
  output returns. UF-03 asserts the real partial transcript on the ambient
  Dictation surface. UF-04 similarly releases cancellation-insensitive late
  transcription and insertion returns, then proves no target receipt, recovery
  UI, or ambient output appears. UF-12 asserts the visible recovery action and
  exact one-report diagnostic receipt.
- Release excludes every UI-test composition source, rejects `--ui-testing`
  before production construction, and the bounded Release build scans the
  executable for fixture symbols. The headless harness self-test also rejects
  any UI-test source under a shipping package target or missing Release
  exclusion.
- The Last Dictation fixture persists into the session's ephemeral JSON store;
  the compiled XCUI relaunch removes the seed argument before asserting
  restoration from that store. Executed proof remains red below.

## Local results

| Check | Result | Output retention | Cleanup |
| --- | --- | --- | --- |
| `scripts/test-headless-check.sh` | Green | none | Green |
| `scripts/test-golden-ui-runner.sh` | Green; adversarial process fixtures only, no app launch | none | Green |
| `scripts/run-headless-check.sh app-build` | Green; Debug app, fixture-free Release app, Release symbol scan, and actual-app XCUI bundle compiled only | none | Green |
| `scripts/run-headless-check.sh core-tests` | Green after sandbox-safe local/Xcode Cloud provisioning, shortcut callback-driver coverage, ambient failure recovery mapping, Dictation partial mapping, and target-display fallback; 100 XCTest, 87 Swift Testing cases, and 4 App composition contract tests passed | none | Green |
| `scripts/run-headless-check.sh all` | Green on Apple Silicon M3 after explicit fail-closed phase sequencing and removal of completed core build products before app-build; a red-first fixture proved the prior zsh control flow could mask an earlier phase failure, and the pre-footprint fix run exceeded 10,581,672 KiB because both lanes' separate Sentry package/build trees accumulated under one 8 GiB cap | none | Green |

## GitHub Actions results

- PR #14 verification run
  [33930252682](https://github.com/serpcompany/serpy-clicky-mac-app/actions/runs/33930252682)
  passed for exact commit `15d7056b24f46c25e3be43cb086b1c2a065180c3`:
  `core-tests` and `app-build` both completed successfully.

## Valid focused actual-app evidence

- `GT-UF12-001` passed in the real `GuideCompanion` app at tested commit
  `0a21ed140f9ebc6211f85b9ddf3636031a9ecf36` through the bounded ambient
  shortcut lane on the M3 on 2026-09-05. It executed one test in 13.624 seconds
  with zero failures or skips, asserted the exact visible malformed-guidance
  cause and recovery action, recorded exactly one allowlisted
  `guidance.plan.malformed` diagnostic, and kept the transcript inspector
  absent. The retained local bundle is
  `evidence/issue-13-real-app-UF12-m3-run3.xcresult` (generated and ignored);
  the committed redacted machine-readable proof is
  `evidence/issue-13-real-app-UF12-m3-run3-proof.json`; the committed sanitized
  `xcresulttool` subset is
  `evidence/issue-13-real-app-UF12-m3-run3-xcresult-sanitized.json`. Process and
  wrapper-root cleanup passed, with no serpy or XCUI process remaining.
- The M3 authenticated to Sentry with the read-only personal token held in
  macOS Keychain and retrieved issue `SERPY-CLICKY-MAC-APP-1` plus exact event
  `139c9b86601e416e9b59db36a6f0e952` through Sentry's API. The issue remained
  unresolved with four events; the selected event was the expected development
  Cocoa error for `com.serpcompany.guidecompanion.internal@0.1.0+42`. No token,
  raw event payload, identity, question, transcript, or screenshot was retained.
  The committed redacted proof is
  `evidence/issue-9-sentry-m3-retrieval-proof.json`; the retained mechanically
  sanitized response subset is
  `evidence/issue-9-sentry-m3-api-response-sanitized.json`.
- `GT-UF09-001` passed in the real `GuideCompanion` app at tested commit
  `79cd0d216f1f09913d2531b16a69c26b2cfbac63` through the bounded
  ambient shortcut lane on 2026-09-05. The test closed Settings, never opened
  the transcript inspector or another app, drove the installed
  `GlobalShortcutCallbacks`, and asserted stale evidence, fresh advancement,
  and completion. Every nonempty instruction had exact AX content and an
  expanded ambient frame (at least 300 points wide and taller than the 46-point
  icon-only state). The retained local bundle is
  `evidence/issue-13-real-app-UF09-ambient-run11.xcresult` (generated and
  ignored); the committed redacted machine-readable proof is
  `evidence/issue-13-real-app-UF09-ambient-run11-proof.json` (one passed, zero
  failed, with device identifiers removed). The result contains four named
  1040×194 screenshots cropped to the `guide.ambient` element: Step 1, stale
  refusal, Step 2, and Done. Process, XCTest-session, wrapper-root, and Launch
  Services cleanup passed. No private-desktop video or frame was committed.

## Deliberately red evidence

- With `SERPY_INJECT_GUIDE_FAILURE=1`, the bounded runner executed the normal
  `GT-UF08-001` journey against the real `GuideCompanion` app on the M3 and the
  `GuideCompanionGolden` plan reported one executed, one failed, zero passed,
  and zero skipped. The test timed out after the injected adapter prevented the
  expected ambient answer from appearing; the retained sanitized failure list
  records the first failed assertion and the timeout without the private AX
  tree. This proves an external deterministic Guide adapter failure makes the
  actual-app lane red rather than being swallowed. The local bundle
  is `evidence/issue-13-real-app-UF08-injected-red-m3.xcresult` (generated and
  ignored); the committed redacted summary is
  `evidence/issue-13-real-app-UF08-injected-red-m3-proof.json`, and the retained
  sanitized `xcresulttool` subset is
  `evidence/issue-13-real-app-UF08-injected-red-m3-xcresult-sanitized.json`.
  The post-run
  checks covered serpy/XCUI processes and wrapper-owned roots only; both were
  absent.

- The first M3 focused UF-12 attempt is retained locally at
  `evidence/issue-13-real-app-UF12-m3-run1.xcresult` (generated and ignored).
  Xcode executed zero tests because this Mac has no Mac Development certificate
  for team `847HR8U8D9`; both the app and UI-test targets failed signing before
  launch. The bounded wrapper still removed its build root and XCTest session,
  and no serpy process survived. At the time, Xcode Settings also had no Apple
  Account configured. The owner subsequently signed in and automatic
  provisioning made the Debug/XCUI build launchable.
- The second M3 focused UF-12 attempt is retained locally at
  `evidence/issue-13-real-app-UF12-m3-run2.xcresult` (generated and ignored).
  The signed app and UI runner launched, but macOS timed out while enabling
  automation mode before the test body. During failure cleanup, XCTest removed
  its runner-container temporary root while the wrapper had entered that root
  to canonicalize it, stranding the cleanup shell in `getcwd`. The run was
  interrupted after the exact stuck process was sampled; its owned 3.5 GiB
  build root and all serpy/XCUI processes were removed. Cleanup now canonicalizes
  candidate roots without changing directory, with a regression guard in the
  adversarial runner test.
- `GT-UF09-001` was executed once through the focused local Xcode/XCUI lane on
  2026-09-04. It failed after 60 seconds because the golden host did not acquire
  a process ID. The actual local result bundle is
  `evidence/issue-13-local-UF09.xcresult` (generated, ignored, not committed).
  The curated Xcode report screenshot is
  `evidence/issue-13-local-UF09-xcode-report.png`.
- The earlier real-app UF-09 attempt is retained at
  `evidence/issue-13-real-app-UF09.xcresult` (generated and ignored). XCTest
  connected the runner, then macOS canceled LocalAuthentication while enabling
  UI automation. No test method or app fixture executed. The owner must approve
  that OS authentication on the next explicitly announced run.
- The owner-approved real-app attempt is retained at
  `evidence/issue-13-real-app-UF09-approved.xcresult` (generated and ignored).
  It did not fail LocalAuthentication: the real app launched as PID 99241 and
  then crashed in `UITestSessionRootPolicy.validate` because XCTest and the app
  had different process-specific temporary directories. XCTest timed out after
  one minute before any flow assertion. The cross-process root contract is now
  headlessly regression-tested; executed UI proof remains red until a new
  explicitly authorized run.
- The second owner-approved real-app attempt is retained at
  `evidence/issue-13-real-app-UF09-run2.xcresult` (generated and ignored). It
  executed one test and failed immediately with `invalidIdentity` before app
  launch because the local wrapper supplied its two authorization values to
  `xcodebuild`, not to the XCTest runner. The wrapper now uses Apple's required
  `TEST_RUNNER_` prefix, while XCTest continues to forward the validated
  session values explicitly to the app. The same run exposed a separate zsh
  top-level nonzero-exit path that skipped the EXIT trap and retained its build
  root; the adversarial runner test now exercises that exact path with a deep,
  3.5 GiB sparse build tree and requires synchronous cleanup before exit.
- The third owner-approved real-app attempt is retained at
  `evidence/issue-13-real-app-UF09-run3.xcresult` (generated and ignored). It
  executed one test and failed immediately before app launch with Cocoa 513 /
  POSIX `EPERM`: the sandboxed XCTest runner received the authorization token
  but could not create its session inside the wrapper-owned `/private/tmp`
  build root. The wrapper now owns only build/source scratch. XCTest creates a
  separately tokened session beneath its own writable canonical temporary
  directory and forwards the exact paths and tokens to the app. App validation
  accepts only the current Darwin user temporary directory or the exact serpy
  XCTest runner container temporary directory; spoofed and symlinked paths
  remain rejected.
- The fourth owner-approved real-app attempt is retained at
  `evidence/issue-13-real-app-UF09-run4.xcresult` (generated and ignored). The
  real app launched, the test method ran, every Talk/Finish action progressed,
  and cleanup passed. Local-only AX/video inspection showed the transcript
  visibly advancing through the combined answer, `Open the File menu.`, and
  `Choose New Window.`. The failures were assertion-only: the combined SwiftUI
  row exposed label `SERPy` and no accessibility value, while the test waited
  for message text in `value`. The row now exposes its visible content as its
  accessibility label and the test selects the latest matching transcript row;
  speaker identity remains separate accessibility metadata. The exported video
  and frames contained existing Chrome content and were deleted without being
  committed.
- The fifth owner-approved real-app attempt at
  `evidence/issue-13-real-app-UF09-run5.xcresult` is mechanically green (one
  passed, zero failed, cleanup passed) but rejected as product proof. It drove
  the optional Voice Transcript inspector, while HeyClicky parity requires the
  shortcut-invoked, nonactivating ambient Guide with no conventional Guide work
  window. The golden Guide tests now drive the real `GlobalShortcutCallbacks`
  through token-owned signals and assert only the ambient panel lifecycle. The
  screenshot `evidence/issue-13-real-app-UF09-run5-xcode-report.png` is retained
  only as a labeled record of this rejected proof and its runtime warning; it
  must not be cited as golden acceptance. Later activity-tree inspection in the
  valid ambient run placed the same warning beneath XCTest's discovered
  interrupting Superwhisper window, alongside an existing Chrome window—not
  beneath serpy launch or session provisioning. The harness does not close or
  control either external app. Session provisioning remains off the main actor.
- Ambient runs 6–9 are retained locally as red-capable evidence. Run 6 exposed
  the real icon-only bug: a target without display metadata made panel layout
  return before resizing. Run 7 proved the response card was visibly expanded
  after target-frame display fallback, while AX value remained empty. Run 8
  proved the controller-owned hosting-view AX value worked and exposed captured
  context; its test still expected the obsolete empty value. Run 9 passed exact
  response values and width but rejected a valid 54-point card using an
  arbitrary 58-point height threshold. Run 10 uses the product invariant:
  response cards must exceed the 46-point icon state in both dimensions. All
  private-desktop diagnostic exports for runs 6–9 were removed.
- A Developer ID signed build 43 was notarized successfully before the
  fail-open combined-runner defect was found. That candidate is rejected and
  must not be installed or cited: its DMG, checksum, manifest, staging output,
  and Release derived data are removed before rebuilding from the reviewed fix.
- Build 43 was rebuilt from exact commit
  `15d7056b24f46c25e3be43cb086b1c2a065180c3`, notarized and stapled under
  submission `881f81b2-945f-4124-8b6e-6c60b7d6b65e`, and installed at
  `/Applications/SERPy.app`. The DMG SHA-256 is
  `39d0bf3e75758e25e51bf127dcf6e7e4f5974353f8a2bd11ef6037fa0b7e0c17`;
  the installed executable matches the reviewed Release executable at
  `b869bfdc5ecfd038cc2b7fe8c822d12b9d68c5a23f1506475a271725fe58414c`.
  Gatekeeper accepted both the DMG and mounted app, and the installed app
  launched. This proves artifact identity and launch only; installed product
  flows remain red. The machine-readable record is
  `evidence/issue-13-build-43-m3-install-proof.json`.
- `golden-ui-tests` is connected to the GitHub repository and configured with
  one required macOS Test action, the `GuideCompanion` scheme, the
  `GuideCompanionGolden` plan, and one Mac destination. Manual run 1
  (`a00efbc1-d67b-4f1b-8b02-036f91063ae4`) built the test products at exact
  commit `15d7056b24f46c25e3be43cb086b1c2a065180c3`, then failed before loading
  the test bundle because Xcode Cloud's execution host and embedded bundle had
  different Team IDs while the non-shipping runner inherited production
  Hardened Runtime library validation. The runner now disables Hardened Runtime
  only for `GuideCompanionUITests`; Release `SERPy.app` remains hardened. The
  burn-in stays 0/10 until the corrected cloud run completes.
- The ten-run isolated burn-in is 0/10 and the check must not be required.
- Every installed evidence cell in `docs/product/user-flows.md` remains red
  until one exact reviewed artifact is exercised in the installed lane.
