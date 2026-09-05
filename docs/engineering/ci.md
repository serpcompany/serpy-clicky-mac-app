# Continuous integration and test operation

This is the operator guide for running serpy tests and understanding what each
result proves. The canonical user outcomes remain in
`docs/product/user-flows.md`; this document explains the runners.

## Current status

| Check | Runner | Trigger | Current state |
| --- | --- | --- | --- |
| `core-tests` | GitHub Actions macOS runner | Pull request, merge queue, push to `main` | Green for `fb33621` in run `33943616152`, including both runner safety suites |
| `app-build` | GitHub Actions macOS runner | Pull request, merge queue, push to `main` | Green for `fb33621` in run `33943616152` |
| Focused golden XCUI | Local Xcode/XCTest | Explicitly selected test | Valid ambient `GT-UF09-001` passed against the real app at `79cd0d2`; cleanup passed |
| `golden-ui-tests` | Xcode Cloud temporary macOS environment | Manual during burn-in; pull request after acceptance | Run 13 again timed out during launch in all 18 tests; launch remains unresolved; burn-in is 0/10 |
| Installed acceptance | Exact signed/notarized app on the owner's Mac | Explicit named acceptance session | Manual evidence only |

Run 4 executed 18 tests (3 passed, 15 failed). Native-control selectors and
fixture timing were corrected in `b8153b7`. Run 5 then reported 18 timeouts;
its first failure was inside `application.launch`, with the app remaining
`Running Background`, before flow assertions. This is not evidence that the
selector corrections passed or failed. The sanitized result is retained in
`evidence/issue-13-xcode-cloud-run5-red-proof.json`.

Run 6 (`99fcbeee-f0e4-41d1-a0c1-e88906a9ffda`) retried the exact same source
without changing timeouts or production code. It finished FAILED with 18
one-minute timeouts; the first test again stopped inside application launch
before flow assertions. See `evidence/issue-13-xcode-cloud-run6-red-proof.json`.
The focused UF-03 diagnostic subsequently passed in run 8, but full run 9
again timed out during launch. Run 11's temporary startup receipts showed app
initialization completed while XCTest still reported `Running Background`.
The runner now yields activation to the product before launch. With that
experiment, run 12 reached flow assertions in all 18 tests. This is useful
evidence, not yet proof that cloud launch is stable.

Run 12's remaining failures identified an ambiguous Settings menu selector,
numeric radio-control values, and Guide remaining in its thinking presentation
while speaking a structured step. Selector corrections are in `3fc2bdc`.
The production speech-order correction in `1dccc86` has a red-to-green Swift
Testing regression: the step must be presented before speech starts and spoken
exactly once. Temporary startup instrumentation was removed. See
`evidence/issue-13-xcode-cloud-run12-flow-proof.json`.

Full run 13 (`dab4658d-f470-4e84-bf24-622bb6f9346a`) tested `1dccc86`
and failed with 18 launch timeouts. Its first test again reported
`Running Background` inside `application.launch`. The activation handoff alone
is therefore insufficient, and the flow corrections remain unvalidated in
the full UI lane. See `evidence/issue-13-xcode-cloud-run13-red-proof.json`.
Focused run 14 tested deferred Settings presentation and failed at the same
launch boundary; that timing change was removed. Run 15 then used the current
`NSApplication.activate()` call and passed UF-03 with zero failures or skips,
including teardown. See
`evidence/issue-13-xcode-cloud-run15-focused-green-proof.json`. Full run 16
(`9cf37d97-17c0-47d7-b2a5-222f86b30a77`) tests that exact same `fb33621`
source. One focused success is not proof of stable full-suite launch.
Neither cloud fixtures nor headless success satisfy installed
microphone, insertion, focus, audible speech, or permission acceptance.

`GuideCompanionLaunchDiagnostic.xctestplan` is a temporary diagnosis-only
selection of the first failing UF-03 test with identical runtime options and
timeouts. The default full golden plan is unchanged. Diagnostic runs never
count toward the ten-run acceptance burn-in. Select this plan only for a named
cloud diagnostic, then restore the workflow to `GuideCompanionGolden`.

## What developers run

### While coding

Use Xcode's Test navigator to run one Swift Testing/XCTest test or suite, or run:

```sh
scripts/run-headless-check.sh core-tests
```

This does not launch an app. The runner owns one temporary directory, enforces
30-minute and 8-GiB limits, terminates its process group, and removes the
directory afterward.

### Before opening a pull request

Run:

```sh
scripts/test-headless-check.sh
scripts/run-headless-check.sh core-tests
scripts/run-headless-check.sh app-build
```

The first command deliberately injects individual and combined-phase failures
and proves fail-closed sequencing, path rejection, timeout, interruption,
descendant termination, and cleanup. `app-build` compiles the production app
and golden UI test bundle without executing them.

### Debugging one UI journey locally

Use the bounded runner with one exact test identifier and a new result path:

```sh
scripts/run-golden-ui-test.sh focused \
  GuideCompanionUITests/GoldenGuideUITests/test_GT_UF09_001_walkthroughRequiresFreshEvidenceForEachStep \
  evidence/issue-13-real-app-UF09-green.xcresult
```

A focused local XCUI run briefly takes foreground control. It launches the real app in
side-effect-incapable UI-test mode; it must not open another application.

Save an `.xcresult` for every claimed run. A compile-only result is not a test
result. After execution, confirm serpy and the XCTest runner terminated
and the temporary build directory was removed.

`scripts/test-golden-ui-runner.sh` exercises timeout, TERM-to-KILL process-group
cleanup, result isolation, temporary-root removal, and an approved XCTest root
that disappears before cleanup without launching an app.

The first local execution of `GT-UF09-001` on 2026-09-04 is retained as evidence
that the now-rejected standalone host failed to acquire a process ID. It does
not count as serpy evidence. The first real-app execution on 2026-09-05 stopped
before the test method because macOS canceled XCTest automation-mode biometric
authentication. Later runs corrected the session boundary and the rejected
transcript-window design. The valid run at `79cd0d2` executes `GT-UF09-001`
through the ambient shortcut path, passes stale/fresh progression and
completion assertions, and retains its local `.xcresult` plus committed
redacted proof as documented in `evidence/issue-13-golden-flow-harness.md`.

## GitHub Actions

`.github/workflows/verification.yml` defines two secret-free, read-only jobs:

- `core-tests`: runs the safety scripts with a system-only macOS `PATH`,
  adversarially tests both bounded runners without launching an app, then runs the complete package suite and
  App-owned composition contract.
- `app-build`: compiles the production app and golden UI bundle without launch.

Workflow actions are pinned to reviewed full commit SHAs. The checkout pin is
official `actions/checkout` v7.0.1, which uses the Node 24 action runtime.

The workflow runs for pull requests, merge queue candidates, and pushes to
`main`. For PR #14 at `15d7056`, both jobs passed in
[GitHub Actions run 33930252682](https://github.com/serpcompany/serpy-clicky-mac-app/actions/runs/33930252682).
Use stable job names when configuring required branch checks.

## Xcode Cloud account requirements

There is no separate Xcode Cloud account. Xcode Cloud uses the team's Apple
Developer Program and App Store Connect access.

The operator needs:

- Xcode 15 or later;
- an Apple Account added in Xcode Settings;
- active Apple Developer Program membership;
- an App Store Connect app record, or permission to create one; and
- Account Holder, Admin, App Manager, or an appropriately permitted Developer
  role to configure the workflow.

Apple Developer Program membership includes 25 Xcode Cloud compute hours per
month. Additional hours are optional paid capacity.

Primary references:

- https://developer.apple.com/xcode-cloud/get-started/
- https://developer.apple.com/documentation/xcode/setting-up-your-project-to-use-xcode-cloud
- https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow
- https://developer.apple.com/documentation/xcode/configuring-your-xcode-cloud-workflow-s-actions

## One-time Xcode Cloud setup

1. Open `GuideCompanion.xcodeproj` in Xcode while signed into the correct Apple
   Developer team.
2. Start Xcode Cloud configuration and connect the GitHub repository when Xcode
   requests source access.
3. Select `GuideCompanion` as the product/scheme.
4. Create a workflow named `golden-ui-tests`.
5. Add one macOS Test action using the `GuideCompanionGolden` test plan.
6. Use one macOS destination and sequential test execution.
7. Supply no secrets or production environment values.
8. Keep the test action required inside the workflow (Apple requires at least
   one required action), but do not make the Xcode Cloud check a required
   branch-protection check during burn-in; start each burn-in run manually.
9. Inspect the Xcode Cloud result bundle and failure attachments after each run.
10. After ten consecutive clean runs, enable the pull-request trigger and make
    the check required. Reset the burn-in count after a flaky, unsafe, or
    unexplained failure.

Xcode Cloud builds test products with `build-for-testing`, then runs them with
`test-without-building` in a temporary environment. The completed test action
publishes its result bundle in Xcode and App Store Connect.

## Automation decision

Yes, the project needs CI automation, but not a Codex scheduled task:

- GitHub Actions automatically runs headless checks on pull requests and
  `main`.
- Xcode Cloud automatically runs the full golden UI plan after its one-time
  workflow setup.
- Installed acceptance remains deliberately manual because it uses real
  macOS permissions, microphone, focus, clipboard, Chrome, and audible speech.

Do not use a recurring Codex automation as a substitute for either CI system.
