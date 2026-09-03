# Provenance and Reference Policy

## Reference Roles

| Reference | Permitted role | Not permitted |
| --- | --- | --- |
| HeyClicky installed/product experience | Behavioral oracle and acceptance inspiration | Code, assets, private protocols, decompilation-derived implementation |
| OpenClicky MIT repository | Source reference and candidate donor for narrow audited units | Wholesale fork architecture, upstream identity, credentials, keys, feeds, release destinations |
| Prior Keylume clean-room project | Evidence process, test patterns, packaging lessons | Treating experimental branches as selected production architecture |
| Superwhisper public documentation | Dictation behavior benchmark | Proprietary implementation assumptions |

## Import Gate

No OpenClicky code enters this repository until an import record identifies:

- Exact upstream URL and commit.
- Exact source files and copied/derived lines.
- Applicable license and notice text.
- Why reuse is safer than a small independent implementation.
- Dependencies pulled in by the unit.
- Tests surrounding the adopted behavior.
- Product names, identifiers, assets, secrets, or update settings removed.
- Approval status.

Use one record per logical component under `docs/imports/`.

## Candidate Reuse Classification

These are audit candidates, not approved imports:

| Area | Initial classification | Reason |
| --- | --- | --- |
| Local transcription provider protocols | Adapt concept | Useful seam; implementation coupling must be measured |
| Apple Speech adapter | Inspect/reimplement or narrow import | Small platform adapter candidate |
| Parakeet model management | Inspect | Valuable behavior but currently integrated with broader settings/state |
| Global shortcut monitor | Inspect/reimplement | Narrow behavior; permission and modifier semantics need dedicated tests |
| Cursor geometry/choreography | Adapt algorithms after audit | Useful edge cases; do not import overlay managers wholesale |
| DMG/notarization verification | Adapt process | Proven locally; must use new identity and destinations |
| CompanionManager | Reject | Centralized product-wide coupling |
| Notch/settings window managers | Reject | Inherited intrusive UX and excessive scope |
| Agent, browser, MCP, shell, bridge | Reject for first product | Outside guide-only product contract |
| Pets, widgets, galleries | Reject for first product | No connection to first journeys |
| Sparkle configuration | Defer | Updating is not required to validate the first product |

## Brand Separation

The product name `SERPy` and assets from `/Users/devin/Brands/SERP` are owned
brand inputs supplied by the project owner. Do not copy the
HeyClicky, Clicky, OpenClicky, or Keylume name, icon, cursor artwork, sounds,
copywriting, bundle identifiers, URL schemes, or marketing assets.

MIT compliance does not itself clear third-party assets or trademarks. Every
shipped asset must be original, commissioned, or separately licensed.

## 2026-09-04 rejected-build rebuild

Branch `codex/heyclicky-guide-rebuild` imports no code or assets from current
HeyClicky or the historical MIT repository. The rejected build-39 visual
adaptation commit is not in this branch. Current HeyClicky `1.0.48 (57)` is
used only through installed screenshots, accessibility output, and observable
interaction; private/account regions are not committed. No additional MIT
notice is required unless a later commit passes the import gate above.

## 2026-09-04 issue #7 implementation

Branch `codex/issue-7-guide-parity` is an independent implementation from the
SERPy build-40 checkpoint. It imports no HeyClicky or OpenClicky source, assets,
protocols, prompts, sounds, identity, or credentials. Issue #7's owner recording
is used only as behavioral evidence. The implementation adds downstream-owned
presence, progression, structured-plan, overlay, and speech policies; no MIT
notice or import record is required for this branch.
