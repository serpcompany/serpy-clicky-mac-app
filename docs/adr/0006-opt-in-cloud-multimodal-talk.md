# ADR 0006: Opt-in request-scoped multimodal Talk

Date: 2026-09-04

## Status

Accepted for private internal testing. Live provider use still requires the
owner to supply a credential and deliberately run the documented HIL.

## Decision

Keep dictation fully local. Keep local Foundation Models guidance as the
default explicit selection. Add a separate OpenAI Talk selection that is
disabled until the user:

1. reads a disclosure naming OpenAI and the exact data leaving the Mac;
2. enables cloud Talk;
3. saves a tester-owned API key in Keychain;
4. verifies provider access through a content-free model-metadata request; and
5. invokes a Talk turn within the 15-minute verification lifetime.

Saved, unverified, expired, or provider-rejected credentials cannot authorize a
multimodal request. Verification calls `GET /v1/models/gpt-5.6-terra` and sends
no screenshot, question, Talk history, or response-generation input.

Each enabled turn sends only the current locked-window image, the spoken
question, and a bounded recent Talk summary. Local OCR remains on the Mac and
is not duplicated into the provider request. Requests use the Responses API,
stream output, set
`store: false`, and are cancelled with the owning turn. Screenshots, OCR,
questions, and answers are not written to disk or content logs.

The production adapter targets `gpt-5.6-terra` through `POST /v1/responses`.
Official OpenAI documentation confirms image input and streaming support for
that model and endpoint. The model has no audio output; SERPy forms complete
sentence events and speaks them locally.

## Security qualification

This private tester build stores only the owner's own key in macOS Keychain; it
does not embed or distribute a shared key. This is an internal evaluation
boundary, not approval to publish a BYOK client. A production distribution
requires a separate server-issued credential design and owner decision.

## Consequences

- Provider-neutral request/event types live in GuideCore.
- OpenAI HTTP/SSE and Keychain details live in GuideMac.
- No automatic fallback is permitted.
- Spatial output is advisory data until independently validated against the
  normalized bounds of the exact locked-window screenshot.
- Real answer quality, latency, billing, and data-handling behavior remain red
  until owner HIL with a benign screen.

## Official references

- https://developers.openai.com/api/reference/typescript/resources/beta/subresources/responses/methods/create
- https://developers.openai.com/api/docs/models/gpt-5.6-terra
- https://developers.openai.com/api/reference/typescript/resources/models/methods/retrieve
