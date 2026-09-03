# SERPy build 39 HeyClicky-informed UX HIL

Use only the Developer ID build `0.1.0 (39)` whose executable SHA-256 is
`5579e2bf54f59821c85a84cfe1c9f87e48609734dab7e7b89457b3a39982cffc`.

## Settings shell

1. Open Settings from the menu bar over another application.
2. Confirm the normal non-floating `SERPy Settings` window comes to the front.
3. Confirm the top rail contains Home, Guide, current provider status, and
   Setup—without plan, upgrade, agent, account, or community controls.
4. Confirm the home surface shows the SERP mark, dictation/Talk shortcuts,
   truthful readiness, and grouped rows for Voice & Input, Companion, and Data
   & Privacy.
5. Open every row, use the back affordance, and resize the window down to its
   minimum. Content must remain readable and scroll rather than clip.
6. Verify every pre-existing setting/action remains reachable and functional.

## Ambient companion

1. With the companion enabled, confirm idle uses the original SERP arrow mark
   on a compact dark surface.
2. Start dictation and Talk separately. Confirm listening uses a blue five-bar
   waveform; capture/thinking uses compact progress; speaking uses a blue
   speaker state; errors remain visually distinct.
3. Confirm every overlay remains click-through except genuine overflow
   scrolling, stays below menu-bar safe areas, and respects Reduce Motion.

## Provenance and declared differences

The current HeyClicky 1.0.48 app is behavioral evidence only. The older MIT
repository contributed only the semantic-layer and waveform concepts recorded
in `docs/imports/0001-clicky-visual-primitives.md`; its license is preserved in
`THIRD_PARTY_NOTICES.md`.

SERPy deliberately omits HeyClicky accounts, plans, payments, agents,
integrations, skills, community links, analytics, autonomous actions, and
product identity. Those controls must not appear as inert placeholders.

Run the full build-34 Talk HIL after this visual pass. The completion manifest
remains red until installed voice, vision, focus, layout, and cancellation rows
are directly observed.
