# SERPy ambient voice-guide P0 TDD report

- Date: 2026-09-04
- Base commit: `332e82a7d78c3ec960602e61ac0894a3b61c1ba4`
- Source: implementation and this report are committed together after parent review
- Built artifact: `.release-derived/Build/Products/Release/SERPy.app`
- App version: `0.1.0 (28)`

## Confirmed seams

1. Companion visibility policy: an active voice-guide turn forces the companion visible without changing the saved `Show cursor companion` preference.
2. Response layout policy: a separately measured response bubble flips and clamps inside the display's visible frame.
3. Ambient presentation policy: ready, listening, live transcript, capturing, thinking, speaking, ready-for-follow-up, error, and cancelled map to distinct truthful presentations with only a compact app/window identity.

## Red-green record

### Slice 1 — guide-forced visibility

- RED command: `swift test --package-path Packages/GuideModules --filter StateMachineTests/testActiveVoiceGuideForcesCompanionVisibleWithoutChangingPreference`
- RED result: failed to compile because `CompanionVisibilityPolicy` did not exist.
- GREEN command: same focused command.
- GREEN result: 1 test passed, 0 failures.

### Slice 2 — edge-aware response layout

- RED command: `swift test --package-path Packages/GuideModules --filter CompanionResponseLayoutPolicyTests/testResponseBubbleStaysFullyVisibleAtScreenEdges`
- RED result: failed to compile because `CompanionResponseLayoutPolicy` did not exist.
- GREEN command: same focused command.
- GREEN result: 1 test passed, 0 failures.

### Slice 3 — ambient guide presentation

- RED command: `swift test --package-path Packages/GuideModules --filter GuidanceAmbientPresentationPolicyTests/testVoiceTurnHasTruthfulDistinctAmbientStagesAndCompactContext`
- RED result: failed to compile because `GuidanceAmbientPresentationPolicy` and `ScreenContextIdentity` did not exist.
- GREEN command: same focused command.
- GREEN result: 1 test passed, 0 failures after the policy and UI wiring compiled.

### Slice 4 — invocation-locked screen target

- RED command: `swift test --package-path Packages/GuideModules --filter ScreenContextTargetPolicyTests/testRememberedInvocationTargetDoesNotChangeAfterAppSwitch`
- RED result: failed to compile because `ScreenContextTargetPolicy` did not exist.
- GREEN command: same focused command.
- GREEN result: 1 test passed, 0 failures; screen capture now resolves the remembered invocation target and fails clearly if that window disappears instead of silently changing apps.

### Slice 5 — non-overlapping companion and answer surfaces

- RED command: `swift test --package-path Packages/GuideModules --filter CompanionResponseLayoutPolicyTests/testResponseBubbleAvoidsCompanionAtCenterAndEveryScreenEdge`
- RED result: failed to compile because the public response-layout seam did not accept an avoided companion frame.
- GREEN command: same focused command.
- GREEN result: 1 test passed, 0 failures across representative center, lower-left, lower-right, upper-left, and upper-right companion placements. Every answer frame retained its measured size, stayed inside the visible frame, and did not intersect the companion frame.

## Verification

- `swift test --package-path Packages/GuideModules`: 27 XCTest tests and 26 Swift Testing tests passed.
- `./scripts/build-release.sh`: signed Release build succeeded.
- `codesign --verify --deep --strict --verbose=2`: valid on disk and satisfies its designated requirement.
- Developer ID team: `847HR8U8D9`.
- Binary SHA-256: `47de425c7e601770ce872274412d6defd2f8ac2f745391d354240f88e29f683f`.
- `git diff --check`: passed.
- A conservative 55-word fixture using the production font and 340-point text width measured 176 points high, producing a 224-point panel. The response uses a non-scrolling `Text` surface and preserves that measured size on the test display rather than relying on interaction with a click-through `ScrollView`.

## Behavior implemented

- Starting a guide turn shows the companion even when the ordinary companion preference is off. The stored preference is not mutated, and ordinary visibility resumes when the transient guide presentation ends.
- Listening uses the complete current partial transcript rather than an unexplained trailing 90-character fragment.
- Captured context is labeled with a bounded app/window identity; OCR content is not included in the identity.
- Answers use a separate, adaptive response panel instead of the two-line status capsule. The layout policy treats the status panel as an avoided anchor, so the response and status neither overwrite nor geometrically cover one another.
- Response geometry flips and clamps within `NSScreen.visibleFrame`, preserving menu-bar and Dock exclusion.
- Speech completion changes the ambient state to ready-for-follow-up, retains the answer for eight seconds, and then returns to ordinary visibility.
- Both panels remain nonactivating, click-through, all-Spaces overlays. Reduce Motion disables SwiftUI state animation. Live transcript token updates are not exposed as repeated VoiceOver announcements.

## Unresolved installed evidence

Build 28 was installed from the exact signed Release artifact. With the saved
companion preference set to off, the idle overlay was absent. Starting a guide
turn made the listening capsule and captured `application — window` identity
visible beside the pointer. After the turn ended, the overlay returned to
hidden and the saved preference remained off.

The following remain red:

- A 55-word answer is readable in full at each display corner and near the menu bar/Dock.
- Multi-display, negative-origin display, another Space, and full-screen behavior.
- Captured app/window label matches the chosen target in a multi-window test and remains locked after app switching.
- Spoken-state timing and VoiceOver announcement behavior in the installed artifact.
