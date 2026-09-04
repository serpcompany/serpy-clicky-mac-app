# ADR 0007: Development-only handled-error Sentry pilot

Date: 2026-09-04

## Status

Accepted for development evaluation only. Production, private-beta, automatic
GitHub issue creation, scheduled agent writes, crash collection, and release
distribution remain unapproved.

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
