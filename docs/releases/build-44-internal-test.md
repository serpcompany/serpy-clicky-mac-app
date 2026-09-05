# SERPy 0.1.0 (44) — internal test build

Built and installed on M3 on 2026-09-05. This is not a V1-ready or public release.

## Artifact

- Source: `685f7628269b9f1b913101ecf1865a69b830eddc`.
- Installer: `dist/SERPy-0.1.0-44.dmg` with adjacent checksum and manifest.
- DMG SHA-256: `8813a41006a9f4a32e07c47dbc971b508513992efa02ccf488be309d4ab2d4c9`.
- Installed executable SHA-256: `df31c19238e4b3b6b222af6292accccbd5f19bbeaf34f6ca03fcc228e7717378`.
- Developer ID signed, notarization accepted, DMG stapled and validated.
- `scripts/verify-release.sh dist/SERPy-0.1.0-44.dmg` passed, including
  Gatekeeper checks for both DMG and contained app.
- Installed from that mounted read-only DMG to `/Applications/SERPy.app`;
  installed signature and Gatekeeper checks passed; bundle version is 44.
- Build 43 installer remains in `dist`; previous installed bundle was moved
  intact to `/private/tmp/SERPy-build43-rollback.app` for short-term rollback.

## Changes since build 43

- Insertion-only diagnostics distinguish confirmed insertion from unconfirmed
  paste and provide an explicit check/retry instruction.
- Guide structured-plan speech begins after the speaking presentation is ready.
- Settings uses the current AppKit activation API.
- Golden-test corrections and safe-runner checks include the native Talk
  disclosure Switch and bounded session cleanup.

## Evidence and remaining gates

- Bounded headless core tests and app/UI-bundle compilation passed before the
  build-number change; the signed Release build then passed.
- Focused local UF-11 passed using a fake in-memory credential, without a live
  OpenAI call. It does not prove cloud-run stability.
- Build 44 launched with Microphone, Speech Recognition, and Accessibility
  Granted and shortcut Registered, without renewed permission prompts.
- Its insertion diagnostic visibly reports `Insertion test unconfirmed` and
  recovery guidance for unconfirmed paste. The attempted TextEdit focus switch
  was interrupted by stale computer-use state; this is not valid successful
  cross-app insertion evidence.
- A subsequent fresh-control retry still captured SERPy's own `AXWindow` in
  the existing insertion log, despite TextEdit reporting a focused text area
  through computer use. Hiding SERPy then captured Finder's `AXGroup`, not
  TextEdit. Stop synthetic retries until the owner directly focuses the
  intended field; per-app accessibility focus is not system frontmost focus.
- Real microphone capture, TextEdit and Chrome insertion, clipboard preservation,
  cancellation/recovery, installed Guide walkthrough and audible speech remain
  red. Xcode Cloud launch instability and ten-run burn-in remain unresolved.
- User-facing lowercase naming awaits the accepted functional baseline.

No public release or live paid API test was performed.
