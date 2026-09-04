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
- Injected `core-tests` and `app-build` failures each exit 86. The self-test
  proves the owned temporary root is removed after either failure.
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
| `scripts/run-headless-check.sh core-tests` | Green after sandbox-safe local/Xcode Cloud provisioning, shortcut callback-driver coverage, ambient failure recovery mapping, and Dictation partial mapping; 100 XCTest, 85 Swift Testing cases, and 4 App composition contract tests passed | none | Green |

## Deliberately red evidence

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
  must not be cited as golden acceptance. The warning was attributed to the
  UI-test target before interaction while synchronous session provisioning ran
  on the test's main actor. Provisioning now runs in a detached task; removal of
  that warning remains pending the next authorized ambient execution.
- `golden-ui-tests` has not run in Xcode Cloud. Xcode Cloud must be connected
  and execute the complete dedicated scheme/test plan.
- The ten-run isolated burn-in is 0/10 and the check must not be required.
- Every installed evidence cell in `docs/product/user-flows.md` remains red
  until one exact reviewed artifact is exercised in the installed lane.
