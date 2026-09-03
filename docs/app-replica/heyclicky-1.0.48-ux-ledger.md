# HeyClicky 1.0.48 UX reconstruction ledger

Reference: installed `/Applications/HeyClicky.app` version `1.0.48 (57)`.
Candidate baseline: SERPy `0.1.0 (38)`.

This ledger covers the user-authorized voice-guide, dictation, companion,
settings, recovery, and privacy experience. HeyClicky accounts, plans,
payments, agents, integrations, skills, community links, analytics, autonomous
actions, and product identity are deliberately excluded by `PRODUCT.md` and
remain declared differences rather than fake SERPy controls.

| Surface / state | HeyClicky observation | SERPy target | Status |
| --- | --- | --- | --- |
| Idle home | Black notch surface with compact blue buddy mark | Branded cursor companion plus concise ready state | implemented; installed QA pending |
| Settings navigation | Persistent compact top rail and scrollable grouped home | Home/Guide rail with provider status and working-only route groups | implemented; installed QA pending |
| Settings rows | Dense rounded dark cards with icon, title, summary/value, chevron | Same hierarchy with original SERP mark, tokens, and copy | implemented; installed QA pending |
| Dictation setup | Drill-down customization and readiness | Shortcut, provider, permissions, diagnostics, recovery | implemented; installed QA pending |
| Talk setup | Voice-first shortcut and provider state | Guidance route with local/OpenAI disclosure and controls | implemented; installed QA pending |
| Listening | Compact blue waveform at ambient surface | Five-bar blue waveform in cursor companion | implemented; installed QA pending |
| Capturing/thinking | Persistent compact progress affordance | Compact progress indicator without opening a chat window | implemented; installed QA pending |
| Speaking | Spoken answer with ambient visible state | Blue speaking state plus complete adjacent answer | implemented; installed QA pending |
| Pointing | Spatial visual cue while speech continues | Validated click-through ring; no pointer control | implemented; installed QA pending |
| Long response | Ambient answer remains recoverable | Edge-safe response surface; overflow-only scrolling | implemented; installed QA pending |
| Follow-up | Same ambient conversation continues | Fresh exact-window capture plus bounded in-memory Talk turns | implemented; installed QA pending |
| Permissions | Contextual setup/recovery | Permission rows with truthful state and direct recovery | implemented; installed QA pending |
| Error | Compact recovery affordance | Stage, cause, and recovery action in ambient/status UI | implemented; installed QA pending |

No current HeyClicky source or asset was inspected or copied. Its current UI is
observable behavioral evidence only. The older MIT repository contributes only
the separately documented units in `docs/imports/0001-clicky-visual-primitives.md`.
