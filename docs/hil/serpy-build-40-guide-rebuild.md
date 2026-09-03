# SERPy build 40 Guide owner QA

Use only installed `/Applications/SERPy.app` `0.1.0 (40)` with executable
SHA-256 `97c5dd01c1b2a14598dccfa47a35f2f882df5ba78cb2e93ea441e5acdda25445`.
The notarized DMG is `dist/SERPy-0.1.0-40.dmg`, SHA-256
`faadec51b7246c06039f82b139392ed8018c88fa9e440a1ef9065ddf29089af1`.

Do not enter or expose secrets. Keep OpenAI unselected for steps 1–8. If you
later choose the opt-in OpenAI test, use your tester-owned credential and stop
if the disclosure or exact target is wrong.

## Primary installed journey

1. Open SERPy Settings → Guidance. Confirm the normal window comes forward,
   `On-device` is selected, the held shortcut is shown, and every visible
   control responds.
2. Close Settings. In a new unsaved TextEdit document, enter
   `ORCHID RIVER 731`. Keep TextEdit frontmost.
3. Hold the configured Guide chord. Within 150 ms, confirm one compact ambient
   listening surface appears on TextEdit's display. SERPy must not activate,
   open a chat window, insert a character, or cover menu controls.
4. While holding, say: “What unique phrase is visible?” Confirm readable live
   transcript text. Release the chord to send.
5. Confirm distinct capture/thinking states, then a complete readable answer
   grows in the same ambient surface and is spoken. Record phrase accuracy,
   first-answer latency, audible first/final words, clipping, focus, and cleanup.
6. Replace the phrase with `COBALT HARBOR 924`. Hold the chord and ask:
   “What changed?” Confirm fresh screen context and dependent continuity.
7. With persistent Companion off, run one complete turn and one cancelled turn.
   The Guide must appear transiently and the saved preference must remain off.
8. Press Escape separately during listening, capture, thinking, and speaking.
   Each must stop owned work, produce no delayed answer, and allow the next turn
   without relaunch.

## Geometry, accessibility, and recovery

9. Repeat at the four corners and beneath crowded menu items. Move the pointer
   during the answer; the ambient surface must stay on the locked window's
   display and never obstruct the menu bar or Dock.
10. Repeat on another display, a negative-origin arrangement, another Space,
    and full screen. Record each unsupported case; do not generalize.
11. Enable Reduce Motion and then VoiceOver. Confirm state, live transcript,
    exact app/window label, complete answer, and error/recovery are readable.
12. Disconnect/select an unavailable microphone, mute output, and test a cold
    Bluetooth route. Record truthful failure and answer recovery. These rows are
    expected to remain red if failover/pre-roll is absent.
13. Ask where one clearly visible benign control is. Accept a point only when it
    lands on the exact target without moving/clicking the real pointer. Then ask
    for a multi-step walkthrough; progressive drawing is currently expected red.

## Optional OpenAI multimodal HIL

14. Select OpenAI only if you accept the request-scoped disclosure. Save a
    tester-owned key, verify it, return to TextEdit, and repeat steps 3–8. Confirm
    only the locked screenshot, question, and bounded Talk context are sent;
    confirm there is no silent local fallback. This is a live paid request and
    was not run during automated verification.

Return the recording and a row-by-row pass/fail note. Do not accept build 40 as
complete merely because Settings, tests, signing, or notarization pass.
