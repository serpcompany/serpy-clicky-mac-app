# Local Guide pointing regression

2026-09-05, M3 source check; installed acceptance remains red.

The production local adapter supplied visible text without evidence IDs and
decoded only step text/completion labels. Consequently every local step lost
its pointing target, independently of the overlay renderer.

`LocalGuidancePointingTests.groundedPoint` exercises `LocalGuidanceService.answer`
with a controlled provider response and synthetic OCR bounds. Before the fix,
`scripts/run-headless-check.sh core-tests` failed on missing `ocr-1` in the
provider prompt and a nil decoded point. After the fix the full core lane passed.

The typed local schema now permits an optional evidence ID, not model-produced
coordinates. The adapter resolves it only against bounded, high-confidence,
in-window OCR evidence supplied in this request. It converts Vision's
bottom-left bounds to the overlay's top-left coordinate convention. Unknown
IDs, low-confidence evidence, empty bounds, and out-of-window bounds produce no
point. Existing response fixtures without an ID stay text-only.

This is not installed HeyClicky parity or proof of local model target selection.
The captured window excludes the system menu bar; Chrome File → New Window
still needs request-scoped app-menu evidence and compatible cue geometry.
The reference black edge-attached surface also remains visibly different from
the current rounded material surface. These gaps remain unresolved.

Candidate build 46 keeps internal Sentry reporting disabled after the rejected
build 45 privacy observation. No OpenAI request is part of this test.
