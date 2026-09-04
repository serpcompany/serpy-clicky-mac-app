# ADR 0001: Two-part first product

Status: accepted; Version 1 stabilization clarified by
`docs/product/version-1-stabilization.md`

## Context

The reference products combine several distinct experiences: dictation,
screen-aware teaching, cursor presentation, autonomous agents, integrations,
and developer tooling. The observed OpenClicky baseline showed that coupling
these paths can make basic voice input appear broken when an unrelated response
provider is unavailable.

## Decision

The first product includes two independent capabilities: local Dictation and an
explicitly invoked screen Guide. Guide surfaces are transient when meaningful;
there is no required idle cursor-following companion. The product excludes
autonomous actions, shell/browser control, connected services, and agent
orchestration.

## Consequences

- The app can deliver useful value without an account, API key, or server.
- Dictation has a small and testable failure surface.
- Screen guidance can evolve behind an adapter without destabilizing dictation.
- The first release will not reproduce every HeyClicky or OpenClicky feature.
- Agent functionality requires a later architecture and security decision.
