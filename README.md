# SERPy for macOS

SERPy is a small native macOS companion for private, on-device dictation and
optional screen guidance.

The first product must do two things well:

1. Dictate ordinary speech into the focused text field using a free local
   speech model, with no assistant request and no API key.
2. Provide an optional cursor companion that can explain the current screen and
   point to a suggested next step without taking autonomous action.

This repository does not contain a fork of OpenClicky or extracted HeyClicky
code. HeyClicky is a behavioral reference. OpenClicky is an MIT-licensed source
reference and possible donor for individually audited components.

## Start Here

1. Read [PRODUCT.md](PRODUCT.md).
2. Read [ARCHITECTURE.md](ARCHITECTURE.md).
3. Read [DELIVERY_PLAN.md](DELIVERY_PLAN.md).
4. Read [ACCEPTANCE.md](ACCEPTANCE.md).
5. Read [PROVENANCE.md](PROVENANCE.md) before importing any code or assets.
6. Read [AGENTS.md](AGENTS.md) before making changes.

Private beta release procedure: [docs/RELEASING.md](docs/RELEASING.md).

Latest private beta:
[SERPy 0.1.0 Beta 1](https://github.com/serpcompany/serpy-clicky-mac-app/releases/tag/v0.1.0-beta.1).

## Current Gate

Status: `v0.1.0-beta.1` is a signed, notarized private prerelease. Public
distribution remains separately approval-gated.

## Source-of-Truth References

- [OpenClicky evaluation record](docs/reference/openclicky-evaluation.md)
- Prior clean-room evidence workspace:
  `/Users/devin/dev/repos/clone-keylume-ios-app`
- Recorded OpenClicky findings:
  `https://github.com/devinschumacher/openclicky-internal-releases/issues`

These records are evidence inputs. They are not dependencies of this repo.
