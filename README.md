# Guide Companion for macOS — Planning Workspace

This is a fresh, planning-first project for a small native macOS companion.
The working product name is intentionally generic and temporary.

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

## Current Gate

Status: architecture planning; no implementation authorized yet.

The next executable step is Phase 0 in `DELIVERY_PLAN.md`: small disposable
technical probes for local transcription, text insertion, overlay lifecycle,
and local screen guidance. A human must approve the architecture and Phase 0
scope before those probes begin.

## Source-of-Truth References

- OpenClicky evaluation workspace:
  `/Users/devin/dev/repos/TEMP-openclicky-proj`
- Installed evaluation app: `/Applications/OpenClicky.app`
- Prior clean-room evidence workspace:
  `/Users/devin/dev/repos/clone-keylume-ios-app`
- Recorded OpenClicky findings:
  `https://github.com/devinschumacher/openclicky-internal-releases/issues`

These locations are evidence inputs. They are not dependencies of this repo.
