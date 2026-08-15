# Agent Instructions

## Mission

Build the smallest polished macOS guide companion defined in `PRODUCT.md`.
Work through `DELIVERY_PLAN.md` in order and advance `ACCEPTANCE.md` only with
the required evidence.

## Current Authorization

The owner authorized implementation through the installed-product finish line
on 2026-08-16. Work through Phases 0–4 in order. This authorization includes
local source changes, local model/runtime evaluation, stable tester-owned
signing configuration, packaging, notarization, and installed-app verification.
It does not authorize a public release, public remote, billing, cloud services,
or any feature listed under Deferred in `PRODUCT.md`.

## Hard Boundaries

- Dictation must not depend on an assistant engine, API key, or network.
- Do not add autonomous computer use, shell execution, agents, accounts, sync,
  billing, analytics, pets, widgets, browser control, MCP, or cloud providers.
- Do not copy or decompile HeyClicky code, assets, private protocols, or product
  identity. Use it only as observable behavioral evidence.
- Do not import OpenClicky code without completing the gate in `PROVENANCE.md`.
- Do not copy upstream signing identities, Team IDs, bundle IDs, Sparkle keys,
  appcasts, credentials, release hosts, or secrets.
- Never store audio, screenshots, or transcript content by default.
- Do not broaden permissions. Camera, Full Disk Access, System Events
  Automation, and persistent screen capture are outside the first product.
- Do not publish, create a remote, or upload artifacts without approval of the
  exact destination and visibility.

## Engineering Rules

- Preserve the dependency direction in `ARCHITECTURE.md`.
- Add a deterministic state-machine test before connecting a feature to macOS
  APIs.
- External frameworks sit behind GuideCore protocols and receive contract
  tests.
- Every failure contains a stage, human-readable cause, and recovery action.
- Use stable signing identity and bundle ID for interactive TCC testing.
- Run Xcode-launched permission tests against one stable build identity; do not
  churn temporary command-line identities.
- Keep Settings a normal non-floating window and overlays nonactivating unless
  a documented interaction requires activation.
- Redact dictated text, screenshots, application document content, usernames,
  credentials, and secrets from committed evidence.

## Evidence Discipline

- Building is not proof of runtime behavior.
- Unit tests are not proof of OS-owned permission UI.
- A synthetic transcript is not proof of microphone capture.
- A preview is not proof of packaged overlay behavior.
- Only the exact signed artifact may satisfy installed-observed acceptance rows.
- Record unsupported applications and failure states rather than generalizing
  from one successful text field.

## Completion

No phase is complete until every required acceptance row for that phase has the
specified evidence and unresolved rows remain visibly red.
