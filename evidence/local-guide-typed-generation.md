# Local Guide typed-generation checkpoint

2026-09-05. Installed build 44 previously displayed the local malformed-plan
failure. Source used unconstrained `LanguageModelSession.respond(to:)` and then
expected JSON. The adapter now requests `FoundationGuidanceResponse` through
Apple's `@Generable` schema, encodes that typed value, and preserves the existing
provider boundary, plan validator, grounding policy, and cancellation ownership.

The schema bounds steps to 1–6 and completion-evidence arrays to 1–4. A new
Swift Testing contract verifies exact encoded keys, quotation preservation,
step order, and schema compilation. The initial test failed to compile (its
availability annotation required correction); it is not claimed as a behavioral
red reproduction of the installed failure. The complete bounded `core-tests`
command subsequently passed.

A separate 120-second-bounded command-line probe compiled the actual schema
source and queried the real on-device model using only a synthetic Chrome
fixture. It returned a structurally valid two-step File → New Window plan.
Its completion evidence used descriptive sentences rather than exact visible
labels, so semantic progression remains unproven. No microphone, screen capture,
paid provider, or private user content was used. Probe files remain explicitly
temporary under `/private/tmp/serpy-foundation-probe.D1qWoP`.

This change is not yet installed. It does not prove HeyClicky visual parity,
grounded pointer placement, spoken output, or cross-app acceptance.

Reference: Apple's Foundation Models guided-generation documentation and the
installed macOS SDK declarations for `respond(to:generating:)` and `@Guide`.
