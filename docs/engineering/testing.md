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
`scripts/run-headless-check.sh all` runs those lanes in order and removes the
completed core lane's owned SwiftPM, composition DerivedData, and cloned-package
directories before app-build. This keeps the same 8 GiB fail-closed disk bound
meaningful on machines where Sentry's binary artifacts expand differently.
`scripts/test-headless-check.sh` deliberately
injects failures, rejects traversal-shaped roots, interrupts a run, and proves
that TERM-ignoring descendants are killed, completed core products do not
survive into app-build, and the owned directory is removed.
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
Both serpy and XCUI must already be closed for that self-test. An occupied
lane exits before fixtures run; this is an unmet precondition, not a passing
timeout/cleanup test. The self-test never quits the owner's application.
The bounded wrapper owns one canonical `serpy-local-xcui.*` build/source scratch
directory directly under `/private/tmp`; the sandboxed XCTest runner never
writes inside it. XCTest creates and owns a separate `serpy-xctest-session.*`
directory in its own writable canonical temporary directory, with independent
run and session owner tokens. The app validates that exact base-parent-root
chain without substituting its process-specific `TMPDIR`.
If XCTest crashes, times out, or is interrupted before its teardown runs, the
outer wrapper searches only the current Darwin user temporary directory and
the two exact serpy XCTest container temporary directories for the
run-token-derived session name. It deletes the directory only after its owner
token matches, and treats a surviving or mismatched session as cleanup failure.
The wrapper canonicalizes those roots with `realpath` without entering them, so
XCTest removing a container temporary directory concurrently cannot strand the
cleanup shell while it resolves a now-deleted working directory.
Disk-budget sampling tolerates a transient package-extraction race by retrying
three times; persistent measurement failure terminates the owned group instead
of silently disabling the budget.
For local `xcodebuild`, the wrapper passes the authorization run token with the
`TEST_RUNNER_` prefix so Xcode strips that prefix and exposes the original name
inside the XCTest runner. The test then explicitly forwards the canonical
session paths and tokens to the application launch environment. See Apple's
[environment-variable reference](https://developer.apple.com/documentation/xcode/environment-variable-reference).
Invalid startup configuration exits immediately with an explicit error.
When the bounded token is absent, session creation is permitted only when
Apple's predefined environment identifies `CI_XCODE_CLOUD=TRUE`, the
`golden-ui-tests` workflow, the `GuideCompanion.xcodeproj` project and
`GuideCompanion` scheme, and a
`test-without-building` action with a nonempty build ID. XCTest then owns and
removes the exact XCTest-owned session. Missing or mismatched cloud identity
fails before app launch.

This lane launches the real serpy application target in `--ui-testing` mode.
Golden Guide tests close Settings and drive the real shortcut callbacks through
exact trigger files inside the token-owned XCTest session. The deterministic
monitor consumes those signals off the main thread; XCUI never calls model
methods, uses visible test controls, or opens the optional Voice Transcript
inspector as Guide parity evidence. Assertions target the nonactivating ambient
surface and its observable stage, context, response, progression, and
cancellation state.
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
