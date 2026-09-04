# SERPy build 42 issue #7 installed Guide QA

Use only installed `/Applications/SERPy.app` `0.1.0 (42)` from commit
`badc0b0a992708a8edcce9a88aa7a3275498ad6f`.

- Installed executable SHA-256:
  `0a5a1b06ebfccb40931d33308e54309805ba7918af8b89ef9683a0a5a3e2f8e1`
- Notarized DMG: `dist/SERPy-0.1.0-42.dmg`
- DMG SHA-256:
  `4873ddc933dd8e30b41821d3864482cd8ed3cfc6f83bc49a015b0ee49f708f73`
- Apple notarization submission:
  `a4809fe6-49f0-436a-b9d3-24dbf843fae1` (`Accepted`)
- Gatekeeper: `accepted`, Notarized Developer ID, team `847HR8U8D9`

The installed and reviewed Release executable hashes match. Source tests,
signing, and the visible Settings window are not proof of the spoken Guide
journey; the matrix below remains the owner acceptance gate.

## Required P0 matrix — all red until recorded

- [ ] Launch SERPy and close Settings. Confirm Dock and Command-Tab presence,
  Dock activation foregrounds a normal surface, Dock Quit terminates, and
  relaunch creates one instance.
- [ ] With Chrome frontmost, hold the configured Guide chord and ask “Show me
  how to open a new window.” Confirm immediate listening/live transcript,
  target focus retention, capture/thinking, then only `Step 1 of 2+` and one cue.
- [ ] Perform step 1, explicitly invoke Guide again, and confirm a fresh capture
  advances to Step 2, stays with a truthful reason, or completes. It must not
  restart, repeat silently, poll, or perform the action.
- [ ] Repeat in Slack with a visible known conversation. Unsupported evidence
  must produce stage/cause/recovery instead of a guessed cue.
- [ ] During every surface, click the underlying target and nearby controls.
  Confirm no SERPy activation, pointer movement, intercepted click, or idle
  cursor-following badge.
- [ ] Press Escape during listening, capture, thinking, speaking, and
  ready-for-follow-up. Confirm all owned work/cues clear and no delayed output.
- [ ] Compare visible and spoken text from first to last item for provider order,
  omissions, duplication, raw JSON, malformed quotes, and narrated punctuation.

## Required P1 matrix — all red until recorded

- [ ] Screen edges, crowded menu items, second/negative-origin display, another
  Space, and full screen.
- [ ] VoiceOver exposes stage, transcript, step number/text, target, complete
  answer, and recovery; Reduce Motion preserves meaning.
- [ ] Microphone unavailable, muted output, and cold Bluetooth recovery.
- [ ] Optional live OpenAI quality/privacy/cost only under owner control after
  explicit selection, disclosure, credential save, and fresh verification.

Automatic advancement after an unannounced click remains out of scope because
it would require unauthorized background observation. No live paid request is
part of automated verification.
