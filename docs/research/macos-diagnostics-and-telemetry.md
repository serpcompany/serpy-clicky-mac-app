# macOS diagnostics, crash reporting, and telemetry

- Date: 2026-09-04
- Decision scope: diagnostics for the direct-download SERPy macOS app
- Evidence rule: product and platform claims use Apple documentation, vendor
  documentation, or vendor-maintained source repositories. Pricing is a dated
  snapshot and must be rechecked before purchase.
- Current policy: research only. `AGENTS.md` and `PRODUCT.md` currently prohibit
  analytics and cloud services; this report does not authorize adding an SDK,
  an account, an ingestion endpoint, or a new data flow.

## Recommendation

Build the diagnostic architecture in two deliberately separate stages:

1. **Now, within current authorization:** make Apple's local stack useful.
   Expand typed `Logger` events, add `OSSignposter` intervals for the Guide and
   dictation stages, subscribe to MetricKit, retain only bounded redacted
   diagnostic payloads locally, preserve release dSYMs, and add a user-initiated
   “Export Diagnostics” support bundle. This adds no cloud service, account, or
   analytics identifier.
2. **Only after an explicit product/privacy authorization:** pilot **Sentry
   Cocoa in crash-and-error-only mode**, opt-in during the private beta. Sentry
   is the strongest fit for automatic native crash reports, handled nonfatal
   `GuideFailure`s, hang evidence, issue grouping, breadcrumbs, and dSYM-backed
   symbolication. Disable performance tracing, profiling, replay, attachments,
   memory introspection, network breadcrumbs, failed-request capture, and user
   identity. Admit only a small code-based event schema through a `beforeSend`
   allowlist. Do not initialize the SDK before consent.

Do **not** add PostHog or TelemetryDeck to solve the current failure. Both are
primarily analytics systems. PostHog now has capable Apple crash/error tracking,
but it brings a broader event/identity/remote-configuration surface than SERPy
needs. TelemetryDeck is attractive if SERPy later separately authorizes
privacy-conscious product analytics, but it is manual error counting rather
than a crash, hang, stack-trace, or symbolication system.

The visible error in the owner's 2026-09-04 report—“The local guide returned
malformed structured guidance”—is a handled provider-contract failure, not a
process crash. A crash-only SDK would not discover it. SERPy must report a
content-free nonfatal error code such as `guidance.plan.malformed`, its stage,
build, local/cloud adapter kind, and bounded timing; it must never report the
question, transcript, model output, OCR, screenshot, window title, target app
document, file path, API key, username, or clipboard content.

## Current SERPy baseline

The repository already has good raw ingredients but not a diagnostic system:

- `GuideFailure` provides a stable stage plus human-readable message and
  recovery action.
- `GuideAppModel` uses one `Logger` category for a handful of dictation
  lifecycle events and stores “last stage” / “last failure” for Settings.
- `TextInsertionService` has a separate `Logger` category, but some values such
  as target bundle identifier and `localizedDescription` are marked public.
- There are no signposts, MetricKit subscriber, crash handler, remote sink,
  issue grouping, dSYM upload, user diagnostic export, or telemetry dependency.
- The product contract explicitly requires redacted local logs and forbids a
  telemetry SDK, analytics identifier, analytics, and cloud services.

Before any remote pilot, existing log calls need the same schema and redaction
review as remote events. `localizedDescription` must not be assumed content-free.

## Crash/error monitoring is not product analytics

These answer different questions and need separate owner decisions:

| Capability | Question answered | Appropriate SERPy data |
| --- | --- | --- |
| Crash/error monitoring | “What failed, in which build and code path?” | crash stack, stable error code, stage, build, OS, anonymous run ID, timings |
| Performance monitoring | “Where does the app hang or exceed a latency budget?” | signpost/span name and duration; no content |
| Product analytics | “Which features and flows do people use?” | launches, screens, actions, cohorts, retention, persistent identities |
| Session replay | “What was drawn and clicked before a failure?” | pixels/view hierarchy/input events—an especially high-risk class for SERPy |

SERPy can authorize crash/error monitoring without authorizing product
analytics. It should not call usage events “diagnostics” to bypass the product
boundary. Session replay is inappropriate here: SERPy handles dictated text and
request-scoped screenshots of other applications. Persistent or incidental
capture would contradict the current no-storage and request-scoped-capture
contracts even if a vendor masks some controls.

## Option comparison

| Dimension | Apple local stack | Sentry Cocoa | PostHog Apple SDK | TelemetryDeck Swift SDK |
| --- | --- | --- | --- | --- |
| Native crash reports | macOS `.ips` reports; Organizer only for App Store/TestFlight distribution; MetricKit can deliver on-device crash diagnostics | Yes; native handler and crash event after relaunch | Yes; optional Mach exception, signal, and uncaught `NSException` capture, sent after relaunch | No automatic native crash reporter documented |
| Handled/nonfatal errors | `Logger`/custom local record; MetricKit CPU exceptions are not application-level handled errors | Yes, manual capture with stack/context | Yes, `captureException`; also generic events | Yes, manual `errorOccurred`, grouped by a developer-supplied ID |
| Hangs/performance | MetricKit hang, launch, responsiveness, CPU, disk, energy metrics; signposts and Instruments | App-hang detection plus MetricKit integration and optional tracing/profiling | No equivalent macOS hang profiler documented; event timings can be sent manually | Duration/events only; MetricKit ingestion is not in the released SDK as of this review |
| Breadcrumbs/context | Developer-defined log/signpost sequence | Automatic and manual breadcrumbs, configurable | Developer-defined “exception steps,” plus broader event context | Developer-defined signals only |
| Issue grouping | Manual triage | Mature issue grouping/fingerprinting | Groups exception events into issues | Dashboard/preset grouping by stable error ID, not stack-based crash triage |
| Symbolication/dSYMs | Xcode/macOS tooling with archived matching dSYM | dSYM upload tooling and release association | `upload-symbols.sh` / PostHog CLI | No native crash symbolication flow |
| Feedback/replay on macOS | TestFlight feedback is irrelevant to current direct-download distribution; users can manually send `.ips`/logs | macOS SDK has no Session Replay and its built-in feedback UI is iOS-only | Session Replay is explicitly iOS-only | No replay or crash-linked feedback workflow |
| Offline behavior | Fully local until the user exports; MetricKit delivers to the app | On-disk envelope cache and later delivery | File-backed event queue; pending crash is processed next launch | File-backed signal cache, saved/restored on macOS termination/launch |
| macOS + SwiftUI | Native, zero dependency | Official SPM SDK and macOS Swift/SwiftUI samples | SPM supports macOS 10.15+; native crash capture includes macOS | Official Swift SDK supports macOS and SwiftUI initialization |
| Hosting/residency | Device-local; Apple distribution reports use Apple's service | Sentry Cloud, or operationally heavy self-hosted Sentry | US/EU Cloud, or limited unsupported hobby self-host | Cloud only; vendor says EU/Germany-hosted and no on-prem/self-hosted product |
| Best fit | **Approved baseline now** | **Best later crash/error-only pilot** | Only if the owner wants a broader combined analytics platform | Later product analytics, not crash monitoring |

### Apple: Unified Logging, signposts, MetricKit, and Organizer

Apple's unified logging system is available on macOS 10.12+, stores log data in
memory and on disk, supports privacy-aware interpolation, and is viewable in
Console, the `log` tool, Xcode, or programmatically through OSLog. Apple also
positions signposts as the API for measuring intervals and events.
[Apple: Logging](https://developer.apple.com/documentation/os/logging/)

MetricKit supports macOS apps and provides crashes, hangs, CPU exceptions, disk
writes, launch, responsiveness, memory, energy, and custom signpost metrics.
Aggregate reports cover the preceding 24 hours and arrive at most daily;
diagnostic reports are delivered immediately on macOS 12 and later. MetricKit
delivers payloads to the app—it does not itself give this direct-download
project a remote dashboard.
[Apple: MetricKit](https://developer.apple.com/documentation/metrickit),
[Apple: monitoring with MetricKit](https://developer.apple.com/documentation/metrickit/monitoring-app-performance-with-metrickit)

Apple's automatic Xcode Organizer crash and diagnostic channel applies to apps
distributed through TestFlight or the App Store. SERPy currently ships as a
Developer ID/notarized direct-download DMG, so it cannot depend on Organizer for
automatic reports. For direct distribution, a user can retrieve a macOS crash
report and share it, and non-crash problems can be investigated with Console.
Apple recommends using its complete crash reports when available because a
third-party report may omit information, and recommends symbolication before
sharing.
[Apple: acquiring crash reports and diagnostic logs](https://developer.apple.com/documentation/xcode/acquiring-crash-reports-and-diagnostic-logs),
[Apple: distribution and reports](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

**Operational fit:** low. The release process must archive every exact dSYM by
build and executable UUID, and the app needs a redacted export UI. The weakness
is discoverability: local evidence still needs a user to export it unless a
future authorized uploader is added.

### Sentry Cocoa

Sentry maintains an official Apple SDK supporting macOS and SwiftPM, with macOS
Swift and SwiftUI samples. Its SDK provides native crash capture, manual error
events, cached envelopes, breadcrumbs, app-hang tracking, MetricKit integration,
release/build association, issue grouping/fingerprinting, and dSYM handling.
[Sentry Cocoa README](https://github.com/getsentry/sentry-cocoa/blob/main/README.md),
[Sentry Apple SDK options](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Options.swift),
[Sentry issue details](https://docs.sentry.io/product/issues/issue-details/),
[Sentry debug information files](https://docs.sentry.io/api/projects/list-a-projects-debug-information-files/)

There are important macOS and privacy limits:

- Session Replay is compiled only for iOS/tvOS, not macOS.
  [Sentry replay integration](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Integrations/SessionReplay/SentrySessionReplayIntegration.swift)
- The built-in user-feedback UI is iOS-only; SERPy would need its own explicit
  support form/export flow.
  [Sentry Apple options](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Options.swift)
- The SDK defaults `sendDefaultPii` and crash memory introspection off, but it
  also exposes automatic system/network breadcrumbs, failed-request capture,
  tracing, profiling, attachments, and local caches. For SERPy, absence of
  default PII is not enough: every automatic integration should be disabled
  unless explicitly admitted, and `beforeSend` should reject non-schema fields.
  [Sentry Apple SDK options](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Options.swift)

Hosted pricing on the review date: Developer is $0 for one user and includes
5,000 errors/month and 30-day lookback; Team is shown at $26/month when billed
annually and includes 50,000 errors/month and multiple users. Limits and
overages must be reconfirmed before adoption.
[Sentry pricing](https://sentry.io/pricing/)

Self-hosting is possible, but Sentry recommends 4 CPU, 16 GB RAM, and 20 GB disk
and describes an experimental errors-only install. The self-hosted platform is
under the FSL-1.1-Apache-2.0 license (internal use allowed, competing hosted
offerings restricted; releases convert to Apache 2.0 after two years). The
client SDK itself is MIT.
[Sentry self-hosted requirements](https://develop.sentry.dev/self-hosted/),
[Sentry self-hosted license](https://github.com/getsentry/self-hosted/blob/master/LICENSE.md),
[Sentry Cocoa license](https://github.com/getsentry/sentry-cocoa/blob/main/LICENSE.md)

**Operational fit:** medium for hosted, high for self-hosted. Hosted Sentry is
the best technical match after authorization, but it creates a new cloud data
processor, retention policy, incident-access surface, dSYM upload secret, and
consent/opt-out lifecycle.

### PostHog Apple SDK

PostHog's current native SDK supports macOS 10.15+ and now includes production
error tracking. Crash autocapture is off by default; when enabled it captures
Mach exceptions, POSIX signals, and uncaught `NSException`s, persists a fatal
report, and sends it on the next launch. It also supports manual Swift `Error`
capture, bounded exception steps, issue grouping, and dSYM upload tooling.
[PostHog package platforms](https://github.com/PostHog/posthog-ios/blob/main/Package.swift),
[PostHog error configuration](https://github.com/PostHog/posthog-ios/blob/main/PostHog/ErrorTracking/PostHogErrorTrackingConfig.swift),
[PostHog exception APIs](https://github.com/PostHog/posthog-ios/blob/main/PostHog/PostHogSDK.swift),
[PostHog issue grouping](https://github.com/PostHog/posthog.com/blob/master/contents/docs/error-tracking/issues-and-exceptions.mdx),
[PostHog symbol uploader](https://github.com/PostHog/posthog-ios/blob/main/build-tools/upload-symbols.sh)

Its file-backed queues survive process restarts and retry later, but that also
means event content is persisted locally. Session Replay is explicitly iOS-only
and the implementation is guarded by `#if os(iOS)`, so it cannot explain a
native SERPy macOS UI failure.
[PostHog iOS usage](https://github.com/PostHog/posthog.com/blob/master/contents/docs/libraries/ios/usage.mdx),
[PostHog replay integration](https://github.com/PostHog/posthog-ios/blob/main/PostHog/Replay/PostHogReplayIntegration.swift),
[PostHog queue behavior](https://github.com/PostHog/posthog-ios/blob/main/PostHog/PostHogQueue.swift)

Hosted Free on the review date is not a trial and includes 100,000 exceptions,
1 million analytics events, 5,000 replay recordings, 10 GB logs, one project,
and one-year retention; paid usage retains free allowances. PostHog offers a
self-hosted open-source deployment, but calls it hobbyist, unsupported, and
unlikely to scale beyond a few hundred thousand events without substantial
effort; several Cloud features are absent.
[PostHog pricing](https://posthog.com/pricing),
[PostHog self-hosting disclaimer](https://github.com/PostHog/posthog.com/blob/master/contents/docs/self-host/open-source/disclaimer.mdx),
[PostHog license](https://github.com/PostHog/posthog/blob/master/LICENSE)

**Operational fit:** medium-to-high. It could technically do crash/error
monitoring, but its core abstractions—persistent distinct IDs, broad event
capture, remote config, product analytics, flags, surveys, logs, and replay—are
far wider than this product's currently authorized diagnostic need. Choose it
only after a deliberate decision to adopt PostHog as a broader data platform,
not merely because its free quota is large.

### TelemetryDeck

TelemetryDeck's official Swift SDK supports macOS/SwiftUI, collects only
developer-sent signals, anonymizes the per-install user ID, rounds timestamps
to the hour, does not store IP addresses, and has a privacy manifest. Its macOS
client backs pending signals to disk and reloads/retries them on a later run.
[TelemetryDeck platforms](https://telemetrydeck.com/platforms/),
[TelemetryDeck Swift SDK](https://github.com/TelemetryDeck/SwiftSDK),
[TelemetryDeck privacy FAQ](https://telemetrydeck.com/docs/guides/privacy-faq/),
[TelemetryDeck signal manager](https://github.com/TelemetryDeck/SwiftSDK/blob/main/Sources/TelemetryDeck/Signals/SignalManager.swift)

The Errors preset accepts manually emitted signals with a stable ID, category,
message, and optional fields. TelemetryDeck warns that dynamic error messages,
file paths, or input data may contain user data and change privacy obligations.
It does not document automatic native crash capture, stack traces, dSYM
symbolication, hang diagnosis, or crash-linked replay. A pull request to add
MetricKit-derived events remained open at the review date, so it must not be
treated as a shipped feature.
[TelemetryDeck Errors preset](https://telemetrydeck.com/docs/articles/preset-errors/),
[TelemetryDeck MetricKit pull request](https://github.com/TelemetryDeck/SwiftSDK/pull/299)

New accounts receive 50,000 events/month free as of July 2026 (older accounts
retain 100,000); the first paid tier is listed at EUR 9/month for 750,000 events.
TelemetryDeck provides no self-hosted/on-premise service and says its service is
EU hosted.
[TelemetryDeck July 2026 pricing update](https://telemetrydeck.com/blog/pricing-update-2026/),
[TelemetryDeck plans](https://dashboard.telemetrydeck.com/plans),
[TelemetryDeck hosting](https://telemetrydeck.com/docs/articles/hosting-solutions/)

**Operational fit:** low for automatic bug discovery, good for separately
authorized low-cardinality product analytics. Pairing it with a crash system
would create two SDKs and two governance surfaces.

## Staged architecture for SERPy

### Stage 0 — local diagnostics (authorized now)

Add a narrow GuideCore protocol, implemented locally by GuideMac/App, rather
than calling a vendor from `GuideUI`:

```text
DiagnosticEvent
  code: stable enum                 // guidance.plan.malformed
  severity: notice | recoverable | fatal
  stage: GuideFailureStage?
  build: version + build number
  runID: random, memory-only
  durationBucket: optional
  attributes: allowlisted enums/bools/integers only

DiagnosticsRecording.record(event)
DiagnosticsRecording.beginInterval(name) -> token
DiagnosticsExporting.exportRedactedBundle()
```

Implementation requirements:

1. Centralize `Logger` subsystem/categories and make interpolated data private
   unless the schema explicitly declares it public.
2. Record stable error codes rather than raw `localizedDescription`.
3. Add signpost intervals for activation, permission, recording,
   transcription, target lock, capture, OCR/understanding, generation/parse,
   presentation, speech, insertion, cancellation, and cleanup.
4. Subscribe to MetricKit and retain a strict bounded local representation of
   crash/hang/CPU/disk-write diagnostics. Keep the raw payload only if a
   redaction audit proves it safe; otherwise include it only through explicit
   owner-approved export.
5. Archive release app, executable UUID, dSYM UUID, commit, and checksum for
   every installed build. Never delete the newest matching dSYM during cache
   cleanup.
6. Export only after a visible user action. Show the exact contents before
   sharing; omit screenshots, audio, transcripts, OCR, Guide responses, window
   titles, document paths, clipboard data, usernames, credentials, and secrets.
7. Add contract tests that feed seeded secrets through every diagnostic path
   and prove they are absent from logs/exported files.

This stage would have made the reported handled failure discoverable in a
support bundle without violating the no-cloud rule.

### Stage 1 — opt-in Sentry crash/error pilot (requires authorization)

Before implementation, the owner must explicitly authorize:

- Sentry as a cloud processor (or accept the operational cost/license of
  self-hosting), account/project creation, network egress, and dSYM upload;
- the exact event schema, lawful/privacy basis, disclosure text, default
  consent state, retention, region, access roles, deletion/export process, and
  incident response owner;
- a pseudonymous installation or run identifier, if any—currently prohibited
  by the “no analytics identifier” rule;
- local disk buffering of unsent events and the purge behavior on opt-out; and
- beta testing with a synthetic crash, hang, offline/retry, malformed-plan
  nonfatal, redaction fixture, and uninstall/opt-out deletion test.

Configure the pilot narrowly:

- disabled until explicit opt-in; no silent remote reporting;
- crash handler + manually captured allowlisted nonfatals only;
- release/build/dist set to the signed artifact and dSYM upload verified by
  UUID before distribution;
- `sendDefaultPii = false`; no user object or persistent identity;
- tracing/profile/replay/attachments/memory introspection/network breadcrumbs,
  failed HTTP request capture, view/controller instrumentation, and screenshots
  disabled;
- `beforeSend` rejects unknown tags/contexts and raw error strings;
- bounded cache and retention; purge cache immediately on opt-out;
- one crash handler only—never run Sentry and PostHog crash capture together;
  and
- continue to retain Apple's complete `.ips` report path because Apple warns
  third-party reports can omit diagnostic information.

### Stage 2 — product analytics (separate future decision)

If the owner later changes the Deferred scope to permit product analytics,
write a new data-purpose specification first. TelemetryDeck is the cleaner
shortlist for aggregate, low-cardinality usage signals; PostHog is the shortlist
when funnels, flags, experiments, surveys, and a broad product platform are
actually wanted. Neither decision should reopen screenshot, transcript, OCR,
audio, input, window-title, or persistent screen-capture collection.

## Acceptance gates for any remote tool

- A policy diff explicitly removes only the minimum necessary prohibitions.
- The Settings disclosure lists data categories, destination/region, retention,
  consent state, and a working opt-out/delete action.
- Network inspection proves no request occurs before opt-in or after opt-out.
- A seeded-secret test proves forbidden content never reaches queued payloads,
  crash context, breadcrumbs, logs, or transport.
- Offline testing proves the queue is bounded and opt-out purges it.
- Exact-build crash and handled-nonfatal fixtures appear symbolicated and group
  correctly; a deliberate hang has useful evidence.
- Release CI retains and verifies dSYMs without embedding upload credentials in
  the app or repository.
- Session replay, screenshots, view hierarchy, keystrokes, text input, audio,
  transcript, OCR, and Guide model input/output remain disabled and absent.
- Telemetry failure never changes dictation or Guide behavior.

## Bottom line

Use **Apple local diagnostics now** and treat every surfaced product failure as
a stable, content-free diagnostic event. If the owner explicitly approves a
remote beta later, use **Sentry in a severely reduced crash/error-only
configuration**. Do not add product analytics or replay as a side effect of
trying to learn about crashes. PostHog is technically capable but too broad for
the present contract; TelemetryDeck is not a crash reporter.
