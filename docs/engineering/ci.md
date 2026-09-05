# Continuous integration and test operation

This is the operator guide for running serpy tests and understanding what each
result proves. The canonical user outcomes remain in
`docs/product/user-flows.md`; this document explains the runners.

## Current status

| Check | Runner | Trigger | Current state |
| --- | --- | --- | --- |
| `core-tests` | GitHub Actions macOS runner | Pull request, merge queue, push to `main` | Green for source `fb33621af95d9ee450e051436c536663935b7110` in run `33943616152`; current staging head is unverified in GitHub Actions |
| `app-build` | GitHub Actions macOS runner | Pull request, merge queue, push to `main` | Green for source `fb33621af95d9ee450e051436c536663935b7110` in run `33943616152`; current staging head is unverified in GitHub Actions |
| Focused golden XCUI | Local Xcode/XCTest | Explicitly selected test | **Partial/secondary:** the summary for ambient `GT-UF09-001` at `79cd0d2` records a pass, but the primary `.xcresult`, Xcode report screenshot, destination, and five cleanup dimensions are unavailable |
| `golden-ui-tests` | Xcode Cloud temporary macOS environment | Manual during burn-in; pull request after acceptance | Run 16 reached all 18 tests: 17 passed and UF-11 failed at its Talk disclosure selector; burn-in is 0/10 |
| Installed acceptance | Exact signed/notarized app on the owner's Mac | Explicit named acceptance session | Build 43 is recorded as the installed signed/notarized candidate; user-flow acceptance remains red |

Runs 1-7 established and narrowed cloud signing, project-identity, selector,
fixture-timing, and launch failures. Run 8 passed only the one-test
`GuideCompanionLaunchDiagnostic` plan; it does not count toward acceptance.
Run 9 returned to the complete `GuideCompanionGolden` plan and reproduced the
launch timeout. Run 10's temporary startup probe crashed before producing the
needed receipts. Run 11 proved app initialization and launch callbacks returned,
while XCTest foreground activation still failed. Run 12 executed the complete
plan: 11 tests passed and 7 failed at flow assertions. Its failures were
classified as Settings selector ambiguity, three UF-05 numeric radio-value
assertions, UF-08 Guide timing, UF-10 speaking timing, and UF-11 selector/cascade
failures. The current source removes temporary launch probes, corrects the
native selectors, and presents structured Guide steps before speech.

Full run 13 (`dab4658d-f470-4e84-bf24-622bb6f9346a`) tested `1dccc86`
and failed with 18 one-minute launch timeouts. Focused run 14 tested deferred
Settings presentation and failed at the same launch boundary; that timing
experiment was removed and synchronous presentation restored. Focused run 15
used the current `NSApplication.activate()` call and passed UF-03 with zero
failures or skips, including teardown. Full run 16
(`9cf37d97-17c0-47d7-b2a5-222f86b30a77`) tested the same `fb33621` source and
reached every flow: 17 passed and UF-11 failed because the test queried the
native Talk disclosure switch as a checkbox. The stronger throwing Switch
lookup is present in staging but has not yet been proven by Xcode Cloud. The
complete-plan gate remains red and burn-in remains 0/10.
Neither cloud fixtures nor headless success satisfy installed microphone,
insertion, focus, audible speech, permission, or click-through acceptance.

`GuideCompanionLaunchDiagnostic.xctestplan` is a temporary diagnosis-only
selection of the first failing UF-03 test with identical runtime options and
timeouts. The default full golden plan is unchanged. Diagnostic runs never
count toward the ten-run acceptance burn-in.

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

The second command, `scripts/test-headless-check.sh`, deliberately injects
individual and combined-phase failures and proves fail-closed sequencing, path
rejection, timeout, interruption, descendant termination, and cleanup. The
first command only runs the bounded evidence-honesty linter. `app-build`
compiles the production app and golden UI test bundle without executing them.

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
progression and completion assertions. Its ignored `.xcresult` is unavailable,
no Xcode report screenshot is committed, its destination was not recorded, and
five cleanup dimensions remain unverified. It is partial secondary evidence,
not complete proof; see `evidence/issue-13-golden-flow-harness.md`.

## GitHub Actions

`.github/workflows/verification.yml` defines three secret-free, read-only jobs:

- `evidence-honesty (cannot prove completion)`: uses the bounded
  `evidence-contract` lane to test the linter,
  discover every tracked focused real-app Issue 13 proof, correlate
  commits/test methods/plans,
  check referenced artifact shape, and enforce the exact current red overall
  gate. Its checkout includes history so each claimed tested commit must resolve
  locally. A green lint result means only that incomplete evidence is honestly
  labeled red or partial. It cannot authenticate artifacts, approve a proof as
  complete, or imply that a UI journey passed.
- `core-tests`: runs the safety scripts with a system-only macOS `PATH`,
  adversarially tests both bounded runners without launching an app, then runs the complete package suite and
  App-owned composition contract.
- `app-build`: compiles the production app and golden UI bundle without launch.

Workflow actions are pinned to reviewed full commit SHAs. The checkout pin is
official `actions/checkout` v7.0.1, which uses the Node 24 action runtime.

The workflow runs for pull requests, merge queue candidates, and pushes to
`main`. For PR #14 at earlier source
`1dccc860b83a14231b1c6138a031d78aa3f8c278`, `core-tests` and `app-build`
both passed in
[GitHub Actions run 33942146377](https://github.com/serpcompany/serpy-clicky-mac-app/actions/runs/33942146377).
The evidence-honesty job is new in this integration and needs its own exact-head
GitHub result before it can be claimed green.
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

## Xcode Cloud configuration and burn-in

The repository is connected and the `golden-ui-tests` workflow is configured
with the `GuideCompanion` scheme, complete `GuideCompanionGolden` plan, one Mac
destination, and no secrets. The action is required inside the workflow because
Apple requires at least one required action, but the cloud check is not a
required branch-protection gate during burn-in.

The configuration checklist is:

1. Open `GuideCompanion.xcodeproj` in Xcode while signed into the correct Apple
   Developer team.
2. Confirm Xcode Cloud remains connected to the GitHub repository.
3. Select `GuideCompanion` as the product/scheme.
4. Select the workflow named `golden-ui-tests`.
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
