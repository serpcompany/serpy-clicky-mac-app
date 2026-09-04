# Agent Instructions

## Mission

Stabilize the two existing Version 1 capabilities defined in
`docs/product/version-1-stabilization.md`: Dictation first, then the
HeyClicky-style Guide. Lock working behavior with tests before design changes or
refactoring. Do not add later product areas during stabilization.

## Current Authorization

The owner authorized implementation through the installed-product finish line
on 2026-08-16. Follow `DELIVERY_PLAN.md` in order. This authorization includes
local source changes, local model/runtime evaluation, stable tester-owned
signing configuration, packaging, notarization, and installed-app verification.
It does not authorize a public release, public remote, billing, cloud services,
or any feature listed under Deferred in `PRODUCT.md`.

On 2026-09-04 the owner separately authorized one narrow exception for Talk:
an opt-in, request-scoped OpenAI multimodal path may transmit the current Talk
question, bounded recent Talk context, and the exact locked-window screenshot.
Ordinary dictation remains local. This exception does not authorize live API
spend during automated work, hosted accounts, sync, analytics, autonomous
computer control, or persistence of guide content.

On 2026-09-04 the owner also authorized a development-only Sentry pilot for
allowlisted handled failures and agent-assisted QA. Follow ADR 0007. The DSN is
injected at runtime and never committed. This does not authorize production or
private-beta telemetry, product analytics, automatic GitHub writes, autonomous
merge/release, or transmission of questions, transcripts, model output,
screenshots, document content, identity, or arbitrary error strings.

## Hard Boundaries

- Dictation must not depend on an assistant engine, API key, or network.
- Do not embed autonomous computer use, shell execution, agents, accounts,
  sync, billing, product analytics, pets, widgets, browser control, or MCP in
  the product. The only approved cloud paths are the request-scoped Talk
  adapter and development-only Sentry pilot described above.
- **Guide has one reference product family: HeyClicky.** Use the installed app,
  the owner's Issue #7 recording, and the historical public MIT source
  `farzaa/clicky@a80fa80721a8aebe51a170a7780705024ebc6e46`. Do not introduce
  Frigade Assistant or any other assistant as a Guide behavior, UX, or code
  reference. Follow `PROVENANCE.md` for attribution and separation.
- FrigadeHQ/Yap is approved only for Dictation implementation. Its publisher
  relationship to Frigade does not make Frigade Assistant a Guide reference.
- Preserve serpy identity and use only the approved historical source revision;
  later private HeyClicky code, credentials, signing, services, and release
  configuration are outside the donor boundary.
- Do not copy upstream signing identities, Team IDs, bundle IDs, Sparkle keys,
  appcasts, credentials, release hosts, or secrets.
- Keep screenshots, audio, and Guide content transient by default. Dictation may
  retain only the bounded Last Dictation recovery record defined in `PRODUCT.md`.
- Never send Talk content unless the provider is explicitly selected, the
  per-device disclosure is accepted, and a credential is available. Never
  silently fall back between local and cloud guidance.
- Do not broaden permissions. Camera, Full Disk Access, System Events
  Automation, and persistent screen capture are outside the first product.
- Do not publish, create a remote, or upload artifacts without approval of the
  exact destination and visibility.

## Engineering Rules

- **Version 1:** read `docs/product/version-1-stabilization.md` before planning,
  implementing, reviewing, or verifying product work.
- **Dictation reference:** before changing recording, transcription, shortcuts,
  insertion, cancellation, or recovery, read
  `docs/research/superwhisper-dictation-inventory.md` and produce the donor
  import map it requires before introducing a new abstraction.
- **User flows:** read `docs/product/user-flows.md` before changing or verifying
  user-visible behavior; update its issue traceability when the contract changes.
- **Testing:** read `docs/engineering/testing.md` before running tests or changing
  the harness. Routine local verification is headless; XCUI runs in the isolated
  UI lane and installed verification uses one exact reviewed artifact.
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
