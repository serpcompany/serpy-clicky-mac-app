# Issue 13 golden-flow harness evidence

Date: 2026-09-04

Base: `9427f18e80120583fe815bbd1c701b5c09367fe5`

## Safety design

- The production app is not the XCUI test host.
- `GuideCompanionGoldenHost` imports only `GuideTestSupport`, whose sole
  dependency is `GuideCore`, and has a distinct test-only bundle identifier.
- `AppRuntimeMode.uiTest` admits only deterministic fixtures and ephemeral
  storage; microphone, permission requests, Screen Recording, production
  Keychain, persistent user data, Sentry transport, network providers, and
  global shortcuts are forbidden.
- Local verification uses only `swift test`, unsigned `xcodebuild build`, and
  unsigned `xcodebuild build-for-testing`. It never runs XCUI.

## Red-capable evidence

- `GoldenRuntimeCompositionTests` failed to compile before the runtime
  capability contract existed.
- `GoldenUserFlowHarnessTests` failed to compile before the observable flow
  fixture existed.
- `SERPY_INJECT_FAILURE=core-tests` exits 86. The self-test proves the owned
  temporary root is removed on that failure.

## Local results

| Check | Result | Output retention | Cleanup |
| --- | --- | --- | --- |
| `scripts/test-headless-check.sh` | Green | none | Green |
| `scripts/run-headless-check.sh app-build` | Green; production app and golden XCUI bundle compiled only | none | Green |
| `scripts/run-headless-check.sh core-tests` | Green; complete package suite passed | none | Green |

## Deliberately red evidence

- `golden-ui-tests` has not run. Xcode Cloud must be connected by the owner and
  execute the dedicated scheme/test plan; local XCUI substitution is forbidden.
- The ten-run isolated burn-in is 0/10 and the check must not be required.
- Every installed evidence cell in `docs/product/user-flows.md` remains red
  until one exact reviewed artifact is exercised in the installed lane.
