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
  TERM-to-KILL escalation, interrupts a live owned group, and proves no
  descendant or run directory survives.
- UI session-root tests reject matching-name roots outside the canonical system
  temporary directory and symlinked parents. Both the parent and direct-child
  root require a UUID-matched owner token.
- The actual UI-test model audit is derived from the concrete constructed
  adapter types. It asserts the exact deterministic type set and rejects any
  production Keychain, Sentry, microphone, TCC, network, global-shortcut, or
  persistent-data adapter.
- The Last Dictation fixture persists into the session's ephemeral JSON store;
  its relaunch test removes the seed argument and proves restoration from that
  store.

## Local results

| Check | Result | Output retention | Cleanup |
| --- | --- | --- | --- |
| `scripts/test-headless-check.sh` | Green | none | Green |
| `scripts/test-golden-ui-runner.sh` | Green; adversarial process fixtures only, no app launch | none | Green |
| `scripts/run-headless-check.sh app-build` | Green after real-app retarget; production app and XCUI bundle compiled only | none | Green |
| `scripts/run-headless-check.sh core-tests` | Green after real-app retarget; complete package suite passed | none | Green |

## Deliberately red evidence

- `GT-UF09-001` was executed once through the focused local Xcode/XCUI lane on
  2026-09-04. It failed after 60 seconds because the golden host did not acquire
  a process ID. The actual local result bundle is
  `evidence/issue-13-local-UF09.xcresult` (generated, ignored, not committed).
  The curated Xcode report screenshot is
  `evidence/issue-13-local-UF09-xcode-report.png`.
- The first real-app UF-09 attempt is retained at
  `evidence/issue-13-real-app-UF09.xcresult` (generated and ignored). XCTest
  connected the runner, then macOS canceled LocalAuthentication while enabling
  UI automation. No test method or app fixture executed. The owner must approve
  that OS authentication on the next explicitly announced run.
- `golden-ui-tests` has not run in Xcode Cloud. Xcode Cloud must be connected
  and execute the complete dedicated scheme/test plan.
- The ten-run isolated burn-in is 0/10 and the check must not be required.
- Every installed evidence cell in `docs/product/user-flows.md` remains red
  until one exact reviewed artifact is exercised in the installed lane.
