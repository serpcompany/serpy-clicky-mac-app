# Issue 13 golden-flow harness evidence

Date: 2026-09-04

Base: `9427f18e80120583fe815bbd1c701b5c09367fe5`

## Safety design

- The production app is not the XCUI test host.
- `GuideCompanionGoldenHost` imports only `GuideTestSupport`, whose sole
  dependency is `GuideCore`, and has a distinct test-only bundle identifier.
- The fixture driver delegates permission, lifecycle, Dictation phase,
  walkthrough progression, Talk authorization, and diagnostic classification
  decisions to the production `GuideCore` policies/state machines. It does not
  carry a second copy of those decisions.
- `AppRuntimeMode.uiTest` admits only deterministic fixtures and ephemeral
  storage; microphone, permission requests, Screen Recording, production
  Keychain, persistent user data, Sentry transport, network providers, and
  global shortcuts are forbidden.
- Local verification uses only `swift test`, unsigned `xcodebuild build`, and
  unsigned `xcodebuild build-for-testing`. It never runs XCUI.
- Xcode's temporary build products are explicitly unregistered from Launch
  Services before their one owned run root is removed.

## Red-capable evidence

- `GoldenRuntimeCompositionTests` failed to compile before the runtime
  capability contract existed.
- `GoldenUserFlowHarnessTests` failed to compile before the observable flow
  fixture existed.
- Injected `core-tests` and `app-build` failures each exit 86. The self-test
  proves the owned temporary root is removed after either failure.
- The runner self-test rejects a traversal-shaped override, forces a
  TERM-ignoring descendant through bounded TERM-to-KILL escalation, interrupts
  a live owned group, and proves no descendant or run directory survives.

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
