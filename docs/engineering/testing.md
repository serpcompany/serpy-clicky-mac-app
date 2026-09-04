# Testing and verification

Use the smallest test that can detect the behavior under change. The default
agent loop is headless; it never launches serpy.

## Test layers

| Layer | Purpose | Runner |
| --- | --- | --- |
| Unit | Pure policies, state machines, parsing, layout, sanitization | Swift Testing by default; existing XCTest may remain |
| Direct integration | Multiple real modules behind controlled platform adapters | Swift Testing by default; existing XCTest may remain |
| UI | A few critical window and interaction journeys | Focused opt-in XCUI in Xcode; full suite in Xcode Cloud |
| Installed | macOS-owned and human-observed behavior | Exact signed/notarized artifact on the owner's Mac |

`swift test` is the SwiftPM command used for package tests; it can run both
Swift Testing and XCTest suites. Swift Testing does not replace XCTest/XCUI for
UI automation.

## Regression rule

For each reproduced bug:

1. Reproduce it at a public behavior seam.
2. Add one failing test at the lowest honest layer.
3. Make the smallest functional correction.
4. Run the focused test, then the affected headless suite.
5. Run a broader or installed check only when the changed boundary requires it.

Do not snapshot or lock unfinished styling. Lock the state transition,
interaction, data boundary, geometry invariant, or user outcome that failed.

## Safe execution lanes

### Local agent lane

The local lane may run package tests and compile the app. It does not launch an
app, run the UI-test target, request permissions, access the production
Keychain item, initialize Sentry, call OpenAI, install an app, or write build
products inside the repository.

Each future harness invocation must own one unique directory below the operating
system temporary directory, impose time and disk limits, and remove that
directory on success, failure, or interruption. Use
`scripts/run-headless-check.sh core-tests` for the package suite and
the App-owned composition contract, and `scripts/run-headless-check.sh
app-build` for unsigned production-app and golden-UI-bundle compilation.
`scripts/test-headless-check.sh` deliberately
injects failures, rejects traversal-shaped roots, interrupts a run, and proves
that TERM-ignoring descendants are killed and the owned directory is removed.
Each command owns a new process group with a 30-minute wall limit and an 8 GiB
disk limit. Neither command launches an application.

### Focused local UI lane

A developer or agent may run one explicitly named golden XCUI test locally
when the owner requests that exact run. The only supported entrypoint is
`scripts/run-golden-ui-test.sh focused`, which selects the production
`GuideCompanion` scheme and `GuideCompanionGolden.xctestplan` and saves an
`.xcresult`. Do not invoke this lane directly through Xcode or raw `xcodebuild`,
because that bypasses its bounds and cleanup. The run may briefly take
foreground control.

Its adversarial no-app self-test is `scripts/test-golden-ui-runner.sh`.
The bounded runner owns one canonical `serpy-local-xcui.*` directory directly
under `/private/tmp`. XCTest and the app share that exact parent using separate
run and session owner tokens; neither process may substitute its own `TMPDIR`.
For local `xcodebuild`, the wrapper passes the parent and run token with the
`TEST_RUNNER_` prefix so Xcode strips that prefix and exposes the original
names inside the XCTest runner. The test then explicitly forwards the session
variables to the application launch environment. See Apple's
[environment-variable reference](https://developer.apple.com/documentation/xcode/environment-variable-reference).
Invalid startup configuration exits immediately with an explicit error.
When the bounded variables are absent, parent creation is permitted only when
Apple's predefined environment identifies `CI_XCODE_CLOUD=TRUE`, the
`golden-ui-tests` workflow, the `GuideCompanion` project and scheme, and a
`test-without-building` action with a nonempty build ID. XCTest then owns and
removes the exact `/private/tmp` parent. Missing or mismatched cloud identity
fails before app launch.

This lane launches the real serpy application target in `--ui-testing` mode.
It must not open TextEdit, Chrome, System Settings, or another external app; access real
permissions, Keychain, Sentry, OpenAI, microphone, or persistent user data; or
leave an app, runner, registration, scratch directory, or build cache behind.
Run one selected test at a time and prove teardown before another run. The full
golden suite remains an isolated Xcode Cloud responsibility.

### Isolated UI lane

XCTest/XCUI runs in a temporary Xcode Cloud macOS test environment. UI-test
runtime mode is resolved before production dependencies are constructed and
uses in-memory credentials, deterministic permissions, local fixtures,
ephemeral storage, an ephemeral receipt-only diagnostic reporter, and no
network provider.

Each test registers teardown before launch, launches one application instance,
uses bounded state-based waits, terminates the application, and proves it
reached the not-running state. An orphan, unexpected Keychain/permission dialog,
second app instance, or resource-budget breach fails the run without retry.

The isolated lane uses the production `GuideCompanion` target and
`GuideCompanionGolden.xctestplan`. Runtime mode is resolved before app
composition. UI-test mode keeps the real lifecycle, `GuideAppModel`, GuideUI,
routing, and coordinators while injecting deterministic implementations only
at external adapter protocols. The scheme is compiled locally with `build-for-testing`;
one explicitly requested test may execute through the focused local UI lane.
The complete plan runs in an Xcode Cloud workflow named `golden-ui-tests`.
Configure that workflow for sequential macOS tests, failure-only diagnostics,
no environment secrets, and no successful screen captures. Make the check
required only after ten consecutive clean runs with zero prompt, process,
network, Keychain, or disk violations.

The test plan owns the common `--ui-testing` argument. Individual test methods
select a named external fixture; product state still advances only through real
app actions and coordinators.

### Installed lane

The installed lane runs only for a named acceptance workflow against one exact
reviewed artifact. It owns macOS permission, microphone, cross-app insertion,
focus, audible speech, Keychain, signing, notarization, Gatekeeper, and
click-through evidence. It uses the stable product bundle and signing identity.

## Telemetry during tests

Automated tests do not start Sentry or transmit diagnostics. Sentry contracts
use sanitized synthetic events and an in-memory transport. A real development
transport smoke test requires an explicit named task and is not part of routine
verification.

## Stop conditions

Stop immediately when a run creates an unexpected app instance, system prompt,
production-data access, network request, orphan process, or unbounded build
directory. Diagnose that violation before another UI attempt. Never change the
bundle or signing identity as a retry strategy.
