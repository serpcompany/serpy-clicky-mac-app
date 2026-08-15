# ADR 0001: Guide-Only First Product

Status: accepted

## Context

The reference products combine several distinct experiences: dictation,
screen-aware teaching, cursor presentation, autonomous agents, integrations,
and developer tooling. The observed OpenClicky baseline showed that coupling
these paths can make basic voice input appear broken when an unrelated response
provider is unavailable.

## Decision

The first product includes independent local dictation, a persistent cursor
companion, and explicitly invoked screen guidance. It excludes autonomous
actions, shell/browser control, connected services, and agent orchestration.

## Consequences

- The app can deliver useful value without an account, API key, or server.
- Dictation has a small and testable failure surface.
- Screen guidance can evolve behind an adapter without destabilizing dictation.
- The first release will not reproduce every HeyClicky or OpenClicky feature.
- Agent functionality requires a later architecture and security decision.
