# SERPy issue #7 installed Guide QA

Candidate build, signing identity, notarization result, installed executable
hash, and artifact hash are intentionally blank until the reviewed source commit
is packaged and installed. Source tests are not installed proof.

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
