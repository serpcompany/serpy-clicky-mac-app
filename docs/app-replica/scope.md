# Historical Guide reconstruction scope

> Historical evidence: this file records the build-40/Issue #7 reconstruction
> context. Current Version 1 scope is `docs/product/version-1-stabilization.md`,
> and current donor permission is `PROVENANCE.md`.

## Authorization and finish line

- Owner authorization: rebuild the AI Guide after explicitly rejecting installed
  SERPy `0.1.0 (39)` on 2026-09-04.
- Reference oracle: exact installed `/Applications/HeyClicky.app` `1.0.48 (57)`.
- Rejected candidate: exact installed `/Applications/SERPy.app` `0.1.0 (39)`.
- New implementation branch: `codex/heyclicky-guide-rebuild`, based on the
  last installed-observed functional head `ef12f96` (build 38), not the rejected
  build-39 UX commit.
- Target identity: SERPy, bundle `com.serpcompany.guidecompanion.internal`.
- Intended use: private internal product development and owner testing.

The finish line is the complete bounded Guide surface described in issue #6:
global voice invocation while another app remains the work surface, ambient
listening/transcription/capture/thinking/speaking/follow-up UI, request-scoped
exact-window vision, useful multimodal guidance, ordered local speech, safe
spatial guidance, deterministic cancellation, truthful failures, normal
Settings recovery, and preference persistence. The completion manifest stays
red until every row has paired installed evidence or the owner explicitly
accepts a named residual difference.

## Reference and donor boundary

Installed HeyClicky is the UX/behavior oracle. Account, plan, Agent,
integration, community, analytics, autonomous-action, and private-service
surfaces are not Version 1 features.

The historical public repository `https://github.com/farzaa/clicky` is MIT at
commit `a80fa80721a8aebe51a170a7780705024ebc6e46` and is an approved Version 1
donor. `PROVENANCE.md` defines the traceability and separation requirements;
another approval is not required for that pinned revision.

## Provider and privacy boundary

- Ordinary dictation remains local and independent of Guide configuration.
- Local Guide remains the default.
- OpenAI multimodal Talk is opt-in, request-scoped, and may transmit only the
  current spoken question, bounded recent Talk context, and exact locked-window
  screenshot after disclosure, explicit selection, credential presence, and a
  recent content-free verification.
- Automated work must not make a live paid model request.
- No screenshot, audio, question, answer, or Guide transcript is persisted by
  default. No silent provider fallback is allowed.
- No clicking, typing, shell execution, browser control, accounts, sync,
  billing, analytics, agents, or new permissions are added.

## Frozen observation environment

Observed 2026-09-04 on macOS 26.5.2 (25F84), Apple M3 Max, built-in
3456×2234 Retina display, Dark appearance, `en_US`, language order `en-US`,
`ja-US`.

| Fact | HeyClicky reference | Rejected SERPy candidate |
| --- | --- | --- |
| Path | `/Applications/HeyClicky.app` | `/Applications/SERPy.app` |
| Version/build | `1.0.48 (57)` | `0.1.0 (39)` |
| Executable SHA-256 | `c1a0863d44da3dda37bac5651809ff9ace3450518eab629f0544da1cb2035b01` | `5579e2bf54f59821c85a84cfe1c9f87e48609734dab7e7b89457b3a39982cffc` |
| Architecture | universal x86_64 + arm64 | arm64 |
| Signature | Developer ID team `2UDAY4J48G`; strict verification passed | Developer ID team `847HR8U8D9`; strict verification passed |
| Gatekeeper | accepted, notarized Developer ID | rejected, unnotarized Developer ID |

TCC grant history is not promoted to fact. Permission-sensitive rows require a
fresh installed run of the eventual reviewed artifact.

## Controlling rejected-build observation

With TextEdit frontmost on a controlled unsaved document containing
`ORCHID RIVER 731`, the installed build-39 `Control–Option–G` gesture did not
begin Talk. A control character reached the TextEdit document and SERPy
remained in its ready state. This is a failure observation, not a generalized
claim about all physical-key events; the owner must still exercise the final
artifact with the actual keyboard and voice.

No live HeyClicky or SERPy provider request was made during this automated
freeze. Listening, answer quality, spoken output, follow-up, provider failure,
and spatial rows therefore remain unresolved until owner HIL.
