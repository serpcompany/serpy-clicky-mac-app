# SERPy build 26 voice guide evidence

## Purpose

Build 26 corrects build 25's interaction model. Voice, not a typing window, is
the primary guide input. Control-Option-G or the menu action starts listening;
a second invocation submits the spoken question; Escape cancels. The local
answer is captioned beside the cursor and requested through macOS local speech.

## Reference boundary

The bounded behavior is based on the public HeyClicky FAQ and the MIT-licensed
Clicky README recorded in `docs/app-replica/scope.md`. No Clicky code, assets,
identity, cloud proxy, or private implementation was imported.

## Artifact identity

- Product: SERPy 0.1.0 (26)
- Installed path: `/Applications/SERPy.app`
- Bundle identifier: `com.serpcompany.guidecompanion.internal`
- Architecture: arm64
- Installed executable SHA-256:
  `ff9db8cfa6884dabf367df3ae830b5d87b8da62ec57d30d50923d309aa821c75`
- Release-build executable SHA-256 matched the installed executable.
- Developer ID signature and designated requirement verification passed.

This is installed-development evidence, not a notarized DMG release report.

## Deterministic evidence

- Full Swift suite passed: 22 XCTest tests plus 26 Swift Testing tests.
- Voice activation policy tests cover start, finish, follow-up, processing
  exclusion, and Escape cancellation.
- The local speech-output adapter rejects empty output without starting speech.
- The Developer ID Release build succeeded without deprecated-API warnings.
- The optional transcript window exposes no text field and remains a normal
  non-floating window.

## Installed observation

- Build 26 showed `Finish Question` immediately after voice capture started.
- A real spoken first turn was transcribed and received a local contextual
  answer without opening a typing composer.
- A real spoken follow-up was transcribed and received a second contextual
  answer in the same transient conversation.
- The cursor companion and menu status followed listening and processing state.
- The optional transcript surface displayed stable user/guide turns and the
  current source-window label.
- Starting a new voice capture exposed a visible Cancel control; cancelling
  returned to idle and submitted no additional conversation turn.

The observation used benign questions. Dictated text, raw screen text, and
screenshots are intentionally omitted from committed evidence.

## Remaining acceptance

- The code requested local AVFoundation speech playback for each answer, but an
  audible owner observation is still required before C12 is accepted.
- The visible cancellation path is installed-observed. The equivalent global
  Escape shortcut remains unit-tested because targeted UI automation cannot
  invoke global shortcuts.
- The bounded clean-room completion manifest remains red until these checks and
  independent owner verification pass.
