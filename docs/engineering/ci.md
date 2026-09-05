# Continuous integration and test operation

This is the operator guide for running serpy tests and understanding what each
result proves. The canonical user outcomes remain in
`docs/product/user-flows.md`; this document explains the runners.

## Current status

| Check | Runner | Trigger | Current state |
| --- | --- | --- | --- |
| `evidence-honesty` | GitHub Actions macOS runner | Pull request, merge queue, push to `main` | New integration check; validates only tracked focused real-app XCUI proof contracts and the separate red overall gate |
| `core-tests` | GitHub Actions macOS runner | Pull request, merge queue, push to `main` | Green for exact base `1901f81a0b0504821801fa98634e017fba9bf114` in run `33938651169` |
| `app-build` | GitHub Actions macOS runner | Pull request, merge queue, push to `main` | Green for exact base `1901f81a0b0504821801fa98634e017fba9bf114` in run `33938651169` |
| Focused golden XCUI | Local Xcode/XCTest | Explicitly selected test | **Partial/secondary:** summaries record real-app UF-09 and UF-12 passes, but retained primary bundles/report screenshots and some cleanup dimensions are unavailable |
| `golden-ui-tests` | Xcode Cloud temporary macOS environment | Manual during burn-in; pull request after acceptance | Configured; run 8 passed the one-test launch diagnostic, not the complete plan; burn-in is 0/10 |
| Installed acceptance | Exact signed/notarized app on the owner's Mac | Explicit named acceptance session | Build 43 identity, notarization, installation, launch, and permission recovery recorded; product-flow acceptance remains red |

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
The next diagnostic should narrow the launch reproduction rather than repeat
the full suite unchanged. The underlying app versus XCTest activation cause
is still unproven.

`GuideCompanionLaunchDiagnostic.xctestplan` is a temporary diagnosis-only
selection of the first failing UF-03 test with identical runtime options and
timeouts. The default full golden plan is unchanged. Diagnostic runs never
count toward the ten-run acceptance burn-in. Select this plan only for a named
cloud diagnostic, then restore the workflow to `GuideCompanionGolden`.

Runs 1–3 retained the bundle-loading and cloud-identity failures that led to
the UI-test-only Hardened Runtime correction and exact project-filename check.
Run 4 loaded the suite and executed 18 tests (3 passed, 15 failed). Runs 5–6
then reproduced a shared launch-boundary timeout. Diagnostic run 7 proved that
launch completed and exposed a transient success-message assertion. Diagnostic
run 8 passed that one corrected UF-03 journey at `096af3b`; it does not execute
the complete golden plan and does not count toward burn-in. Full-plan run 9 at
exact commit `1901f81a0b0504821801fa98634e017fba9bf114` returned to 18
one-minute application-launch timeouts before flow assertions, despite the same
UF-03 journey passing in focused run 8. Run 9 is red and the underlying app
startup versus XCTest activation cause remains unproven. Commit `29baaed` adds
bounded DEBUG-only fixed-name launch-stage receipts in the owned test session
and XCTest probes at 5, 15, and 30 seconds. Full-plan run 10 at exact commit
`29baaedbea835d8939bcf2a6177309924dd798b9` failed because the temporary
diagnostic `DispatchWorkItem` inherited MainActor isolation and trapped on its
background queue before logging any receipts. This proves the probe defect,
not the original app-startup cause. The current branch replaces it with a
runtime-covered detached scheduler; that correction has no cloud result yet.
The heterogeneous run records remain under
`evidence/issue-13-xcode-cloud-run*-proof.json`; the focused real-app XCUI
evidence-honesty linter does not validate those external records. Burn-in
remains 0/10.

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
scripts/run-headless-check.sh evidence-contract
scripts/test-headless-check.sh
scripts/run-headless-check.sh core-tests
scripts/run-headless-check.sh app-build
```

The first command runs only the bounded focused real-app XCUI evidence-honesty
linter and separate overall red gate. It does not validate heterogeneous Xcode
Cloud or installed-build records and cannot prove completion. The second
command deliberately injects individual and combined-phase failures
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
transcript-window design. The committed summary for the run at `79cd0d2`
records `GT-UF09-001` through the ambient shortcut path with stale/fresh
progression and completion assertions. Its primary `.xcresult`, Xcode report
screenshot, destination, and unmeasured cleanup dimensions are unavailable,
so this is partial secondary evidence; see
`evidence/issue-13-golden-flow-harness.md`.

## GitHub Actions

`.github/workflows/verification.yml` defines three secret-free, read-only jobs:

- `evidence-honesty (focused real-app XCUI; cannot prove completion)`: uses the
  bounded `evidence-contract` lane to test the linter, auto-discover every
  tracked `issue-13-real-app-*-proof.json`, correlate its commit/test method/test
  plan, check referenced artifact shape, and enforce the exact current red
  overall gate. A green result means only that these focused proof contracts
  are honestly labeled red or partial. It does not validate the heterogeneous
  Xcode Cloud/install records, authenticate artifacts, approve a proof as
  complete, or imply that a UI journey passed.

- `core-tests`: runs the safety scripts with a system-only macOS `PATH`,
  adversarially tests the runner, then runs the complete package suite and
  App-owned composition contract.
- `app-build`: compiles the production app and golden UI bundle without launch.

Workflow actions are pinned to reviewed full commit SHAs. The checkout pin is
official `actions/checkout` v7.0.1, which uses the Node 24 action runtime.

The workflow runs for pull requests, merge queue candidates, and pushes to
`main`. For PR #14 at exact base
`1901f81a0b0504821801fa98634e017fba9bf114`, `core-tests` and `app-build`
both passed in
[GitHub Actions run 33938651169](https://github.com/serpcompany/serpy-clicky-mac-app/actions/runs/33938651169).
That run predates the new evidence-honesty job; the integration branch requires
its own exact-head CI result after push.
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
