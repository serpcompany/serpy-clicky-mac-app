# Agent-assisted bug discovery and repair

- Date: 2026-09-04
- Decision scope: getting a SERPy failure from an installed macOS app into a
  reproducible, tested fix with as little owner handling as possible
- Evidence rule: product and capability claims use official OpenAI, GitHub, and
  Sentry documentation or vendor-maintained source repositories. Skills.sh is
  treated only as discovery metadata; candidates are verified against their
  source repositories before recommendation.
- Current policy: research only. This report does not authorize installing a
  plugin or MCP server, adding Sentry, creating accounts, transmitting app data,
  changing GitHub issues, scheduling an agent, or modifying product code.

## Recommendation

There is a materially better workflow than making the owner copy diagnostics
into an agent conversation:

```text
installed SERPy app
  -> allowlisted crash or handled-error event
  -> Sentry grouping and alert threshold
  -> one linked GitHub issue
  -> Codex reads the Sentry evidence and repository
  -> reproduces the failure, adds a failing test, fixes it, and reports back
```

Sentry's GitHub integration supports automatically creating GitHub issues from
Issue Alert conditions, subject to the Sentry organization's plan and feature
availability. Sentry also maintains an official Codex plugin that bundles its
debugging skills and hosted Sentry MCP server. GitHub maintains an official MCP
server that can search and manage issues and pull requests.
[Sentry integration metadata](https://docs.sentry.io/api/integrations/get-integration-provider-information/),
[Sentry for Codex](https://github.com/getsentry/plugin-codex),
[GitHub MCP Server](https://github.com/github/github-mcp-server)

This is agent-capable, but it is not currently authorized for SERPy. The app's
contract prohibits telemetry SDKs, analytics, and unapproved cloud services.
The owner must explicitly authorize a narrow Sentry crash/error data flow and
GitHub integration before this design can replace Issue #9's local-only flow.

No official source reviewed establishes an automatic “Sentry event starts a
Codex coding task” trigger. The supported pieces can collect, group, inspect,
and repair a bug, but unattended invocation still needs a separately designed
scheduler, webhook, or automation and an explicit branch/PR/merge policy.

## What each agent technology actually contributes

| Component | Contribution | What it does not do |
| --- | --- | --- |
| App diagnostic SDK | Captures crashes and explicitly reported handled errors from installed builds | Does not diagnose or fix source code |
| Sentry issue grouping | Combines repeated events into one issue with occurrence evidence | Does not automatically start Codex |
| Sentry GitHub integration | Creates or links a GitHub issue when an Issue Alert condition matches, subject to feature availability | Does not write a regression test |
| Codex Sentry plugin | Teaches Codex to find and debug Sentry issues and connects it to Sentry MCP | Does not cause the app to emit safe data |
| Sentry MCP | Lets a human-in-the-loop coding agent query issue, event, trace, release, and project evidence | Does not grant repository or merge authority |
| GitHub MCP or `gh` | Searches, deduplicates, creates, labels, and updates repository issues and PRs | Does not supply runtime crash evidence |
| Repo-local skill | Encodes SERPy's own triage, privacy, TDD, installed-app, and reporting sequence | Is instructions, not a daemon or event transport |
| Codex automation | Can periodically run a review workflow when separately configured | A schedule is not the same as an immediate Sentry event trigger |

OpenAI describes plugins as bundles of skills, MCP servers, and optional UI.
Its Codex use-case catalog separately identifies adding Mac telemetry and
creating a CLI over a log source or export as agent workflows. This distinction
matters: a skill tells an agent how to work, while an SDK, CLI, or MCP server
gives it access to the evidence.
[OpenAI Developers](https://developers.openai.com/),
[Codex use cases](https://developers.openai.com/codex/use-cases)

## Available now from official sources

### Sentry for Codex

Sentry's canonical AI repository says its Codex distribution can set up an SDK,
query and fix production issues, review code with Sentry context, and configure
monitoring. Its `sentry-debug-issue` workflow can fetch issue context, optionally
use Sentry's analysis, apply a fix, and resolve the issue. The generated Codex
plugin includes the hosted Sentry MCP server.
[Canonical Sentry AI source](https://github.com/getsentry/sentry-for-ai),
[generated Codex plugin](https://github.com/getsentry/plugin-codex)

The official Sentry MCP is explicitly designed for human-in-the-loop coding
agents and debugging, rather than as a general Sentry administration API. It can
run as the hosted service or through a local `stdio` transport. Some
natural-language search tools require an LLM-provider key when self-hosted;
other tools remain available without that extra provider configuration.
[Sentry MCP](https://github.com/getsentry/sentry-mcp)

This is the strongest agent-side candidate after Sentry itself is authorized.
It should not be installed before then because installation connects a new
remote data surface and the plugin is useless without an accessible Sentry
project.

### GitHub access

GitHub's official MCP server supports repository inspection, issue and PR
management, Actions inspection, allowlisted toolsets, read-only mode, and
lockdown mode. Its own issue-tool instructions tell agents to search before
creating an issue to avoid duplicates. GitHub publishes a Codex configuration
guide and recommends least-privilege credentials.
[GitHub MCP Server](https://github.com/github/github-mcp-server),
[GitHub MCP issue instructions](https://github.com/github/github-mcp-server/blob/main/pkg/github/toolset_instructions.go),
[GitHub MCP for Codex](https://github.com/github/github-mcp-server/blob/main/docs/installation-guides/install-codex.md)

SERPy does not need this MCP merely to open an issue. GitHub's REST API and
`gh issue create` already support issue creation; a fine-grained token needs
Issues write permission. GitHub also exposes issue search, which should run
before any write.
[GitHub issue REST API](https://docs.github.com/en/rest/issues/issues),
[GitHub issue search](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/filtering-and-searching-issues-and-pull-requests)

Use Sentry's grouping key or issue ID as the durable deduplication key, then
record it in the GitHub issue. Similar titles are not a reliable deduplication
contract.

### Existing SERPy/Codex skills

The current environment already supplies the important implementation skills:

- `build-macos-apps:telemetry` for local `Logger` instrumentation and log
  verification;
- `diagnosing-bugs` for root-cause work;
- `tdd` for red-green-refactor and integration coverage;
- `build-macos-apps:build-run-debug` and `test-triage` for the native app;
- `code-review` for spec and repository-standards review.

The official OpenAI macOS telemetry skill deliberately focuses on adding and
verifying lightweight `Logger` events. It is useful for instrumentation, but it
is not a remote collector, issue creator, or agent trigger.
[OpenAI macOS telemetry skill](https://github.com/openai/plugins/tree/main/plugins/build-macos-apps/skills/telemetry)

## Skills.sh candidate review

Skills.sh surfaced relevant candidates, but install count alone is not a trust
decision:

| Candidate | Current discovery signal | Source verdict | Recommendation |
| --- | --- | --- | --- |
| `getsentry/sentry-for-ai@sentry-code-review` | About 2.6K installs in the 2026-09-04 search | Official Sentry source; the repository points Codex users to its generated plugin | Use the official Codex plugin only after Sentry authorization |
| `getsentry/sentry-for-ai@sentry-sdk-setup` | About 3.2K installs in the earlier Sentry setup search | Official Sentry source, but now part of a broader generated plugin workflow | Do not install the isolated legacy skill; use the current plugin entry points |
| `openai/plugins@telemetry` | 33 installs in the 2026-09-04 search | Official OpenAI source and already available in this environment | Use for local logging work; no additional installation needed |
| `warpdotdev/oz-skills@github-bug-report-triage` | 338 installs | Reputable vendor repository, but redundant with SERPy's existing issue process and official GitHub tooling | Do not add another generic triage policy |
| `getsentry/sentry-agent-skills` results | Several legacy skills appear in search | The old repository is superseded by `sentry-for-ai` | Do not install |

The Sentry source repository explicitly says it is the source of truth but is
not itself the artifact to install; Codex users should use the generated
`getsentry/plugin-codex` distribution. That is a stronger signal than a
third-party skills index entry.
[Sentry for AI distribution guidance](https://github.com/getsentry/sentry-for-ai),
[Sentry for Codex](https://github.com/getsentry/plugin-codex)

## Two viable levels for SERPy

### Level A — local agent assistance under the current privacy boundary

Revise Issue #9 from “clipboard only” to a bounded local incident store plus a
small read-only CLI, for example:

```text
serpy-diagnostics list --unreported --json
serpy-diagnostics show <incident-id> --json
serpy-diagnostics mark-reported <incident-id> --issue <url>
```

The store must contain only the existing allowlisted schema and must pass
seeded-secret tests. A repo-local `triage-serpy-incident` skill can tell Codex
to:

1. read new incidents through the CLI;
2. reproduce the event with the matching deterministic fixture;
3. search existing GitHub issues by stable event code and fingerprint;
4. draft or, when separately authorized, create one issue;
5. add a failing unit/contract/integration test;
6. implement on a branch, run installed-app verification, and report back.

This removes manual copying when Codex is running on the same Mac. It does not
discover errors from other users' machines, notify the team remotely, or start
an agent by itself. The owner or an authorized scheduled local task must still
invoke the triage workflow.

### Level B — remotely assisted private-beta triage

After an explicit policy decision, use this minimal remote design:

1. Add Sentry Cocoa in opt-in, crash/error-only mode.
2. Send only stable event code, stage, build/release, macOS version, provider
   kind, retry category/count, and bounded timing.
3. Exclude prompt, response, transcript, audio, screenshot, OCR, window title,
   document data, paths, usernames, credentials, clipboard, attachments,
   replay, tracing, profiling, network breadcrumbs, and persistent identity.
4. Let Sentry group repeated events into one Sentry issue.
5. Configure a GitHub Issue Alert only for a new regression, fatal event, or a
   frequency/impact threshold—not every occurrence. Availability must be
   confirmed against the selected Sentry plan.
6. Put the Sentry issue ID, event code, build, counts, first/last seen, and a
   private Sentry link in the GitHub issue; never copy raw content.
7. Invoke Codex with the official Sentry plugin/MCP. The agent diagnoses,
   reproduces, writes the failing test, fixes on a dedicated branch, verifies,
   and reports back.
8. Keep PR creation, merge, packaging, and release behind explicit owner policy.

Sentry's official GitHub integration metadata lists creating/linking issues,
syncing them, and automatically creating GitHub issues from Issue Alert
conditions. This automatic ticket capability is feature-gated, so it must be
verified in the actual Sentry organization rather than assumed from a pricing
page.
[Sentry GitHub integration source](https://github.com/getsentry/sentry/blob/master/src/sentry/integrations/github/integration.py),
[Sentry integration API metadata](https://docs.sentry.io/api/integrations/get-integration-provider-information/)

The macOS capture side would use Sentry's official Cocoa SDK, which supports
Apple platforms and Swift Package Manager. The prior telemetry report contains
the required configuration and privacy exclusions.
[Sentry Cocoa](https://github.com/getsentry/sentry-cocoa),
[existing SERPy telemetry research](macos-diagnostics-and-telemetry.md)

## What remains human or explicitly policy-controlled

Even with Level B, the owner does not need to manually copy diagnostics, but
some responsibilities do not safely disappear:

- somebody or an automated UI suite must exercise code paths; crash monitoring
  cannot find a flow nobody runs;
- a product team must define which handled failures are reported;
- an owner must approve the cloud processor, schema, consent/default, region,
  retention, access, deletion, and credential handling;
- an alert policy must prevent one GitHub issue per event;
- Codex needs an invocation mechanism and repository/Sentry credentials;
- branch creation, PR submission, merge, packaging, and release need explicit
  authority and review gates;
- every accepted fix still needs a deterministic regression test and
  installed-product evidence.

An agent can perform most diagnosis and implementation work. It cannot infer
permission to transmit private app data or continuously modify the repository.

## Concrete next decision

Choose one of these before changing Issue #9:

1. **Recommended immediate step:** approve Level A. Add the safe local incident
   store, read-only CLI, and repo-local triage skill. This eliminates copying
   for tests performed on the development Mac and validates the schema without
   creating a new data processor.
2. **Recommended private-beta destination:** explicitly authorize a Level B
   Sentry pilot. Then replace clipboard-first reporting with opt-in remote
   grouping, a thresholded GitHub integration, and the official Sentry Codex
   plugin/MCP.

Do not spend time collecting more generic skills. The necessary agent-side
capabilities exist. The product decision is whether SERPy may transmit the
small, audited error schema to Sentry and whether Codex may perform scheduled
GitHub writes.

## Proposed acceptance criteria for an implementation issue

- [ ] The event schema and forbidden-data list are committed before egress is
  enabled.
- [ ] Seeded-secret tests prove forbidden values cannot enter local records,
  Sentry envelopes, GitHub issue bodies, or agent prompts.
- [ ] `guidance.plan.malformed` is emitted as a handled error with a stable
  fingerprint and deterministic reproduction fixture.
- [ ] Repeated occurrences group into one issue.
- [ ] A configured threshold creates no more than one linked GitHub issue for
  the same Sentry issue.
- [ ] Codex can retrieve the linked Sentry evidence without the owner copying
  diagnostics.
- [ ] The agent adds a failing regression test before the fix and runs the
  required unit, integration, and installed-app verification afterward.
- [ ] No agent auto-merges, packages, releases, or closes acceptance without
  the separately authorized evidence.
- [ ] Disabling consent stops future egress and purges any bounded local Sentry
  cache as defined by the privacy decision.

