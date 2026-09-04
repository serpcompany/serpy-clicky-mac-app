# Version 1 delivery plan

Version 1 stabilizes existing functionality. It does not add onboarding,
payments, broader Settings/options, language features, changed history defaults,
or other SERP applications. `docs/product/version-1-stabilization.md` is the
scope and acceptance authority.

## Phase 1 — Dictation stabilization

Exercise the existing Dictation workflow in TextEdit and Chrome. Reproduce each
failure, add a regression test at the lowest honest layer, correct the behavior,
and verify the affected headless suite.

Complete this phase only when the exact installed artifact passes invocation,
local transcription, insertion, cancellation, clipboard preservation, existing
recovery, quit, and relaunch without a permission loop or duplicate process.

## Phase 2 — Guide stabilization

Use installed HeyClicky and the Issue #7 Clipy recording as the UX/behavior
oracle. The pinned historical MIT Clicky revision in `PROVENANCE.md` is an
approved implementation donor. This is the sole Guide reference family: do not
introduce Frigade Assistant or any other assistant product. FrigadeHQ/Yap is a
Dictation-only donor.

Reproduce and fix the existing Guide workflow in vertical slices: lifecycle,
compact phase UI, target lock, two-step Chrome walkthrough, progression, safe
pointing, speech ordering, cancellation, click-through behavior, and cleanup.

Complete this phase only when the exact installed artifact passes the Chrome
`File` → `New Window` → done walkthrough and the owner accepts the functional
result.

## Phase 3 — User-facing name

Change visible product identity from `SERPy` to `serpy` while preserving the
existing bundle identifier, signing identity, Keychain service, preferences
domain, and internal module/type names. Verify permissions and stored state
survive the change.

## Phase 4 — Test enforcement

Implement the safe lanes in `docs/engineering/testing.md` around the accepted
functional baseline:

- headless local package and compile checks;
- isolated Xcode Cloud UI checks;
- explicit installed-artifact acceptance.

The local command must not launch serpy. Build/test products use bounded
temporary storage and are removed on exit or interruption. The UI-test runtime
must construct no production Keychain, permission, Sentry, or network adapter.

Complete this phase only after the functional baseline is already green and the
new harness proves it leaves no app process, prompt, or build cache behind.

## Phase 5 — Later iteration

After Version 1 is functionally locked, create separate issues for design
iteration, refactoring, onboarding, payments, Settings improvements, language
features, storage-default changes, and other SERP app integrations.
