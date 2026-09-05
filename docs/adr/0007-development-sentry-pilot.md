# ADR 0007: Development-only handled-error Sentry pilot

Date: 2026-09-04

## Status

Extended by owner approval on 2026-09-05 to explicitly configured installed
internal test builds. General production telemetry, automatic GitHub issue
creation, scheduled agent writes, and crash collection remain unapproved.

Internal builds require `SERPY_INTERNAL_DIAGNOSTICS` at compile time, a runtime
or build-injected DSN, and environment `internal-test`. Ordinary Release builds
remain disabled. The existing development environment retains its original
single-code allowlist. Internal tests additionally allow the fixed
`guide.failure.unclassified` code grouped by the enum failure stage, with only
enum provider classification and the existing scrubbed build metadata. This
allows stage-level triage of handled errors, not arbitrary logs or crash stacks.
The owning Dictation failure presenter and Guide coordinator emit typed
incidents; absent configuration uses the no-op reporter. All automated tests
remain transport-free. An installed event must be retrieved before claiming the
expanded feedback loop works.

## Decision

Evaluate whether one allowlisted handled failure can move from an installed
SERPy run into Sentry and then into an agent without manual diagnostic copying.

The first event contract contains only:

- `guidance.plan.malformed` as the message and fingerprint;
- failure stage;
- provider kind;
- schema version;
- Sentry environment;
- application release, version, and build;
- error severity and Cocoa platform identifier;
- event timestamp and Sentry event identifier; and
- Sentry SDK name and version.

The DSN is supplied through `SENTRY_DSN` at process launch or injected as an
Xcode build setting into a local development artifact. It is never stored in
source, defaults, or Keychain. With no DSN, the generated Info.plist value is
empty, the reporter is a no-op, and the app creates no Sentry client.

## Privacy controls

The pilot disables crash handling, tracing, profiling, app-hang tracking,
MetricKit, structured-log ingestion, metrics, sessions, automatic breadcrumbs,
network and file-I/O tracking, failed-request capture, swizzling, memory
introspection, user identity, and default PII.

`beforeSend` accepts only events tagged `serpy_schema=handled-v1` and removes
user, context, extra, module, breadcrumb, thread, debug-image, request,
transaction, stacktrace, and exception fields before serialization. Seeded
contract tests exercise this boundary.

The first synthetic transport attempt revealed that Sentry's defaults added a
generated user identifier, device/culture context, and local debug paths even
with default PII disabled. That event contained no Talk question, transcript,
screenshot, raw response, credential, or document content. The configuration
was tightened before the second attempt. The second serialized envelope was
allowlist-only and received HTTP 200 from Sentry.

## Verification seam

`--ui-testing --guide-fixture=malformed-plan` presents the real handled-error UI
and records a typed diagnostic incident without microphone capture, screen
capture, model execution, or arbitrary content. Package tests cover failure
classification and coordinator reporting; XCUI covers visible app behavior.

## Consequences

- GuideCore owns the typed incident and reporting protocol.
- GuideMac owns the Sentry adapter and SDK dependency.
- App composition enables Sentry only when a runtime DSN is present.
- The official Sentry Codex plugin and authenticated MCP may read pilot events
  for diagnosis, but may not modify Sentry, GitHub, source, or releases without
  the authority of the current task.
- Crash reporting can be considered only after a separate stack-path and
  identity redaction contract is tested.

## References

- https://github.com/getsentry/sentry-cocoa
- https://github.com/getsentry/plugin-codex
- https://docs.sentry.io/platforms/apple/
- `docs/research/agent-assisted-bug-triage.md`
- `docs/research/macos-diagnostics-and-telemetry.md`
