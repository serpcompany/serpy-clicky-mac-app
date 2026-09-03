# SERPy build 30 bounded Talk HIL

This guide is for the exact branch artifact at:

`/Users/devin/dev/repos/serpy-clicky-mac-app/.release-derived/Build/Products/Release/SERPy.app`

Expected version is `0.1.0 (30)`. The executable SHA-256 recorded when built is
`2a7172249d5d43b0a7dcac9aabbdfb51efb207c5d05726927bfb26e14a3b5492`.
Do not mark any row passed if the installed executable does not hash-match.

## Safety and evidence rules

- Use benign fixture text only. Do not expose credentials, personal messages,
  customer data, or private documents in screenshots or recordings.
- Keep **Show Cursor Companion** off before the first journey.
- SERPy must not activate itself, click, type, move the pointer, or open a chat
  window during Talk.
- A build, unit test, or synthetic transcript does not satisfy any observation
  below.

## Primary journey

1. In TextEdit, show the literal phrase `ORCHID RIVER 731` in a normal window.
2. With TextEdit frontmost, press Control–Option–G.
3. Confirm the companion appears immediately even though its saved preference
   is off. It should say Listening and name `TextEdit — <window title>`.
4. Ask aloud, “What unique phrase is visible?” Press Control–Option–G again.
5. Observe distinct Reading, Thinking, and Speaking states. The TextEdit window
   must remain frontmost.
6. Confirm the complete answer is readable in one stationary response bubble,
   does not overlap the status capsule, and is spoken audibly.
7. Change the visible phrase to `COBALT HARBOR 924`, invoke Talk again, and ask,
   “What changed?” Confirm the dependent follow-up uses fresh screen context.
8. After the transient response clears, confirm the persistent companion is
   hidden again and its saved preference remains off.

## Exact target checks

1. Open two TextEdit documents with different unique phrases.
2. Front the second document and invoke Talk.
3. Bring the first document forward only after Listening appears.
4. Finish the question. The compact label and answer must refer to the second,
   invocation-time window—not whichever same-process window is now frontmost.
5. Repeat, but close the locked window before finishing. SERPy must report that
   the selected window disappeared; it must not answer from the sibling window.

## Cancellation matrix

Exercise Escape separately during Listening, Reading/capture, Thinking, and
Speaking. For every row confirm: microphone stops, speech stops if active, the
answer panel disappears, no delayed answer appears, the companion returns to
the saved visibility, and a new Talk turn works without relaunch.

## ChatGPT grounding

With ChatGPT frontmost and benign visible text, ask where to start a new chat.
SERPy must identify `ChatGPT — <window title>` and must not falsely claim that it
cannot see the application. Record the exact question and a redacted summary of
the answer, not captured screen text.

## Rows that remain red after this HIL

Pointing/drawing, whole-document and arbitrary visual understanding,
multi-display/negative-origin/Spaces/full-screen behavior, VoiceOver, Reduce
Motion, and the complete permission/mic/model/audio failure matrix are not part
of this demo and must remain unresolved.
