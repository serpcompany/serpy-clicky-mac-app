# Import record: Clicky visual primitives

Status: approved by owner request on 2026-09-04 and implemented as a narrow
adaptation.

## Source

- Repository: `https://github.com/farzaa/clicky`
- Commit: `a80fa80721a8aebe51a170a7780705024ebc6e46`
- License: MIT, Copyright (c) 2026 Farza
- Inspected units:
  - `leanring-buddy/DesignSystem.swift`, lines 22–147: semantic dark-surface,
    text, border, spacing, radius, state, and accent token organization.
  - `leanring-buddy/OverlayWindow.swift`, lines 705–742: five-bar animated
    waveform concept for the listening cursor state.

## Adopted scope

SERPy reimplements two narrow concepts in independent source:

1. A small semantic visual-token namespace with layered dark surfaces,
   borders, spacing, radii, semantic status colors, and hover feedback.
2. A five-bar `TimelineView` waveform for the cursor companion's listening
   state.

No upstream line is copied verbatim. Token names and values, component APIs,
layout, animation timing, accessibility behavior, and all Swift source were
rewritten for SERPy. The MIT notice is nevertheless retained in
`THIRD_PARTY_NOTICES.md` because these units were used as design/code
references rather than mere product screenshots.

## Why this reuse is safer

The semantic layering and waveform are small, isolated presentation units.
Reusing their proven concepts is lower risk than importing Clicky's monolithic
window or companion managers, while SERPy's existing model, provider,
permission, storage, and overlay boundaries remain intact.

## Dependencies and removals

- Adds no package or runtime dependency.
- Imports no Clicky image, icon, sound, font, copy, service, identifier,
  credential, appcast, analytics, or update configuration.
- Uses an original code-drawn mark based on owner-supplied SERP branding.
- Does not import `CompanionManager`, `OverlayWindow`, settings managers, or
  product-wide state.

## Verification

- `SettingsExperienceTests` locks the working route inventory.
- Existing overlay, response-layout, Reduce Motion, and guide coordinator tests
  continue to exercise the presentation seams.
- Installed visual QA compares the current HeyClicky 1.0.48 interaction
  hierarchy with SERPy while treating brand and excluded features as declared
  differences.
