# SERPy issue #7 build 42 installed checkpoint

Date: 2026-09-04

Claim: **Issue #7 source contracts installed for owner QA.** This is not parity
verification or owner acceptance.

## Exact artifact

- Branch: `codex/issue-7-guide-parity` (local, unpushed)
- Commit: `badc0b0a992708a8edcce9a88aa7a3275498ad6f`
- Installed app: `/Applications/SERPy.app` `0.1.0 (42)`
- Executable SHA-256:
  `0a5a1b06ebfccb40931d33308e54309805ba7918af8b89ef9683a0a5a3e2f8e1`
- DMG: `dist/SERPy-0.1.0-42.dmg`
- DMG SHA-256:
  `4873ddc933dd8e30b41821d3864482cd8ed3cfc6f83bc49a015b0ee49f708f73`
- Notarization: accepted submission
  `a4809fe6-49f0-436a-b9d3-24dbf843fae1`; DMG stapled
- Signature/Gatekeeper: strict Developer ID verification and Gatekeeper execute
  assessment passed

The installed executable hash equals the retained reviewed Release hash.
LaunchServices reports one installed foreground build-42 process. Generated
debug/staging products and replaced builds were unregistered and moved to Trash;
only the retained Release bundle remains inside the repository.

## Verification

- Package tests: 95 XCTest + 34 Swift Testing = 129 passing.
- Xcode UI tests: 2/2 passing.
- The launch/Settings UI test failed first against the unreliable SwiftUI
  selector path, then passed after one owned normal window controller became the
  launch, Dock-reopen, menu, and Command-comma route.
- DMG signature, checksum, notarization ticket, mounted-app signature, Gatekeeper
  open, and mounted-app execute checks passed.
- Live installed window inventory: `SERPy Settings`, 680×704.
- Live installed process: foreground application, build 42, no `LSUIElement`.
- Candidate screenshots:
  `evidence/issue-7-serpy-build-42/candidate/setup.jpeg` and
  `evidence/issue-7-serpy-build-42/candidate/guidance.jpeg`.

## Implemented slice

- Normal Dock/Command-Tab lifetime with Settings on launch and Dock reopen.
- No rejected persistent idle cursor badge.
- Click-through, nonactivating transient Guide surfaces.
- Exact PID/window/title/frame/display lock and bounded validated point cue.
- Structured two-to-six-step local/OpenAI plans with one active `Step n of m`.
- Explicit reinvocation performs a fresh capture and advances, stays with a
  reason, or completes without polling, regeneration, or autonomous action.
- Ordered sanitized active-step speech, deterministic cancellation/reset, and
  visible answer retention on speech failure.

No live paid provider request was made. Physical held-shortcut, microphone,
focus/hit testing, Chrome/Slack walkthrough, audible voice, multi-display,
VoiceOver/Reduce Motion, and device-recovery rows remain red in
`docs/hil/serpy-issue-7-guide-parity.md`.
