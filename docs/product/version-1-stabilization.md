# Version 1 stabilization contract

This document controls Version 1 work. GitHub issues contain the work; this
document defines which outcomes belong to the release and how they are proven.

## Product boundary

Version 1 stabilizes the two capabilities already present in the app:

1. **Dictation** — Superwhisper-style local speech-to-text and focused-field
   insertion.
2. **Guide** — HeyClicky-style voice conversation, screen-aware answers, and
   progressive visual guidance.

HeyClicky is the sole Guide reference product. Its installed app, the owner's
Issue #7 recording, public product material, and pinned historical MIT source
are one reference family. Do not add Frigade Assistant or another assistant as
an additional Guide reference. Yap remains a Dictation-only code donor.

Version 1 adds no new product area. Onboarding redesign, payments, accounts,
expanded Settings/options, selected-keyboard language support, automatic
language detection, changed history defaults, Window Manager, Shortcut Coach,
and other utility integrations remain later work.

The canonical user-facing product name is **serpy**. Preserve the existing
bundle identifier, signing identity, Keychain service, preferences domain, and
internal module/type names during stabilization so renaming does not reset
permissions or stored state. Historical evidence keeps the exact capitalization
and artifact names it originally recorded.

## Execution order

1. Make the existing Dictation workflow work and lock it with regression tests.
2. Make the existing Guide workflow work and lock it with regression tests.
3. Apply the user-facing `serpy` name consistently.
4. Add automated enforcement around the accepted functional baseline.
5. Iterate on design and refactoring only after the baseline is green.

Do not mix onboarding, payments, broader settings design, new language
capabilities, or other app integrations into these stabilization steps.

## Dictation acceptance workflow

Reference inventory:
`docs/research/superwhisper-dictation-inventory.md`.

With an editable field focused in TextEdit and then Chrome:

1. Invoke the existing Dictation shortcut.
2. Speak a short phrase and stop Dictation.
3. Observe the exact transcript at the caret without activating serpy or
   submitting the destination.
4. Verify the prior clipboard remains intact.
5. Press Escape during a second attempt and observe that nothing is inserted.
6. Exercise the existing Last Dictation recovery when delivery is failed or
   unconfirmed.
7. Quit and relaunch once; verify one app instance and no permission loop.

The workflow must remain local and independent of Guide, Sentry, and OpenAI
configuration.

## Guide acceptance workflow

Use the owner's 12:56 Clipy review as the controlling walkthrough evidence:

- Recording: https://clipy.online/video/ggzzyvlnfi2s
- Agent context: https://clipy.online/video/ggzzyvlnfi2s.arec
- GitHub specification: https://github.com/serpcompany/serpy-clicky-mac-app/issues/7

With Chrome frontmost, ask how to open a new window:

1. Invoke the existing held Guide shortcut without activating serpy.
2. Observe compact listening, transcript, capture/thinking, speaking, and
   ready-for-follow-up states.
3. Receive a grounded ordered walkthrough that points first to `File`, then to
   `New Window`, then reports completion.
4. Keep the underlying Chrome controls clickable throughout the walkthrough.
5. Verify the overlay is compact, dismissible, and leaves no idle artifact.
6. Verify visible and spoken output contains no raw JSON, malformed quotes,
   duplicated sentences, or narrated punctuation.
7. Press Escape in each owned phase; verify work and transient UI stop without
   a delayed result.
8. Close and reopen Settings; verify Dock/Command-Tab presence, one app
   instance, and a normal quit path.

The orange/red Flare trail in the recording is recorder UI, not serpy UI.
Integrations, agents, autonomous clicking/typing, search execution, and file
deletion shown or discussed in the recording are outside Version 1.

## Test lock

Every reproduced defect receives a regression test at the lowest layer that
can honestly detect it:

- Swift Testing for new unit and direct integration tests.
- Existing XCTest unit/integration tests remain until a separate refactor earns
  migration.
- XCTest/XCUI only for a small number of critical UI journeys.
- Exact installed-artifact observation for microphone, macOS permissions,
  Accessibility insertion, cross-app focus, audible speech, Keychain, signing,
  notarization, Gatekeeper, and click-through behavior.

Tests protect user-visible outcomes, not the current internal structure or an
unfinished visual design. Read `docs/engineering/testing.md` before running or
changing the harness.

## Completion

Version 1 is ready for owner review only when both acceptance workflows pass on
one exact installed artifact, their deterministic regression tests pass, the
safe automated harness passes, and the reviewed artifact is shown to the owner.
A build, mock, screenshot, or passing unit suite cannot substitute for the
installed workflow.
