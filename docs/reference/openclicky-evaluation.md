# OpenClicky evaluation record

## Purpose

OpenClicky was evaluated as a behavioral and source reference before SERPy was
built as an independent product. This record preserves the useful findings
without importing OpenClicky's Git history, source tree, product identity, or
release configuration into the SERPy repository.

The evaluation is historical evidence, not a runtime or build dependency.

## Reference identity

- Upstream: `https://github.com/jasonkneen/openclicky.git`
- Upstream branch: `main`
- Pinned upstream commit: `257fc11120b92a18455d541fa8a6285dceecc9a0`
- Internal packaging branch: `phase1/internal-dmg`
- Internal packaging commit: `4f31afcc8d95b523da93a297c7b16414e0766d8d`
- Evaluation wrapper head: `d5be272`
- Evaluated app: OpenClicky Internal `0.1.0 (1)`
- DMG SHA-256: `64cd83ccd1396fc889438487f584fc1b54614e05a4bba6ffe2f07b705d35a0c3`
- Evaluation date: 2026-08-15 to 2026-08-16
- Artifact/evidence repository: private
  `devinschumacher/openclicky-internal-releases`
- Source/evaluation archive: private
  [`serpcompany/openclicky-evaluation-archive`](https://github.com/serpcompany/openclicky-evaluation-archive)

The packaged build passed the internal Developer ID signing, notarization,
stapling, browser-download quarantine, Finder installation, Gatekeeper, launch,
quit, and relaunch journey on the registered test Mac. That proves the
packaging mechanics on that Mac; it does not establish commercial clearance,
public distribution readiness, or product suitability.

## Findings carried into SERPy

| Evaluation finding | SERPy disposition |
| --- | --- |
| Hover-expanding notch UI covered menu-bar controls | Avoided. SERPy does not use a hover-expanding notch surface. |
| Full Settings remained globally floating | Rejected. SERPy Settings must behave as a normal non-floating window. |
| First-run permission state was fragmented and unclear | Retained as a product-quality requirement. Setup must explain prerequisites and recovery without repeated prompts. |
| OpenPets Cat ZIP validation failed | Out of scope. Pets and galleries are explicitly excluded from SERPy's first product. |
| Ask and voice appeared inert without a GPT Realtime key | Avoided by architecture. Core dictation cannot depend on an assistant engine, API key, or network. |
| Cursor visibility did not reliably follow its enabled preference | Retained as an acceptance requirement for the SERPy companion lifecycle. |
| A useful default voice path must be local and free | Adopted as a foundational product decision. |
| A Superwhisper-style focused-field dictation journey was missing | Adopted and implemented as the SERPy baseline: configurable toggle shortcut, local transcription, cancellation, durable recovery, and conservative insertion. |

Original detailed reports remain in the private evaluation issue tracker:

1. [Disable the hover-expanding notch panel](https://github.com/devinschumacher/openclicky-internal-releases/issues/1)
2. [Make Settings non-floating](https://github.com/devinschumacher/openclicky-internal-releases/issues/2)
3. [Redesign permission onboarding](https://github.com/devinschumacher/openclicky-internal-releases/issues/3)
4. [OpenPets Cat ZIP failure](https://github.com/devinschumacher/openclicky-internal-releases/issues/4)
5. [Voice failure without a Realtime API key](https://github.com/devinschumacher/openclicky-internal-releases/issues/5)
6. [Cursor visibility lifecycle](https://github.com/devinschumacher/openclicky-internal-releases/issues/6)
7. [Free local voice requirement](https://github.com/devinschumacher/openclicky-internal-releases/issues/7)
8. [Focused-field global dictation requirement](https://github.com/devinschumacher/openclicky-internal-releases/issues/8)

## Source-retention boundary

No OpenClicky source has been copied into SERPy. Any future import must pass the
recorded gate in `PROVENANCE.md` and identify exact files, lines, license
obligations, dependencies, tests, and removed upstream identity.

The unique source and wrapper histories are preserved in a separate private,
read-only archive with their original ancestry intact:

- [Final evaluation wrapper commit `d5be272`](https://github.com/serpcompany/openclicky-evaluation-archive/commit/d5be272411d11e4ea1ea7ec59c4ad82e62719c80)
- [Tagged evaluation wrapper snapshot](https://github.com/serpcompany/openclicky-evaluation-archive/tree/evaluation-final-2026-08-16)
- [Internal packaging source commit `4f31afc`](https://github.com/serpcompany/openclicky-evaluation-archive/commit/4f31afcc8d95b523da93a297c7b16414e0766d8d)
- [Tagged internal packaging source snapshot](https://github.com/serpcompany/openclicky-evaluation-archive/tree/p1b-internal-2026-08-15)

The OpenClicky history must not be pushed as an archived branch or tag in the
SERPy repository. The temporary local evaluation checkout may be removed after
the archive repository and these links have been verified.
