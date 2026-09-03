# SERPy build 31 opt-in OpenAI Talk HIL

This guide is for the exact signed branch artifact at:

`$REPO_ROOT/.release-derived/Build/Products/Release/SERPy.app`

Expected version is `0.1.0 (31)`. Its Developer ID-signed arm64 executable
SHA-256 is
`94115f3d211af04c2d53ded75f247f4d6320d2cda008d326e345c8b4cda67865`.
Do not mark an installed row passed unless that hash matches.

## Safety and cost boundary

- Use a tester-owned OpenAI API key and benign fixture content only.
- Do not expose credentials, personal messages, customer data, or private
  documents in the locked-window screenshot.
- This HIL intentionally incurs one or more normal OpenAI API requests. No
  automated test or build may make those requests.
- Plain dictation must continue to work with OpenAI Talk disabled and with no
  credential.

## Configure the explicit opt-in

1. Open SERPy Settings → Guidance.
2. Confirm **On-device** is selected by default.
3. Select **OpenAI multimodal** and read the complete disclosure.
4. Accept the request-scoped transmission disclosure.
5. Paste the tester-owned API key, save it to Keychain, then click **Verify
   Keychain**. This button must state that it does not contact OpenAI.
6. Quit and relaunch SERPy. Confirm the selection and disclosure remain, the
   key field is blank, and the saved-key status remains available.

## Primary multimodal journey

1. In TextEdit, show `ORCHID RIVER 731` plus one visible non-text control.
2. Keep TextEdit frontmost and press Control–Option–G.
3. Confirm SERPy stays nonactivating and identifies the exact TextEdit window.
4. Ask, “What phrase is visible, and where should I click next?” Press the
   shortcut again.
5. Observe distinct capture/provider states. The answer should begin appearing
   incrementally, remain complete and unclipped in the widened edge-safe
   bubble, and speak complete sentences once in order.
6. Confirm the answer is grounded in the screenshot and never claims SERPy
   clicked, typed, moved the pointer, or controlled the app.
7. Ask a dependent spoken follow-up after changing the visible phrase to
   `COBALT HARBOR 924`. Confirm the fresh screenshot and bounded in-memory
   conversation both affect the answer.

## No-send and no-fallback matrix

Repeat one invocation after each state below. It must fail before sending any
screen content, give a precise recovery action, and never silently use the
other provider:

1. OpenAI selected, disclosure off.
2. OpenAI selected, no Keychain credential.
3. OpenAI selected, invalid credential.
4. OpenAI selected, network unavailable.
5. On-device selected while the Apple local model is unavailable.

## Cancellation and privacy

1. Exercise Escape during listening, capture/provider wait, streaming answer,
   and speech. No delayed text or audio may appear afterward.
2. Quit SERPy after a benign Talk turn. Confirm no screenshot, question,
   answer, or guide transcript was written under Application Support.
3. Delete the key in Settings and verify the Keychain status changes without
   displaying the credential.

## Rows that remain red

This build does not establish HeyClicky parity. Model quality, live latency,
installed streaming/audio behavior, spatial cue rendering, arbitrary visual
understanding, multi-display/Spaces/full-screen behavior, VoiceOver, Reduce
Motion, provider retention behavior, and the full audio-device failure matrix
remain red until separately observed and accepted.
